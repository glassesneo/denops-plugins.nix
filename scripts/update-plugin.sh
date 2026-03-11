#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: update-plugin.sh <plugin> [options]

Options:
  --repo-root PATH      Override repository root.
  --hashes-path PATH    Override the target hashes.json path.
  --release-json PATH   Read GitHub release JSON from a fixture file.
  --hash HASH           Override the computed source hash for deterministic checks.
  --rev REV             Override the target revision.
  --version VERSION     Override the display version.
  -h, --help            Show this help text.
EOF
}

fail() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "required command not found: $1"
}

validate_hashes_file() {
  local path
  path="$1"

  jq -e '
    type == "object" and
    ((keys | sort) == ["hash", "owner", "repo", "rev", "version"]) and
    (.owner | type == "string" and length > 0) and
    (.repo | type == "string" and length > 0) and
    (.rev | type == "string" and length > 0) and
    (.hash | type == "string" and test("^sha256-[A-Za-z0-9+/]{43}=$")) and
    (.version | type == "string" and length > 0)
  ' "$path" >/dev/null
}

load_release_payload() {
  local owner repo url body_path combined_path merged_path http_code message page page_count
  owner="$1"
  repo="$2"

  if [ -n "$release_json_path" ]; then
    jq -c '.' "$release_json_path"
    return 0
  fi

  combined_path="$(mktemp)"
  cleanup_files+=("$combined_path")
  printf '[]\n' > "$combined_path"

  page=1
  while :; do
    body_path="$(mktemp)"
    cleanup_files+=("$body_path")
    url="https://api.github.com/repos/${owner}/${repo}/releases?per_page=100&page=${page}"

    http_code="$(
      curl \
        --silent \
        --show-error \
        --location \
        --output "$body_path" \
        --write-out '%{http_code}' \
        --header 'Accept: application/vnd.github+json' \
        --header 'X-GitHub-Api-Version: 2022-11-28' \
        "$url"
    )" || fail "failed to fetch GitHub releases for ${owner}/${repo}"

    if [ "$http_code" != "200" ]; then
      message="$(jq -r '.message? // empty' "$body_path" 2>/dev/null || true)"
      if [ -n "$message" ]; then
        fail "GitHub releases request failed (${http_code}): ${message}"
      fi
      fail "GitHub releases request failed with status ${http_code}"
    fi

    jq -e 'type == "array"' "$body_path" >/dev/null || fail "GitHub releases response must be a JSON array"
    page_count="$(jq -r 'length' "$body_path")"

    merged_path="$(mktemp)"
    cleanup_files+=("$merged_path")
    jq -c -s '.[0] + .[1]' "$combined_path" "$body_path" > "$merged_path"
    mv "$merged_path" "$combined_path"

    if [ "$page_count" -lt 100 ]; then
      break
    fi

    page=$((page + 1))
  done

  jq -c '.' "$combined_path"
}

select_release_tag() {
  local payload selected
  payload="$1"

  jq -e '
    def normalize:
      if type == "array" then
        .
      elif type == "object" then
        [.]
      else
        error("expected a releases array or release object")
      end;

    normalize
    | if all(.[]; (.draft | type == "boolean") and (.prerelease | type == "boolean")) | not then
      error("release entries must include boolean draft and prerelease fields")
    elif all(.[]; (.draft or .prerelease) or ((.tag_name | type == "string" and length > 0) and (.published_at | type == "string" and length > 0))) | not then
      error("non-draft, non-prerelease releases must include tag_name and published_at")
    else
      .
    end
  ' >/dev/null <<<"$payload"

  selected="$(jq -er '
    def normalize:
      if type == "array" then
        .
      elif type == "object" then
        [.]
      else
        error("expected a releases array or release object")
      end;

    normalize
    | map(select(.draft == false and .prerelease == false))
    | sort_by(.published_at)
    | last
    | .tag_name // empty
  ' <<<"$payload" 2>/dev/null || true)"

  printf '%s\n' "$selected"
}

prefetch_hash() {
  local owner repo rev archive_url
  owner="$1"
  repo="$2"
  rev="$3"
  archive_url="https://github.com/${owner}/${repo}/archive/${rev}.tar.gz"

  nix store prefetch-file --json --unpack "$archive_url" | jq -er '.hash'
}

