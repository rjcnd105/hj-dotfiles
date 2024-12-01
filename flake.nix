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
    inputs.snowfall-lib.mkFlake {
      # You must provide our flake inputs to Snowfall Lib.
      inherit inputs;

      # The `src` must be the root of the flake. See configuration
      # in the next section for information on how you can move your
      # Nix files to a separate directory.
      src = ./.;
      overlays = [ ];
      snowfall = {
        # namespace = "hj-namespace";
        meta = {
          name = "hj-flake";
          title = "hj flake";
        };
      };

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

      outputs-builder = channels: { formatter = channels.nixpkgs.nixfmt-rfc-style; };
    };

}
