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

    comin = {
      url = "github:nlewo/comin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

  };

  outputs =
    inputs@{
      self,
      catppuccin,
      nixpkgs,
      home-manager,
      darwin,
      sops-nix,
      comin,
    }:
    let
      # 형태는 ${host}_${username}
      hosts = {
        workspace_hj = {
          system = "aarch64-darwin";
          email = "rjcnd123@gmail.com";
        };
        homelab_hj = {
          system = "x86_64-linux";
          email = "rjcnd123@gmail.com";
          filesHost = "workspace";
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

      darwinHosts = lib.filterAttrs (_: v: lib.hasSuffix "darwin" v.system) hosts;
      linuxHosts = lib.filterAttrs (_: v: lib.hasSuffix "linux" v.system) hosts;

      parseHostKey =
        key: config:
        let
          split = builtins.split "_" key;
          hostName = builtins.elemAt split 0;
          userName = builtins.elemAt split 2;
        in
        {
          inherit hostName userName;
          myOptions = {
            inherit key;
            inherit (config) email system;
            inherit hostName userName;
            filesHost = config.filesHost or hostName;
            paths = myLib.config.paths;
            absoluteProjectPath = envVars.PWD;
            _debug = { };
          };
        };

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
    {
      _debug = {
        inherit envVars;
      };

      darwinConfigurations = lib.mapAttrs (
        key: config:
        let
          parsed = parseHostKey key config;
          inherit (parsed) hostName userName myOptions;
          systemModulePaths = getModulePaths "systems" config.system hostName userName;
          homeModulePaths = getModulePaths "homes" config.system hostName userName;
        in
        darwin.lib.darwinSystem {
          system = config.system;
          specialArgs = {
            inherit inputs myOptions;
          };
          modules = [
            { nixpkgs = nixpkgsConfig config.system; }
            home-manager.darwinModules.home-manager
            { home-manager.users.${userName}.imports = homeModulePaths; }
          ]
          ++ systemModulePaths;
        }
      ) darwinHosts;

      nixosConfigurations = lib.mapAttrs (
        key: config:
        let
          parsed = parseHostKey key config;
          inherit (parsed) hostName userName myOptions;
          systemModulePaths = getModulePaths "systems" config.system hostName userName;
          homeModulePaths = getModulePaths "homes" config.system hostName userName;
        in
        nixpkgs.lib.nixosSystem {
          system = config.system;
          specialArgs = {
            inherit inputs myOptions;
          };
          modules = [
            { nixpkgs = nixpkgsConfig config.system; }
            home-manager.nixosModules.home-manager
            { home-manager.users.${userName}.imports = homeModulePaths; }
            comin.nixosModules.comin
          ]
          ++ systemModulePaths;
        }
      ) linuxHosts;

      devShells = lib.genAttrs [
        "aarch64-darwin"
        "x86_64-linux"
      ] (system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        {
          default = pkgs.mkShell {
            packages = with pkgs; [
              nixd
              nixfmt
            ];
          };
        }
      );

      templates = {
        phoenix = {
          path = ./templates/phoenix;
          description = "my phoenix template";
        };
      };
    };
}
