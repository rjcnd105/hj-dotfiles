{
  description = "Nix Dotsfiles with flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixos-hardware.url = "github:nixos/nixos-hardware";

    home-manager = {
      url = "github:nix-community/home-manager/master";
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

      mkCommonConfigurations = { username ? (import ./config/users.nix).default }@inputs: {
        nix = {
          settings = {
            trusted-users = [ "root" username ];
            auto-optimise-store = true;
            keep-derivations = true;
            keep-outputs = true;
            auto-allocate-uids = true;
            experimental-features = [
              "nix-command"
              "flakes"
            ];
          };
          # garbage collection
          gc = {
            automatic = true;
            dates = "weekly";
            options = "--delete-older-than 45d";
          };
        };
      };

      mkDarwinConfigurations = host:
        darwin.lib.darwinSystem {
          system = host.arch;
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
            ({ pkgs, ... }: {
              home-manager.users.${host.user} = {
                imports = [
                  ./hosts/${host.dir}/home.nix
                ];
              };
            })
          ];
        };
    in
    {
      darwinConfigurations."${hosts.workspace.user}@${hosts.workspace.hostname}" = mkDarwinConfigurations hosts.workspace;
    };
}
