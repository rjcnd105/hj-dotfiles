{
  description = "Nix Dotsfiles with flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    flake-utils-plus = {
      url = "github:gytis-ivaskevicius/flake-utils-plus";
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
    inputs@{
      self,
      nixpkgs,
      nix-darwin,
      home-manager,
      flake-utils-plus,
      agenix,
      disko,
      impermanence,
      nix-index-database,
      flake-parts,
      git-hooks,
      terranix,
      ...
    }:
    {
      darwinConfigurations = {
        hj =
          nix-darwin.lib.darwinSystem
            {
              system = "aarch64-darwin";
              modules = [
                home-manager.darwinModules.home-manager
                {
                  home-manager.useGlobalPkgs = true;
                  home-manager.useUserPackages = true;

                  home-manager.users.${user}.imports = home;
                  home-manager.extraSpecialArgs = extraHomeManagerArgs;
                }
              ];
            }
            lib.mkFlake
            {

              debug = true;
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

                # my-input.homeModules.my-module
              ];

              outputs-builder = channels: { formatter = channels.nixpkgs.nixfmt-rfc-style; };
            };
      };
    };

}
