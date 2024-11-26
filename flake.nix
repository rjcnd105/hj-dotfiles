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
          specialArgs = { inherit inputs pkgs host; };
          modules = [
            home-manager.darwinModules.home-manager
            ./hosts/${host.dir}/nix.conf.nix
            {
              system.stateVersion = 5;
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;

                # extraSpecialArgs
                # home-manager 시스템 레벨 모듈에 전달되는 인자
                # 각 모듈의 인자로 넘겨줌
                extraSpecialArgs = {
                  inherit inputs pkgs host;
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
