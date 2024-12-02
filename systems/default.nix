{
  inputs,
  pkgs,
  customConfig,
  ...
}:
{

  imports = [
    ../shared/core/nixos.nix
  ];
  config = {
    system.stateVersion = 5;

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

    fonts = {
      packages = with pkgs; [
        (nerdfonts.override {
          fonts = [
            "D2Coding"
            "JetBrainsMono"
          ] ++ cfg.fonts;
        })
      ];
    };
  };
}
