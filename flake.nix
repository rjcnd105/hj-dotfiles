{
  description = "A highly awesome system configuration.";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    inputs.nixvim = {
      url = "github:nix-community/nixvim";
      # If you are not running an unstable channel of nixpkgs, select the corresponding branch of nixvim.
      # url = "github:nix-community/nixvim/nixos-24.11";

      inputs.nixpkgs.follows = "nixpkgs";
    };

    catppuccin.url = "github:catppuccin/nix";
    darwin = {
      url = "github:lnl7/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-index-database.url = "github:nix-community/nix-index-database";
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
      catppuccin,
      nix-index-database,
      nixvim,
      comma,
      determinate,
      nixpkgs,
      home-manager,
      darwin,
    }:
    let
      # 형태는 ${host}_${username}
      hosts = {
        workspace_hj = {
          system = "aarch64-darwin";
        };
      };
      lib = nixpkgs.lib;

      getModulePaths =
        prefix: system: host: user:
        builtins.filter builtins.pathExists [
          ./${prefix}/default.nix
          ./${prefix}/${system}/default.nix
          ./${prefix}/${system}/${host}/default.nix
          ./${prefix}/${system}/${host}/${user}/default.nix
          ./${prefix}/${host}/default.nix
          ./${prefix}/${host}/${user}/default.nix
        ];
    in
    {
      darwinConfigurations = lib.mapAttrs (
        key: config:
        let
          split = builtins.split "_" key;
          hostName = builtins.elemAt split 0;
          userName = builtins.elemAt split 2;
          customConfig = {
            inherit hostName userName;
            host_userName = key;
          };
          systemModulePaths = getModulePaths "systems" config.system hostName userName;
          homeModulePaths = getModulePaths "homes" config.system hostName userName;
        in
        darwin.lib.darwinSystem {
          system = config.system;
          specialArgs = {
            inherit inputs customConfig;
          };
          modules = [
            home-manager.darwinModules.home-manager
            {
              home-manager = {
                users.${userName}.imports = homeModulePaths;
                extraSpecialArgs = {
                  inherit inputs customConfig;
                };

              };
            }
          ] ++ systemModulePaths;
        }
      ) hosts;
    };
}
