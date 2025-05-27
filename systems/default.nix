{
  pkgs,
  myOptions,
  ...
}:
{

  config = {
    system.stateVersion = 5;

    # documentation.enable = true;

    environment.variables = {
      USER = myOptions.userName;
      HOME = "/Users/${myOptions.userName}";
    };

    networking = {
      hostName = myOptions.userName;
      computerName = myOptions.userName;
      localHostName = myOptions.userName;
    };

    users.users.${myOptions.userName} = {
      name = myOptions.userName;
      home = "/Users/${myOptions.userName}";
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
      # 필요한 다른 폰트들...
    ];
    system.primaryUser = myOptions.userName;
    system.defaults.NSGlobalDomain.AppleFontSmoothing = 2;
  };
}
