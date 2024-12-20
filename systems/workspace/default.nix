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
    # ../../shared/development/devops/postgresql.nix
  ];

  config = {
    environment.systemPackages = [
      inputs.comma
      pkgs.nix-search-cli
      pkgs.devenv
    ];

    # 여기에 추가해야지만 기본 쉘 설정 가능
    # ex) chsh -s /nix/var/nix/profiles/default/bin/zsh
    # ex) chsh -s $(which fish)
    environment.shells = [
      pkgs.zsh
      pkgs.fish
    ];

    environment.variables = variables;

    security.pam.enableSudoTouchIdAuth = true;

    users.groups = {
      while = {
        description = "시스템 관리자 권한";
        # 이것과는 별개로 dseditgroup를 사용해서 수동으로 그룹으로 추가해줘야함.
        members = [ "hj" ];
      };
    };
    nix.settings.trusted-users = [
      "root"
      "@wheel"
    ];
    nix.nixPath = [ "nixpkgs=flake:nixpkgs" ];

    home-manager = {
      sharedModules = [
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
