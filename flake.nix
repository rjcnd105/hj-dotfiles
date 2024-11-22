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

    nix-snapshotter = {
      url = "github:pdtpartners/nix-snapshotter";
      inputs.nixpkgs.follows = "nixpkgs";
    };

  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      ...
    }@inputs:

    let
      hosts = import ./config/hosts.nix;
      mkHomeConfigurations =
        host:
        home-manager.lib.homeManagerConfiguration {
          pkgs = import nixpkgs {
            system = host.arch;
            config = {
              allowUnfree = true;
            };
          };
          modules = [
            ./hosts/${host.dir}/home.nix
            ./overlays
          ];
        };

      mkNixOSConfigurations =
        host:
        nixpkgs.lib.nixosSystem {
          system = host.arch;
          modules = [
            ./hosts/${host.dir}/configuration.nix
            ./overlays
            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.users."${host.user}" = import ./hosts/${host.dir}/home.nix;
            }
          ];
        };

      supportedSystems = [
        "x86_64-linux"
        "x86_64-darwin"
        "aarch64-linux"
        "aarch64-darwin"
      ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
    in
    {
      nixosConfigurations."${hosts.gateway.hostname}" = mkNixOSConfigurations hosts.gateway;
      homeConfigurations."${hosts.my_workspace.user}@${hosts.my_workspace.hostname}" = mkHomeConfigurations hosts.work;

      devShells = forAllSystems (
        system:
        let
          nixpkgsFor = forAllSystems (system: import nixpkgs { inherit system; });
          pkgs = nixpkgsFor.${system};
        in
        {
            default = pkgs.mkShell {
                nativeBuildInputs = with pkgs; [
                    nixd
                    nixfmt-rfc-style
                ];
            };
        }
      );
    };
}
