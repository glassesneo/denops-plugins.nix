{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs = inputs @ {flake-parts, ...}:
    flake-parts.lib.mkFlake {inherit inputs;} ({...}: let
      overlay = import ./overlays/default.nix;
      hashSchemaCheck = path: ''
        jq -e '
          type == "object" and
          ((keys | sort) == ["hash", "owner", "repo", "rev", "version"]) and
          (.owner | type == "string" and length > 0) and
          (.repo | type == "string" and length > 0) and
          (.rev | type == "string" and length > 0) and
          (.hash | type == "string" and test("^sha256-[A-Za-z0-9+/]{43}=$")) and
          (.version | type == "string" and length > 0)
        ' "${path}" >/dev/null
      '';
    in {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];

      flake = {
        overlays.default = overlay;
      };

      perSystem = {
        pkgs,
        system,
        ...
      }: let
        plugins = import ./plugins {
          inherit pkgs;
          lib = pkgs.lib;
        };

        overlayPkgs = import inputs.nixpkgs {
          inherit system;
          overlays = [overlay];
        };

        overlayVimPackageInfo = overlayPkgs.neovimUtils.makeVimPackageInfo [
          overlayPkgs.vimPlugins.skkeleton
          overlayPkgs.vimPlugins.kensaku
          overlayPkgs.vimPlugins.kensaku-search
          overlayPkgs.vimPlugins.fuzzy-motion
        ];

        overlayPackDir = overlayPkgs.neovimUtils.packDir {
          repoCheck = overlayVimPackageInfo.vimPackage;
        };
      in {
        packages = plugins;

        checks = {
          overlay-consumer = overlayPkgs.runCommandNoCC "overlay-consumer" {} ''
            test -d "${overlayPackDir}/pack/repoCheck/start/skkeleton"
            test -d "${overlayPackDir}/pack/repoCheck/start/kensaku"
            test -d "${overlayPackDir}/pack/repoCheck/start/kensaku-search"
            test -d "${overlayPackDir}/pack/repoCheck/start/fuzzy-motion"
            test -d "${overlayPackDir}/pack/repoCheck/start/denops.vim"
            touch "$out"
          '';

          update-script-success =
            pkgs.runCommandNoCC "update-script-success" {
              nativeBuildInputs = [
                pkgs.bash
                pkgs.coreutils
                pkgs.curl
                pkgs.jq
                pkgs.nix
              ];
            } ''
              repo_copy="$TMPDIR/repo"
              mkdir -p "$repo_copy/plugins/skkeleton" "$repo_copy/scripts" "$repo_copy/tests/fixtures/github-releases"

              cp ${./plugins/skkeleton/hashes.json} "$repo_copy/plugins/skkeleton/hashes.json"
              cp ${./scripts/update-plugin.sh} "$repo_copy/scripts/update-plugin.sh"
              cp ${./tests/fixtures/github-releases/qualifying.json} "$repo_copy/tests/fixtures/github-releases/qualifying.json"

              chmod +x "$repo_copy/scripts/update-plugin.sh"
              export DENOPS_PLUGINS_ALLOW_HASH_OVERRIDE=1

              "$repo_copy/scripts/update-plugin.sh" skkeleton \
                --repo-root "$repo_copy" \
                --release-json "$repo_copy/tests/fixtures/github-releases/qualifying.json" \
                --hash sha256-FqGK4IgD75etYRpdr4NaBHQvlBL5Cx9q0SOy+IoUXoU=

              ${hashSchemaCheck "$repo_copy/plugins/skkeleton/hashes.json"}
              jq -e '.rev == "2.0.2" and .version == "2.0.2"' "$repo_copy/plugins/skkeleton/hashes.json" >/dev/null

              touch "$out"
            '';

          update-script-no-release =
            pkgs.runCommandNoCC "update-script-no-release" {
              nativeBuildInputs = [
                pkgs.bash
                pkgs.coreutils
                pkgs.curl
                pkgs.jq
                pkgs.nix
              ];
            } ''
              repo_copy="$TMPDIR/repo"
              original_hashes="$TMPDIR/original-hashes.json"

              mkdir -p "$repo_copy/plugins/skkeleton" "$repo_copy/scripts" "$repo_copy/tests/fixtures/github-releases"

              cp ${./plugins/skkeleton/hashes.json} "$repo_copy/plugins/skkeleton/hashes.json"
              cp "$repo_copy/plugins/skkeleton/hashes.json" "$original_hashes"
              cp ${./scripts/update-plugin.sh} "$repo_copy/scripts/update-plugin.sh"
              cp ${./tests/fixtures/github-releases/no-qualifying.json} "$repo_copy/tests/fixtures/github-releases/no-qualifying.json"

              chmod +x "$repo_copy/scripts/update-plugin.sh"

              if "$repo_copy/scripts/update-plugin.sh" skkeleton \
                --repo-root "$repo_copy" \
                --release-json "$repo_copy/tests/fixtures/github-releases/no-qualifying.json"
              then
                echo "expected update without overrides to fail"
                exit 1
              fi

              cmp -s "$original_hashes" "$repo_copy/plugins/skkeleton/hashes.json"
              touch "$out"
            '';

          update-script-manual-override =
            pkgs.runCommandNoCC "update-script-manual-override" {
              nativeBuildInputs = [
                pkgs.bash
                pkgs.coreutils
                pkgs.curl
                pkgs.jq
                pkgs.nix
              ];
            } ''
              repo_copy="$TMPDIR/repo"

              mkdir -p "$repo_copy/plugins/skkeleton" "$repo_copy/scripts" "$repo_copy/tests/fixtures/github-releases"

              cp ${./plugins/skkeleton/hashes.json} "$repo_copy/plugins/skkeleton/hashes.json"
              cp ${./scripts/update-plugin.sh} "$repo_copy/scripts/update-plugin.sh"
              cp ${./tests/fixtures/github-releases/no-qualifying.json} "$repo_copy/tests/fixtures/github-releases/no-qualifying.json"

              chmod +x "$repo_copy/scripts/update-plugin.sh"
              export DENOPS_PLUGINS_ALLOW_HASH_OVERRIDE=1

              "$repo_copy/scripts/update-plugin.sh" skkeleton \
                --repo-root "$repo_copy" \
                --release-json "$repo_copy/tests/fixtures/github-releases/no-qualifying.json" \
                --hash sha256-QgbKRvEWcoaFQfoszaNyv3B7C3jO+E6dg6NaaXkwggc= \
                --rev 2.0.1 \
                --version 2.0.1

              ${hashSchemaCheck "$repo_copy/plugins/skkeleton/hashes.json"}
              jq -e '.rev == "2.0.1" and .version == "2.0.1"' "$repo_copy/plugins/skkeleton/hashes.json" >/dev/null

              touch "$out"
            '';

          update-script-validation-failure =
            pkgs.runCommandNoCC "update-script-validation-failure" {
              nativeBuildInputs = [
                pkgs.bash
                pkgs.coreutils
                pkgs.curl
                pkgs.jq
                pkgs.nix
              ];
            } ''
              repo_copy="$TMPDIR/repo"
              original_hashes="$TMPDIR/original-hashes.json"

              mkdir -p "$repo_copy/plugins/skkeleton" "$repo_copy/scripts" "$repo_copy/tests/fixtures/github-releases"

              cp ${./plugins/skkeleton/hashes.json} "$repo_copy/plugins/skkeleton/hashes.json"
              cp "$repo_copy/plugins/skkeleton/hashes.json" "$original_hashes"

              cp ${./scripts/update-plugin.sh} "$repo_copy/scripts/update-plugin.sh"
              cp ${./tests/fixtures/github-releases/qualifying.json} "$repo_copy/tests/fixtures/github-releases/qualifying.json"

              chmod +x "$repo_copy/scripts/update-plugin.sh"
              export DENOPS_PLUGINS_ALLOW_HASH_OVERRIDE=1

              if "$repo_copy/scripts/update-plugin.sh" skkeleton \
                --repo-root "$repo_copy" \
                --release-json "$repo_copy/tests/fixtures/github-releases/qualifying.json" \
                --hash sha256-not-a-real-hash
              then
                echo "expected validation failure to fail"
                exit 1
              fi

              cmp -s "$original_hashes" "$repo_copy/plugins/skkeleton/hashes.json"
              touch "$out"
            '';

          update-script-malformed-json =
            pkgs.runCommandNoCC "update-script-malformed-json" {
              nativeBuildInputs = [
                pkgs.bash
                pkgs.coreutils
                pkgs.curl
                pkgs.jq
                pkgs.nix
              ];
            } ''
              repo_copy="$TMPDIR/repo"
              original_hashes="$TMPDIR/original-hashes.json"

              mkdir -p "$repo_copy/plugins/skkeleton" "$repo_copy/scripts" "$repo_copy/tests/fixtures/github-releases"

              cp ${./plugins/skkeleton/hashes.json} "$repo_copy/plugins/skkeleton/hashes.json"
              cp "$repo_copy/plugins/skkeleton/hashes.json" "$original_hashes"
              cp ${./scripts/update-plugin.sh} "$repo_copy/scripts/update-plugin.sh"
              printf '{ invalid json\n' > "$repo_copy/tests/fixtures/github-releases/malformed.json"

              chmod +x "$repo_copy/scripts/update-plugin.sh"

              if "$repo_copy/scripts/update-plugin.sh" skkeleton \
                --repo-root "$repo_copy" \
                --release-json "$repo_copy/tests/fixtures/github-releases/malformed.json"
              then
                echo "expected malformed JSON to fail"
                exit 1
              fi

              cmp -s "$original_hashes" "$repo_copy/plugins/skkeleton/hashes.json"
              touch "$out"
            '';

          update-script-missing-release-fields =
            pkgs.runCommandNoCC "update-script-missing-release-fields" {
              nativeBuildInputs = [
                pkgs.bash
                pkgs.coreutils
                pkgs.curl
                pkgs.jq
                pkgs.nix
              ];
            } ''
              repo_copy="$TMPDIR/repo"
              original_hashes="$TMPDIR/original-hashes.json"

              mkdir -p "$repo_copy/plugins/skkeleton" "$repo_copy/scripts" "$repo_copy/tests/fixtures/github-releases"

              cp ${./plugins/skkeleton/hashes.json} "$repo_copy/plugins/skkeleton/hashes.json"
              cp "$repo_copy/plugins/skkeleton/hashes.json" "$original_hashes"
              cp ${./scripts/update-plugin.sh} "$repo_copy/scripts/update-plugin.sh"
              cat > "$repo_copy/tests/fixtures/github-releases/missing-fields.json" <<'EOF'
              [
                {
                  "draft": false,
                  "prerelease": false,
                  "published_at": "2024-09-01T00:00:00Z"
                }
              ]
              EOF

              chmod +x "$repo_copy/scripts/update-plugin.sh"

              if "$repo_copy/scripts/update-plugin.sh" skkeleton \
                --repo-root "$repo_copy" \
                --release-json "$repo_copy/tests/fixtures/github-releases/missing-fields.json"
              then
                echo "expected missing release fields to fail"
                exit 1
              fi

              cmp -s "$original_hashes" "$repo_copy/plugins/skkeleton/hashes.json"
              touch "$out"
            '';
        };

        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            curl
            jq
          ];
        };
      };
    });
}
