{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    devenv.url = "github:cachix/devenv";
  };
  outputs =
    inputs@{ flake-parts, nixpkgs, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        inputs.devenv.flakeModule
        inputs.flake-parts.flakeModules.easyOverlay
      ];
      systems = [
        "aarch64-darwin"
        "aarch64-linux"
        "x86_64-linux"
      ];
      debug = true;

      perSystem =
        {
          config,
          self',
          inputs',
          pkgs,
          system,
          ...
        }:
        {

          # Equivalent to  inputs'.nixpkgs.legacyPackages.hello;
          packages.default = [
            pkgs.gh
            pkgs.hello
          ];

          devenv.shells.default = {
            # https://devenv.sh/reference/options/
            packages = [ config.packages.default ];
            imports = [ ./devenv.nix ];
          };
        };
    };
}
