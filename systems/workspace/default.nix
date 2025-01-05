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
    { programs.nix-index-database.comma.enable = true; }
    # ../../shared/development/devops/postgresql.nix
  ];

  config = {
    environment.systemPackages = [
      pkgs.nix
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
    nix.package = pkgs.nix;
    nix.nixPath = [ "nixpkgs=flake:nixpkgs" ];
    nix.settings = {

      trusted-users = [
        "root"
        "@wheel"
      ];
      extra-trusted-substituters = "https://cache.flakehub.com";
      extra-trusted-public-keys = "cache.flakehub.com-3:hJuILl5sVK4iKm86JzgdXW12Y2Hwd5G07qKtHTOcDCM= cache.flakehub.com-4:Asi8qIv291s0aYLyH6IOnr5Kf6+OF14WVjkE6t3xMio= cache.flakehub.com-5:zB96CRlL7tiPtzA9/WKyPkp3A2vqxqgdgyTVNGShPDU= cache.flakehub.com-6:W4EGFwAGgBj3he7c5fNh9NkOXw0PUVaxygCVKeuvaqU= cache.flakehub.com-7:mvxJ2DZVHn/kRxlIaxYNMuDG1OvMckZu32um1TadOR8= cache.flakehub.com-8:moO+OVS0mnTjBTcOUh2kYLQEd59ExzyoW1QgQ8XAARQ= cache.flakehub.com-9:wChaSeTI6TeCuV/Sg2513ZIM9i0qJaYsF+lZCXg0J6o= cache.flakehub.com-10:2GqeNlIp6AKp4EF2MVbE1kBOp9iBSyo0UPR9KoR0o1Y=";

      upgrade-nix-store-path-url = "https://install.determinate.systems/nix-upgrade/stable/universal";

      netrc-file = "/nix/var/determinate/netrc";
      extra-substituters = "https://cache.flakehub.com";

      experimental-features = "nix-command flakes";
      always-allow-substitutes = "true";
    };

    home-manager = {
      sharedModules = [
        inputs.catppuccin.homeManagerModules.catppuccin
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
