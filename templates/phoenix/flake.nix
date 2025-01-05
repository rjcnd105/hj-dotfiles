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
        {
          _module.args.pkgs = import inputs.nixpkgs {
            inherit system;
            overlays = [
              (final: prev: {
                mise = prev.callPackage (mise + "/default.nix") { };
              })
            ];
          };
          packages.default = [
            pkgs.gh
            pkgs.hello
            pkgs.mise
          ];

          devenv.shells.default = {
            # https://devenv.sh/reference/options/
            packages = [ config.packages.default ];
            imports = [ ./devenv.nix ];

          };
        };
    };
}
