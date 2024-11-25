{
  description = "Nix Dotsfiles with flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    nixos-hardware.url = "github:nixos/nixos-hardware";

    home-manager = {
      url = "github:nix-community/home-manager/release-24.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    darwin = {
      url = "github:lnl7/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      darwin,
      ...
    }@inputs:
    let
      hosts = import ./config/hosts.nix;

      mkCommonConfigurations =
        {
          username ? (import ./config/users.nix).default,
        }@inputs:
        {
          nix = {
            settings = {
              trusted-users = [
                "root"
                username
              ];
              keep-derivations = true;
              keep-outputs = true;
              experimental-features = [
                "nix-command"
                "flakes"
              ];
              # substituters와 trusted-public-keys 명시적 설정
              substituters = [
                "https://cache.nixos.org"
                "https://nix-community.cachix.org"
              ];
              trusted-public-keys = [
                "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
                "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
              ];
            };
            configureBuildUsers = true;
            optimise.automatic = true;
            # garbage collection
            gc = {
              automatic = true;
              options = "--delete-older-than 45d";
            };
          };
        };

      mkDarwinConfigurations =
        host:
        let

          system = host.arch;
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
          };
        in
        darwin.lib.darwinSystem {
          inherit system;
          specialArgs = { inherit inputs pkgs; }; # specialArgs 추가
          modules = [
            home-manager.darwinModules.home-manager
            {
              # nix 설정 포함
              imports = [
                (mkCommonConfigurations {
                  username = host.user;
                })
              ];
            }
            {
              system.stateVersion = 5;
              home-manager = {

                useGlobalPkgs = true;
                useUserPackages = true;
                extraSpecialArgs = {
                  inherit inputs pkgs;
                };
                users.${host.user} = {
                  imports = [
                    ./hosts/${host.dir}/home.nix
                  ];
                };
              };
            }
          ];
        };
    in
    {
      darwinConfigurations."${hosts.workspace.user}@${hosts.workspace.hostname}" = mkDarwinConfigurations hosts.workspace;
    };
}
