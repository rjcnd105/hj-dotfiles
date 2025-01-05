{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    devenv.url = "github:cachix/devenv";
    mise = {
      url = "github:jdx/mise/release";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs =
    inputs@{
      flake-parts,
      nixpkgs,
      mise,
      ...
    }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        inputs.flake-parts.flakeModules.easyOverlay
        inputs.devenv.flakeModule
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
        let
          pkgs = import nixpkgs {
            system = system;
            overlays = [
              (final: prev: {
                mise = prev.callPackage (mise + "/default.nix") { };
              })
            ];
          };
        in
        {

          packages.default = [
            pkgs.gh
            pkgs.hello
            pkgs.mise
          ];

          devenv.shells.default = {
            imports = [ ./devenv-phoenix.nix ];
            # https://devenv.sh/reference/options/
            packages = [ config.packages.default ];

            enterShell = ''
              echo hello
            '';

          };
        };
    };
}
