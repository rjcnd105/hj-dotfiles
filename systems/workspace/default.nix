{
  pkgs,
  inputs,
  myOptions,
  config,
  ...
}:
let
  variables = {
    USER = myOptions.userName;
    EDITOR = "zed";
    LANG = "ko_KR.UTF-8";
  };
in
{

  imports = [
    # ../../shared/development/devops/postgresql.nix
  ];

  config = {
    environment.systemPackages = [
      # pkgs.nix
      # pkgs.nix-search-cli
      pkgs.devenv
    ];

    homebrew = {
      enable = true;

      # onActivation = {
      #   autoUpdate = true;
      #   cleanup = "uninstall";
      #   upgrade = true;
      # };
    };

    # 여기에 추가해야지만 기본 쉘 설정 가능
    # ex) chsh -s /nix/var/nix/profiles/default/bin/zsh
    # ex) chsh -s $(which fish)
    environment.shells = [
      pkgs.bashInteractive
      pkgs.zsh
      pkgs.fish
    ];

    environment.etc."nix/conf.d/custom.conf".text = ''
      !include ${config.users.users.${myOptions.userName}.home}/.config/nix/nix.custom.conf
      extra-substituters = https://cache.nixos.org/ https://devenv.cachix.org https://jdx.cachix.org
      extra-trusted-public-keys = devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw= jdx.cachix.org-1:3N2cKS7DOv4oDa53G8GfI72sD9aI2zspA6Sj08B2f3U=
    '';

    environment.variables = variables // {
      DOCKER_HOST = "unix://${
        config.users.users.${myOptions.userName}.home
      }/.local/share/containers/podman/machine/podman.sock";
    };

    security.pam.services.sudo_local.touchIdAuth = true;

    users.groups = {
      while = {
        description = "시스템 관리자 권한";
        # 이것과는 별개로 dseditgroup를 사용해서 수동으로 그룹으로 추가해줘야함.
        members = [ "hj" ];
      };

    };

    nix.enable = false;
    # nix.package = pkgs.nix;
    # nix.nixPath = [ "nixpkgs=flake:nixpkgs" ];
    # nix.settings = {

    #   trusted-users = [
    #     "root"
    #     "@wheel"
    #   ];
    #   extra-trusted-substituters = "https://cache.flakehub.com";
    #   extra-trusted-public-keys = "cache.flakehub.com-3:hJuILl5sVK4iKm86JzgdXW12Y2Hwd5G07qKtHTOcDCM= cache.flakehub.com-4:Asi8qIv291s0aYLyH6IOnr5Kf6+OF14WVjkE6t3xMio= cache.flakehub.com-5:zB96CRlL7tiPtzA9/WKyPkp3A2vqxqgdgyTVNGShPDU= cache.flakehub.com-6:W4EGFwAGgBj3he7c5fNh9NkOXw0PUVaxygCVKeuvaqU= cache.flakehub.com-7:mvxJ2DZVHn/kRxlIaxYNMuDG1OvMckZu32um1TadOR8= cache.flakehub.com-8:moO+OVS0mnTjBTcOUh2kYLQEd59ExzyoW1QgQ8XAARQ= cache.flakehub.com-9:wChaSeTI6TeCuV/Sg2513ZIM9i0qJaYsF+lZCXg0J6o= cache.flakehub.com-10:2GqeNlIp6AKp4EF2MVbE1kBOp9iBSyo0UPR9KoR0o1Y=";

    #   upgrade-nix-store-path-url = "https://install.determinate.systems/nix-upgrade/stable/universal";

    #   netrc-file = "/nix/var/determinate/netrc";
    #   extra-substituters = "https://cache.flakehub.com";

    #   experimental-features = "nix-command flakes";
    #   always-allow-substitutes = "true";
    # };

    home-manager = {
      sharedModules = [
        inputs.catppuccin.homeModules.catppuccin
        inputs.mac-app-util.homeManagerModules.default
        {
          catppuccin = {
            enable = true;
            flavor = "macchiato";
            zellij.enable = false;
          };
        }
      ];
      extraSpecialArgs = {
        inherit inputs myOptions;
      };
    };

  };
}
