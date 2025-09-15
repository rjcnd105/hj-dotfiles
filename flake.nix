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
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    catppuccin.url = "github:catppuccin/nix";

    # mise = {
    #   url = "github:jdx/mise/v2025.2.7";
    #   inputs.nixpkgs.follows = "nixpkgs";
    # };

  };

  outputs =
    inputs@{
      self,
      catppuccin,
      nixpkgs,
      home-manager,
      darwin,
      sops-nix,
    # mise,
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
      myLib = import ./config/lib.nix {
        inherit lib;
        pkgs = nixpkgs;
      };

      envVars = import ./env.nix;

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
      _debug = {
        inherit envVars;
      };

      darwinConfigurations = lib.mapAttrs (
        key: config:
        let
          split = builtins.split "_" key;
          hostName = builtins.elemAt split 0;
          userName = builtins.elemAt split 2;
          myOptions = {
            inherit key;
            inherit (config) email;
            inherit hostName userName;
            paths = myLib.config.paths;
            absoluteProjectPath = envVars.PWD;
            _debug = { };
          };

          systemModulePaths = getModulePaths "systems" config.system hostName userName;
          homeModulePaths = getModulePaths "homes" config.system hostName userName;

          nixpkgsConfig = system: {
            inherit system;
            # overlays = [
            #   (final: prev: {
            #     mise = prev.callPackage (mise + "/default.nix") { };
            #   })
            # ];

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
            inherit inputs myOptions;
          };
          modules = [
            {
              nixpkgs = nixpkgsConfig config.system;
            }
            home-manager.darwinModules.home-manager
            {
              home-manager = {
                users.${userName}.imports = homeModulePaths;

              };
            }
          ]
          ++ systemModulePaths;
        }
      ) hosts;

      templates = {
        phoenix = {
          path = ./templates/phoenix;
          description = "my phoenix template";
        };
      };
    };
}
