{
  pkgs,
  inputs,
  myOptions,
  config,
  ...
}:
let
  # variables = {
  #   USER = myOptions.userName;
  #   EDITOR = "zed";
  #   LANG = "ko_KR.UTF-8";
  # };
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

    security.pam.services.sudo_local.touchIdAuth = true;

    users.groups = {
      while = {
        description = "시스템 관리자 권한";
        # 이것과는 별개로 dseditgroup를 사용해서 수동으로 그룹으로 추가해줘야함.
        members = [ myOptions.userName ];
      };

    };

    # https://determinate.systems/blog/nix-darwin-updates/#what-you-should-change
    # TODO: 그러나 이후 https://determinate.systems/blog/changelog-determinate-nix-386/#nix-darwin 적용 확인..
    nix.enable = false;

    home-manager = {
      sharedModules = [
        inputs.catppuccin.homeModules.catppuccin
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
