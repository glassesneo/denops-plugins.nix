# denops-plugins.nix

`denops-plugins.nix` packages denops-based Vim and Neovim plugins that are still missing from nixpkgs. The first packaged plugin is `skkeleton`, and the repository exports both direct package outputs and an overlay that extends `pkgs.vimPlugins` with upstream plugin names.

## Supported systems

- `x86_64-linux`
- `aarch64-linux`
- `x86_64-darwin`
- `aarch64-darwin`

The repository evaluates on all four systems. Version 1 verifies real builds on the host system only.

## Runtime requirements

Every packaged denops plugin in this repository carries `pkgs.vimPlugins.denops-vim` through the plugin `dependencies` attribute, so overlay consumers do not need to add `denops-vim` separately. You still need a compatible `deno` available inside the editor runtime environment.

That means a working setup always needs all three layers:

1. the plugin itself, such as `skkeleton`
2. `denops.vim`, supplied automatically by this repository's plugin metadata
3. `deno`, supplied by your shell, wrapper, Home Manager config, or explicit editor configuration

## Direct package usage

From a local checkout:

```sh
nix build .#skkeleton
```

From another flake:

```nix
{
  inputs.denops-plugins.url = "github:<owner>/denops-plugins.nix";

  outputs = { self, nixpkgs, denops-plugins, ... }:
    let
      system = "aarch64-darwin";
      pkgs = import nixpkgs { inherit system; };
    in {
      packages.${system}.default = pkgs.symlinkJoin {
        name = "editor-plugins";
        paths = [ denops-plugins.packages.${system}.skkeleton ];
      };
    };
}
```

## Overlay usage

```nix
{
  inputs.denops-plugins.url = "github:<owner>/denops-plugins.nix";

  outputs = { self, nixpkgs, denops-plugins, ... }:
    let
      system = "aarch64-darwin";
      pkgs = import nixpkgs {
        inherit system;
        overlays = [ denops-plugins.overlays.default ];
      };
    in {
      packages.${system}.default = pkgs.neovimUtils.packDir {
        myPlugins = {
          start = [ pkgs.vimPlugins.skkeleton ];
          opt = [];
        };
      };
    };
}
```

The overlay intentionally wins on name collisions inside `pkgs.vimPlugins`. If nixpkgs later adds the same plugin and you want the upstream version back for one name, import a clean nixpkgs package set and restore that plugin in a follow-up overlay:

```nix
let
  system = "aarch64-darwin";
  upstreamPkgs = import nixpkgs { inherit system; };
  pkgs = import nixpkgs {
    inherit system;
    overlays = [
      denops-plugins.overlays.default
      (final: prev: {
        vimPlugins = prev.vimPlugins // {
          skkeleton = upstreamPkgs.vimPlugins.skkeleton;
        };
      })
    ];
  };
in
pkgs.vimPlugins.skkeleton
```

## Home Manager usage

Keep Home Manager on the same `nixpkgs` revision and let Neovim wrap runtime dependencies automatically:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    denops-plugins.url = "github:<owner>/denops-plugins.nix";
  };

  outputs = { nixpkgs, home-manager, denops-plugins, ... }:
    let
      system = "aarch64-darwin";
      pkgs = import nixpkgs {
        inherit system;
        overlays = [ denops-plugins.overlays.default ];
      };
    in {
      homeConfigurations.me = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [
          {
            programs.neovim = {
              enable = true;
              autowrapRuntimeDeps = true;
              plugins = [ pkgs.vimPlugins.skkeleton ];
            };
          }
        ];
      };
    };
}
```

If you do not use `autowrapRuntimeDeps = true`, make sure `deno` still reaches the editor runtime through another path such as `programs.neovim.extraPackages = [ pkgs.deno ];`.

## Repository layout

- `plugins/default.nix` is the single plugin registry used by both `packages` and the overlay.
- `plugins/<name>/hashes.json` stores the source pin as `{ owner, repo, rev, hash, version }`.
- `lib/mkDenopsPlugin.nix` wraps `buildVimPlugin` and injects `denops-vim` plus `runtimeDeps` metadata.
- `scripts/update-plugin.sh` refreshes one plugin pin at a time.

## Updating plugins

Version 1 supports GitHub-hosted plugins only and fetches repository snapshots with `fetchFromGitHub { owner; repo; rev; hash; }`.

If a plugin publishes GitHub Releases, the updater selects the newest non-draft, non-prerelease release by `published_at` and sets both `rev` and `version` to that release's `tag_name`.

If a plugin does not publish qualifying releases, pass manual overrides instead. `skkeleton` currently needs that path:

```sh
./scripts/update-plugin.sh skkeleton --rev 2.0.2 --version 2.0.2
```

See `CONTRIBUTING.md` for the full maintainer workflow.
