{
  iuputs,
  pkgs,
  customConfig,
  ...
}:
{

  config.system.stateVersion = 5;
  config.backupFileExtension = "backup"; # 백업 파일 확장자 설정

  config.networking = {
    hostName = customConfig.host_userName;
    computerName = customConfig.host_userName;
    localHostName = customConfig.host_userName;
  };

  config.home-manager = {
    useUserPackages = true;
    useGlobalPkgs = true;
  };

  config.fonts = {
    fontDir.enable = true;
    fonts = with pkgs; [
      (nerdfonts.override {
        fonts = [
          "D2Coding"
          "JetBrainsMono"
        ] ++ cfg.fonts;
      })
    ];
  };
}
