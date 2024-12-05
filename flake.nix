{
  description = "A highly awesome system configuration.";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };


    darwin = {
      url = "github:lnl7/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixvim = {
      url = "github:nix-community/nixvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    Neve = {
      url = "github:redyf/Neve";
    };

    catppuccin.url = "github:catppuccin/nix";

    nix-index-database.url = "github:nix-community/nix-index-database";

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
      Neve,
      comma,
      nixpkgs,
      home-manager,
      darwin,
    }:
    let
      # 형태는 ${host}_${username}
      hosts = {
        workspace_hj = {
          system = "aarch64-darwin";
          email = "rjcnd123@gmail.com";
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
            inherit (config) email;
            inherit hostName userName;
            host_userName = key;
          };
          systemModulePaths = getModulePaths "systems" config.system hostName userName;
          homeModulePaths = getModulePaths "homes" config.system hostName userName;

          nixpkgsConfig = system: {
            inherit system;
            config = {
              allowUnfreePredicate =
                pkg:
                builtins.elem (lib.getName pkg) [
                  "vault"
                ];
            };
          };
        in
        darwin.lib.darwinSystem {
          system = config.system;
          specialArgs = {
            inherit inputs customConfig;
          };
          modules = [
            ./config/options.nix
            {
              nixpkgs = nixpkgsConfig config.system;
            }
            home-manager.darwinModules.home-manager
            {
              home-manager = {
                users.${userName}.imports = homeModulePaths;

              };
            }
          ] ++ systemModulePaths;
        }
      ) hosts;
    };
}
