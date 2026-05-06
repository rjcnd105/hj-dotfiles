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

    deopjibRuntime = {
      url = "github:rjcnd105/my-app/feat/deopjib-runtime-contract";
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
      deopjibRuntime,
    }:
    let
      # 형태는 ${host}_${username}
      hosts = {
        workspace_hj = {
          system = "aarch64-darwin";
          email = "rjcnd123@gmail.com";
          projectPath = "/Users/hj/dot/nix-dots";
        };
        homelab_hj = {
          system = "x86_64-linux";
          email = "rjcnd123@gmail.com";
          filesHost = "workspace";
          projectPath = "/etc/nixos";
        };
      };
      lib = nixpkgs.lib;
      systems = [
        "aarch64-darwin"
        "x86_64-linux"
      ];
      eachSystem = lib.genAttrs systems;
      myLib = import ./config/lib.nix {
        inherit lib;
        pkgs = nixpkgs;
      };

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
            absoluteProjectPath = config.projectPath;
            _debug = { };
          };
        };

      nixpkgsConfig = system: {
        inherit system;
        overlays = [
          (_final: _prev: {
            pwgen = nixpkgsPwgen.legacyPackages.${system}.pwgen;
            direnv = _prev.direnv.overrideAttrs (old: {
              doCheck = false;
            });
          })
        ];
        config = {
          allowUnfreePredicate =
            pkg:
            builtins.elem (lib.getName pkg) [
              "vault"
              "claude-code"
            ];
        };
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

          settings.global.on-unmatched = "info";
        };

      treefmtEval = eachSystem (system: treefmt-nix.lib.evalModule (pkgsFor system) treefmtModule);

      homelabAppctlDeployInvariants =
        system:
        let
          pkgs = pkgsFor system;
        in
        pkgs.runCommand "homelab-appctl-deploy-invariants" { } ''
          app_containers=${./systems/homelab/app-containers.nix}

          ${pkgs.gnugrep}/bin/grep -F 'systemctl restart "$image_unit"' "$app_containers" >/dev/null
          if ${pkgs.gnugrep}/bin/grep -F 'systemctl start "$image_unit"' "$app_containers" >/dev/null; then
            echo 'homelab-appctl deploy must restart image pull units; start is a no-op for active oneshot .image units' >&2
            exit 1
          fi

          touch "$out"
        '';
    in
    {
      _debug = { };

      formatter = eachSystem (system: treefmtEval.${system}.config.build.wrapper);

      checks = eachSystem (system: {
        formatting = treefmtEval.${system}.config.build.check self;
        homelab-appctl-deploy-invariants = homelabAppctlDeployInvariants system;
      });

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
            { system.configurationRevision = self.rev or self.dirtyRev or "dirty"; }
            home-manager.nixosModules.home-manager
            { home-manager.users.${userName}.imports = homeModulePaths; }
            comin.nixosModules.comin
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

      templates = {
        phoenix = {
          path = ./templates/phoenix;
          description = "my phoenix template";
        };
      };
    };
}
