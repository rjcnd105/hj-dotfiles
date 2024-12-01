{
  description = "Nix Dotsfiles with flake";

  inputs = {
    unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    nixos-hardware.url = "github:nixos/nixos-hardware";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";

    home-manager = {
      url = "github:nix-community/home-manager/release-24.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    darwin = {
      url = "github:lnl7/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    catppuccin.url = "github:catppuccin/nix";

    nixvim = {
      url = "github:nix-community/nixvim";
      # url = "/home/gaetan/perso/nix/nixvim/nixvim";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      nixvim,
      catppuccin,
      darwin,
      ...
    }@inputs:
    let
      hosts = import ./config/hosts.nix;

      mkDarwinConfigurations =
        host:
        let
          pkgs = import nixpkgs {
            system = host.arch;
            config.allowUnfree = true;
          };
        in

        darwin.lib.darwinSystem {
          system = host.arch;

          # specialArgs
          # nix-darwin 시스템 레벨 모듈에 전달되는 인자
          # 각 모듈의 인자로 넘겨줌
          specialArgs = {
            inherit
              inputs
              pkgs
              host
              catppuccin
              nixvim
              ;
          };
          modules = [
            home-manager.darwinModules.home-manager
            (
              {
                pkgs,
                host,
                config,
                inputs,
                catppuccin,
                nixvim,
                ...
              }:
              {

                warnings = [
                  "Config keys: ${toString (builtins.attrNames config)}"
                ];
              }
            )
            ./hosts/${host.dir}/nix.conf.nix

            (
              { specialArgs, ... }@inputs:
              {
                warnings = [
                  "specialArgs keys: ${toString (builtins.attrNames specialArgs)}"
                ];
              }
            )
            {
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;

                backupFileExtension = "backup"; # 백업 파일 확장자 설정
                # extraSpecialArgs
                # home-manager 시스템 레벨 모듈에 전달되는 인자
                # 각 모듈의 인자로 넘겨줌
                extraSpecialArgs = {
                  inherit
                    inputs
                    pkgs
                    host
                    catppuccin
                    nixvim
                    ;
                };
                users.${host.user}.imports = [
                  ./hosts/${host.dir}/home.nix
                ];
              };
            }
          ];
        };
    in
    with hosts;
    {
      darwinConfigurations = {
        "${hosts.workspace.user}@${hosts.workspace.hostname}" = mkDarwinConfigurations hosts.workspace;
      };

      nixosModules.${hosts.workspace.user} = ./modules/age.nix;
      nixosModules.default = self.nixosModules.age;

      darwinModules.age = ./hosts/${hosts.workspace.user}/darwin.nix;
      darwinModules.default = self.darwinModules.age;

      homeManagerModules.age = ./modules/age-home.nix;
      homeManagerModules.default = self.homeManagerModules.age;

    };
}