plugin_name=""
repo_root=""
hashes_path=""
release_json_path=""
manual_rev=""
manual_version=""
manual_hash=""
cleanup_files=()

trap 'rm -f "${cleanup_files[@]}"' EXIT

if [ "$#" -eq 0 ]; then
  usage >&2
  exit 1
fi

while [ "$#" -gt 0 ]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    --repo-root)
      [ "$#" -ge 2 ] || fail "missing value for --repo-root"
      repo_root="$2"
      shift 2
      ;;
    --hashes-path)
      [ "$#" -ge 2 ] || fail "missing value for --hashes-path"
      hashes_path="$2"
      shift 2
      ;;
    --release-json)
      [ "$#" -ge 2 ] || fail "missing value for --release-json"
      release_json_path="$2"
      shift 2
      ;;
    --hash)
      [ "$#" -ge 2 ] || fail "missing value for --hash"
      manual_hash="$2"
      shift 2
      ;;
    --rev)
      [ "$#" -ge 2 ] || fail "missing value for --rev"
      manual_rev="$2"
      shift 2
      ;;
    --version)
      [ "$#" -ge 2 ] || fail "missing value for --version"
      manual_version="$2"
      shift 2
      ;;
    --*)
      fail "unknown option: $1"
      ;;
    *)
      if [ -n "$plugin_name" ]; then
        fail "unexpected argument: $1"
      fi
      plugin_name="$1"
      shift
      ;;
  esac
done

[ -n "$plugin_name" ] || fail "missing plugin name"

require_command curl
require_command jq
require_command nix

if [ -z "$repo_root" ]; then
  script_dir="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"
  repo_root="$(CDPATH='' cd -- "${script_dir}/.." && pwd)"
fi

if [ -z "$hashes_path" ]; then
  hashes_path="${repo_root}/plugins/${plugin_name}/hashes.json"
fi

[ -f "$hashes_path" ] || fail "hash file not found: $hashes_path"
validate_hashes_file "$hashes_path" || fail "invalid hash file schema: $hashes_path"

if [ -n "$release_json_path" ] && [ ! -f "$release_json_path" ]; then
  fail "release fixture not found: $release_json_path"
fi

if [ -n "$manual_rev" ] || [ -n "$manual_version" ]; then
  [ -n "$manual_rev" ] && [ -n "$manual_version" ] || fail "--rev and --version must be supplied together"
fi

if [ -n "$manual_hash" ]; then
  [ -n "$release_json_path" ] || fail "--hash is only supported with --release-json for deterministic checks"
  [ "${DENOPS_PLUGINS_ALLOW_HASH_OVERRIDE:-}" = "1" ] || fail "--hash requires DENOPS_PLUGINS_ALLOW_HASH_OVERRIDE=1"
fi

owner="$(jq -er '.owner' "$hashes_path")"
repo="$(jq -er '.repo' "$hashes_path")"

if [ -n "$manual_rev" ]; then
  target_rev="$manual_rev"
  target_version="$manual_version"
else
  release_payload="$(load_release_payload "$owner" "$repo")"
  release_tag="$(select_release_tag "$release_payload")"

  if [ -n "$release_tag" ]; then
    target_rev="$release_tag"
    target_version="$release_tag"
  else
    fail "no qualifying GitHub release found for ${owner}/${repo}; provide --rev and --version"
  fi
fi

if [ -n "$manual_hash" ]; then
  target_hash="$manual_hash"
else
  target_hash="$(prefetch_hash "$owner" "$repo" "$target_rev")" || fail "failed to prefetch ${owner}/${repo} at ${target_rev}"
fi

temp_output="$(mktemp "${hashes_path}.tmp.XXXXXX")"
cleanup_files+=("$temp_output")

jq -n \
  --arg owner "$owner" \
  --arg repo "$repo" \
  --arg rev "$target_rev" \
  --arg hash "$target_hash" \
  --arg version "$target_version" \
  '{ owner: $owner, repo: $repo, rev: $rev, hash: $hash, version: $version }' > "$temp_output"

validate_hashes_file "$temp_output" || fail "generated hash file failed validation"

mv "$temp_output" "$hashes_path"
