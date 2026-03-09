{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs = inputs @ {flake-parts, ...}:
    flake-parts.lib.mkFlake {inherit inputs;} (top @ {
      # config,
      # withSystem,
      # moduleWithSystem,
      ...
    }: {
      imports = [];
      flake = {};
      systems = [
        # systems for which you want to build the `perSystem` attributes
        "x86_64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
        # ...
      ];
      perSystem = {
        # config,
        pkgs,
        ...
      }: {
        devShells = {
          default = pkgs.mkShell {
            packages = with pkgs; [];
          };
        };
      };
    });
}
