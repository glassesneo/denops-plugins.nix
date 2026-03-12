{
  pkgs,
  lib ? pkgs.lib,
  helpers,
  kensaku,
}:
let
  pin = builtins.fromJSON (builtins.readFile ./hashes.json);
in
helpers.mkDenopsPlugin {
  pname = "fuzzy-motion";
  version = pin.version;
  src = pkgs.fetchFromGitHub {
    inherit (pin) hash owner repo rev;
  };
  dependencies = [kensaku];
  runtimeDeps = [pkgs.deno];
  meta = with lib; {
    description = "Fuzzy motion plugin for Vim/Neovim powered by denops.vim";
    homepage = "https://github.com/${pin.owner}/${pin.repo}";
    license = licenses.mit;
  };
}
