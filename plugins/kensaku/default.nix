{
  pkgs,
  lib ? pkgs.lib,
  helpers,
}:
let
  pin = builtins.fromJSON (builtins.readFile ./hashes.json);
in
helpers.mkDenopsPlugin {
  pname = "kensaku";
  version = pin.version;
  src = pkgs.fetchFromGitHub {
    inherit (pin) hash owner repo rev;
  };
  runtimeDeps = [pkgs.deno];
  meta = with lib; {
    description = "Fuzzy Japanese search for Vim/Neovim powered by denops.vim";
    homepage = "https://github.com/${pin.owner}/${pin.repo}";
    license = licenses.mit;
  };
}
