{
  description = "A highly awesome system configuration.";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgsPwgen.url = "github:nixos/nixpkgs/4533d9293756b63904b7238acb84ac8fe4c8c2c4";
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

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

    comin = {
      url = "github:nlewo/comin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    quadlet-nix.url = "github:SEIAROTg/quadlet-nix";

    deopjibApp = {
      url = "github:rjcnd105/my-app";
      flake = false;
    };

    frontVibeHelperApp = {
      url = "github:rjcnd105/front-vibe-helper";
      flake = false;
    };
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      nixpkgsPwgen,
      treefmt-nix,
      home-manager,
      darwin,
      sops-nix,
      comin,
      quadlet-nix,
      deopjibApp,
      frontVibeHelperApp,
    }:
    let
      hosts = {
        workspace_hj = {
          hostName = "workspace";
          userName = "hj";
          system = "aarch64-darwin";
          email = "rjcnd123@gmail.com";
          projectPath = "/Users/hj/dot/nix-dots";
        };
        homelab_hj = {
          hostName = "homelab";
          userName = "hj";
          system = "x86_64-linux";
          email = "rjcnd123@gmail.com";
        };
      };
      lib = nixpkgs.lib;
      systems = [
        "aarch64-darwin"
        "x86_64-linux"
      ];
      eachSystem = lib.genAttrs systems;

      getModulePaths =
        prefix: system: host:
        builtins.filter builtins.pathExists [
          ./${prefix}/default.nix
          ./${prefix}/${system}/default.nix
          ./${prefix}/${host}/default.nix
        ];

      darwinHosts = lib.filterAttrs (_: v: lib.hasSuffix "darwin" v.system) hosts;
      linuxHosts = lib.filterAttrs (_: v: lib.hasSuffix "linux" v.system) hosts;

      mkMyOptions = key: hostCfg: {
        inherit key;
        inherit (hostCfg)
          email
          system
          hostName
          userName
          ;
        filesHost = hostCfg.filesHost or "workspace";
        absoluteProjectPath = hostCfg.projectPath or null;
      };

      nixpkgsConfig = system: {
        inherit system;
        overlays = [
          (_final: _prev: {
            pwgen = nixpkgsPwgen.legacyPackages.${system}.pwgen;
            direnv = _prev.direnv.overrideAttrs (_old: {
              doCheck = false;
            });
          })
        ];
      };

      pkgsFor = system: import nixpkgs (nixpkgsConfig system);

      treefmtModule =
        { ... }:
        {
          projectRootFile = "flake.nix";

          programs = {
            nixfmt.enable = true;
            taplo.enable = true;
          };

          settings.global = {
            on-unmatched = "info";
            # Codex가 실행할 때마다 이 파일을 다시 쓰므로 treefmt 결과가
            # 유지되지 않는다. CI formatting 체크가 그때마다 깨지는 걸 막는다.
            excludes = [ "files/workspace/.codex/config.toml" ];
          };
        };

      treefmtEval = eachSystem (system: treefmt-nix.lib.evalModule (pkgsFor system) treefmtModule);
    in
    {
      formatter = eachSystem (system: treefmtEval.${system}.config.build.wrapper);

      checks = import ./checks {
        inherit
          self
          inputs
          lib
          pkgsFor
          eachSystem
          treefmtEval
          ;
      };

      darwinConfigurations = lib.mapAttrs (
        key: hostCfg:
        let
          myOptions = mkMyOptions key hostCfg;
          systemModulePaths = getModulePaths "systems" hostCfg.system hostCfg.hostName;
          homeModulePaths = getModulePaths "homes" hostCfg.system hostCfg.hostName;
        in
        darwin.lib.darwinSystem {
          system = hostCfg.system;
          specialArgs = {
            inherit inputs myOptions;
          };
          modules = [
            { nixpkgs = nixpkgsConfig hostCfg.system; }
            home-manager.darwinModules.home-manager
            { home-manager.users.${hostCfg.userName}.imports = homeModulePaths; }
          ]
          ++ systemModulePaths;
        }
      ) darwinHosts;

      nixosConfigurations = lib.mapAttrs (
        key: hostCfg:
        let
          myOptions = mkMyOptions key hostCfg;
          systemModulePaths = getModulePaths "systems" hostCfg.system hostCfg.hostName;
          homeModulePaths = getModulePaths "homes" hostCfg.system hostCfg.hostName;
        in
        nixpkgs.lib.nixosSystem {
          system = hostCfg.system;
          specialArgs = {
            inherit inputs myOptions;
          };
          modules = [
            { nixpkgs = nixpkgsConfig hostCfg.system; }
            { system.configurationRevision = self.rev or self.dirtyRev or "dirty"; }
            home-manager.nixosModules.home-manager
            { home-manager.users.${hostCfg.userName}.imports = homeModulePaths; }
            comin.nixosModules.comin
            quadlet-nix.nixosModules.quadlet
          ]
          ++ systemModulePaths;
        }
      ) linuxHosts;

      devShells = eachSystem (
        system:
        let
          pkgs = pkgsFor system;
        in
        {
          default = pkgs.mkShell {
            packages = [
              pkgs.nixd
              treefmtEval.${system}.config.build.wrapper
            ];
          };
        }
      );
    };
}
