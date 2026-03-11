final: prev: {
  vimPlugins = prev.vimPlugins // import ../plugins {
    pkgs = final;
    lib = final.lib;
    vimPlugins = final.vimPlugins;
  };
}
