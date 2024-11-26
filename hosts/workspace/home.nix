{
  pkgs,
  config,
  lib,
  inputs,
  host,
  ...
}:
let
  info = import ../../config/info.nix;
in
{
  imports = [
    ../../home-manager/presets/workspace.nix
  ];



  home = {
    username = host.user;
    homeDirectory = lib.mkForce (builtins.toPath "/Users/${host.user}");
    stateVersion = info.home-manager.stateVersion;
    # 환경 변수 설정
    sessionVariables = {
      LANG = "ko_KR.UTF-8";
    };
    backupFileExtension = lib.mkDefault (
      let
        timestamp = builtins.substring 0 12 (
          builtins.replaceStrings ["-" ":"] ["" ""] (builtins.toString builtins.currentTime)
        );
        year = builtins.substring 2 4 timestamp;
        month = builtins.substring 4 6 timestamp;
        day = builtins.substring 6 8 timestamp;
        hour = builtins.substring 8 10 timestamp;
        minute = builtins.substring 10 12 timestamp;
      in
        "${year}${month}${day}_${hour}${minute}"
    );
  };

  # home-manager 자체 설정
  programs.home-manager.enable = true;
}
