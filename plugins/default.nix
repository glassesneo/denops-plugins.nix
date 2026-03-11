{pkgs, lib ? pkgs.lib, vimPlugins ? pkgs.vimPlugins}:
let
  helpers = import ../lib {
    inherit lib pkgs vimPlugins;
  };
in {
  skkeleton = import ./skkeleton {
    inherit helpers lib pkgs vimPlugins;
  };
}
