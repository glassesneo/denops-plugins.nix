{pkgs, lib ? pkgs.lib, vimPlugins ? pkgs.vimPlugins}: {
  mkDenopsPlugin = import ./mkDenopsPlugin.nix {
    inherit lib pkgs vimPlugins;
  };
}
