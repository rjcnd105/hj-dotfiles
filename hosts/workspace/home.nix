{ pkgs, config, lib, ... }:
let
  hosts = import ../../config/hosts.nix;
  info = import ../../config/info.nix;
in
{

  imports = [
    ../../home-manager/presets/workspace.nix
  ];


  home = {
    username = hosts.workspace.user;
    homeDirectory = lib.mkForce (builtins.toPath "/Users/${hosts.workspace.user}");
    stateVersion = info.home-manager.stateVersion;
      # 환경 변수 설정
    sessionVariables = {
        EDITOR = "zed";
        LANG = "ko_KR.UTF-8";
    };
  };

    # home-manager 자체 설정
    programs.home-manager.enable = true;
}
