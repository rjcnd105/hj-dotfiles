{
  description = "Nix Dotsfiles with flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    snowfall-lib = {
      url = "github:snowfallorg/lib";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    catppuccin.url = "github:catppuccin/nix";
    nix-index-database.url = "github:nix-community/nix-index-database";
    darwin = {
      url = "github:lnl7/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # In order to build system images and artifacts supported by nixos-generators.
    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/0.1";

    # Comma
    comma = {
      url = "github:nix-community/comma";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs:
    let
      lib = inputs.snowfall-lib.mkLib {
        inherit inputs;
        src = ./.;

        snowfall = {
          meta = {
            name = "hj-flake";
            title = "hj flake";
          };

          namespace = "hj";
        };
      };
    in
    lib.mkFlake {

      channels-config = {
        allowUnfree = true;
      };

      system.modules.nixos = with inputs; [
        determinate.nixosModules.default
        # determinate.nixosModules.default
      ];
      # Add modules to all Darwin systems.
      systems.modules.darwin = with inputs; [
        determinate.darwinModules.default
      ];

      # Add modules to all homes.
      homes.modules = with inputs; [
        nix-index-database.hmModules.nix-index
        # my-input.homeModules.my-module
      ];

      outputs-builder = channels: { formatter = channels.nixpkgs.nixfmt-rfc-style; };
    }
    // {
      self = inputs.self;
    };

}
