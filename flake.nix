{
  description = "A highly awesome system configuration.";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager/master";
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
      nixpkgs,
      home-manager,
      comma,
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
          ./${prefix}
          ./${prefix}/${system}
          ./${prefix}/${system}/${host}
          ./${prefix}/${system}/${host}/${user}
          ./${prefix}/${host}
          ./${prefix}/${host}/${user}
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
          moduleMoudlePaths = getModulePaths "modules" config.system hostName userName;
          homeModulePaths = getModulePaths "homes" config.system hostName userName;
        in
        {
          "${key}" = darwin.lib.darwinSystem {
            system = config.system;
            specialArgs = {
              inherit inputs customConfig;
            };
            extraSpecialArgs = {
              inherit inputs customConfig;
            };
            allowUnfree = true;
            modules = [
              {
                home-manager.users.${userName}.modules = homeModulePaths;
                home-manager.extraSpecialArgs = {
                  inherit inputs customConfig;
                };
              }
            ] ++ systemModulePaths ++ moduleMoudlePaths;
          };
        }
      ) hosts;
    };
}
