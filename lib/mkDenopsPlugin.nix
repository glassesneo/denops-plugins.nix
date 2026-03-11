{pkgs, lib ? pkgs.lib, vimPlugins ? pkgs.vimPlugins}:
let
  supportedSystems = [
    "x86_64-linux"
    "aarch64-linux"
    "x86_64-darwin"
    "aarch64-darwin"
  ];

  uniqueDerivations =
    derivations:
    builtins.foldl'
      (
        acc: drv:
        if lib.any (candidate: candidate.outPath == drv.outPath) acc then acc else acc ++ [drv]
      )
      []
      derivations;
in
/*
  Wrap `buildVimPlugin` for denops-based plugins and keep plugin/runtime
  dependency metadata aligned with nixpkgs and Home Manager consumers.
*/
{
  pname,
  version,
  src,
  dependencies ? [],
  runtimeDeps ? [],
  passthru ? {},
  meta ? {},
  ...
}@args:
let
  mergedDependencies = uniqueDerivations ([vimPlugins.denops-vim] ++ dependencies);
  mergedRuntimeDeps = uniqueDerivations ((passthru.runtimeDeps or []) ++ runtimeDeps);
  buildArgs = builtins.removeAttrs args [
    "dependencies"
    "runtimeDeps"
    "passthru"
    "meta"
  ];
in
pkgs.vimUtils.buildVimPlugin (buildArgs // {
  inherit pname src version;
  dependencies = mergedDependencies;
  runtimeDeps = mergedRuntimeDeps;
  passthru = passthru // {
    denopsPlugin = true;
    runtimeDeps = mergedRuntimeDeps;
  };
  meta = meta // {
    platforms = meta.platforms or supportedSystems;
  };
})
