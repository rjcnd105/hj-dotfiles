{
  inputs,
  pkgs,
  config,
  customConfig,
  ...
}:
{

  imports = [
    ../shared/core/nixos.nix
  ];

  config = {
    system.stateVersion = 5;

    documentation.enable = true;

    environment.variables = {
      USER = customConfig.userName;
      HOME = "/Users/${customConfig.userName}";
    };

    networking = {
      hostName = customConfig.userName;
      computerName = customConfig.userName;
      localHostName = customConfig.userName;
    };

    users.users.${customConfig.userName} = {
      name = customConfig.userName;
      home = "/Users/${customConfig.userName}";
    };

    home-manager = {
      useUserPackages = true;
      useGlobalPkgs = true;
      backupFileExtension = "backup"; # 백업 파일 확장자 설정
    };

    # nerd-fonts list
    # https://github.com/NixOS/nixpkgs/blob/master/pkgs/data/fonts/nerd-fonts/manifests/fonts.json
    fonts.packages = [
      pkgs.nerd-fonts.d2coding
      pkgs.nerd-fonts.jetbrains-mono
      pkgs.nerd-fonts.lilex
      # 필요한 다른 폰트들...
    ];



    system.defaults.NSGlobalDomain.AppleFontSmoothing = 2;
  };
}
