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
    inputs.nix-index-database.darwinModules.nix-index
    ../../shared/development/devops/postgresql.nix
  ];

  config = {
    environment.systemPackages = [
      inputs.comma
      pkgs.nix-search-cli
      pkgs.devenv
    ];

    environment.shells = [
      pkgs.zsh
      pkgs.nushell
    ];

    environment.variables = variables;

    security.pam.enableSudoTouchIdAuth = true;

    # system.activationScripts.postActivation.text = ''
    #   # Terminal.app의 기본 shell을 nushell로 설정
    #   /usr/libexec/PlistBuddy -c "Set :Window\ Settings:Basic:Shell '${
    #     config.home-manager.users.${myOptions.userName}.programs.nushell.package
    #   }/bin/nu'" ~/Library/Preferences/com.apple.Terminal.plist

    #   # 현재 셸의 모든 환경변수를 launchctl에 설정
    #   for var in $(env | cut -d= -f1); do
    #     /bin/launchctl setenv "$var" "''${!var}"
    #   done
    # '';

    # system.activationScripts.postActivation.text = ''
    #    ${pkgs.nushell}/bin/nu -c '
    #      if (ls /etc/agenix/ | length) > 0 {
    #        sudo chown ${myvars.username} /etc/agenix/*
    #      }
    #    '
    #  '';
    #

    users.groups = {
      while = {
        description = "시스템 관리자 권한";
        members = [ "hj" ];
      };
    };
    nix.settings.trusted-users = [
      "root"
      "@wheel"
    ];

    home-manager = {
      sharedModules = [
        inputs.nixvim.homeManagerModules.nixvim
        inputs.catppuccin.homeManagerModules.catppuccin
        {
          catppuccin = {
            enable = true;
            flavor = "macchiato";
          };
        }
      ];
      extraSpecialArgs = {
        inherit inputs myOptions;
      };
    };
  };
}
