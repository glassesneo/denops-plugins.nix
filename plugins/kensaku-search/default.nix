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
  pname = "kensaku-search";
  version = pin.version;
  src = pkgs.fetchFromGitHub {
    inherit (pin) hash owner repo rev;
  };
  dependencies = [kensaku];
  meta = with lib; {
    description = "Use kensaku.vim as search with / command";
    homepage = "https://github.com/${pin.owner}/${pin.repo}";
    license = licenses.mit;
  };
}
