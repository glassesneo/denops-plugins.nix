# Contributing

## Repository layout

- `flake.nix` wires the shared plugin registry into `packages`, `overlays.default`, and repo-owned checks.
- `lib/mkDenopsPlugin.nix` is the shared denops helper.
- `plugins/default.nix` is the single source of truth for packaged plugins.
- `plugins/<name>/default.nix` defines one plugin derivation.
- `plugins/<name>/hashes.json` stores one pin in the fixed schema `{ owner, repo, rev, hash, version }`.
- `tests/fixtures/github-releases/*.json` stores deterministic updater fixtures.

## Adding a plugin

1. Create `plugins/<name>/hashes.json` with `owner`, `repo`, `rev`, `hash`, and `version`.
2. Create `plugins/<name>/default.nix` and build it with `helpers.mkDenopsPlugin`.
3. Register the plugin in `plugins/default.nix` under the upstream plugin name.
4. Add or extend documentation in `README.md` if the plugin has extra runtime caveats.
5. Run `nix flake show`, `nix build .#<name>`, and `nix flake check` on the host system.

## Updating a plugin

The updater uses portable Bash plus `curl`, `jq`, and `nix`. It validates the new source before writing anything and replaces `plugins/<name>/hashes.json` atomically.

For a plugin with qualifying GitHub Releases:

```sh
./scripts/update-plugin.sh <name>
```

For a plugin without qualifying releases, provide manual overrides:

```sh
./scripts/update-plugin.sh skkeleton --rev 2.0.2 --version 2.0.2
```

The script supports repo-owned fixture checks and other writable temp trees:

```sh
DENOPS_PLUGINS_ALLOW_HASH_OVERRIDE=1 \
./scripts/update-plugin.sh skkeleton \
  --repo-root /tmp/repo-copy \
  --release-json /tmp/repo-copy/tests/fixtures/github-releases/qualifying.json \
  --hash sha256-FqGK4IgD75etYRpdr4NaBHQvlBL5Cx9q0SOy+IoUXoU=
```

You can also target one copied pin file directly:

```sh
DENOPS_PLUGINS_ALLOW_HASH_OVERRIDE=1 \
./scripts/update-plugin.sh skkeleton \
  --hashes-path /tmp/repo-copy/plugins/skkeleton/hashes.json \
  --release-json /tmp/repo-copy/tests/fixtures/github-releases/no-qualifying.json \
  --hash sha256-QgbKRvEWcoaFQfoszaNyv3B7C3jO+E6dg6NaaXkwggc= \
  --rev 2.0.1 \
  --version 2.0.1
```

`--hash` is reserved for deterministic fixture-backed checks and is rejected unless `DENOPS_PLUGINS_ALLOW_HASH_OVERRIDE=1` is set.

## Failure handling and rollback

- Failed updates exit nonzero and leave the existing `hashes.json` unchanged.
- `nix flake check` covers success, no-release, manual-override, and validation-failure branches on writable temp copies.
- If a successful update turns out to be bad, restore the pin with version control, for example `git restore plugins/skkeleton/hashes.json`.

## Source support

Version 1 supports GitHub-hosted plugins only. The current update workflow assumes GitHub Releases for automatic discovery and always hashes the same repository snapshot tarball shape used by `fetchFromGitHub`.
