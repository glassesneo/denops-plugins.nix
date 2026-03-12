{pkgs, lib ? pkgs.lib, vimPlugins ? pkgs.vimPlugins}:
let
  helpers = import ../lib {
    inherit lib pkgs vimPlugins;
  };

  kensaku = import ./kensaku {
    inherit helpers lib pkgs;
  };
in {
  inherit kensaku;

  kensaku-search = import ./kensaku-search {
    inherit helpers lib pkgs kensaku;
  };

  fuzzy-motion = import ./fuzzy-motion {
    inherit helpers lib pkgs kensaku;
  };

  skkeleton = import ./skkeleton {
    inherit helpers lib pkgs;
  };
}
