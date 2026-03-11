{
  pkgs,
  lib ? pkgs.lib,
  helpers,
  ...
}:
let
  pin = builtins.fromJSON (builtins.readFile ./hashes.json);
in
helpers.mkDenopsPlugin {
  pname = "skkeleton";
  version = pin.version;
  src = pkgs.fetchFromGitHub {
    inherit (pin) hash owner repo rev;
  };
  runtimeDeps = [pkgs.deno];
  meta = with lib; {
    description = "SKK for Vim and Neovim powered by denops.vim";
    homepage = "https://github.com/${pin.owner}/${pin.repo}";
    license = licenses.zlib;
  };
}
