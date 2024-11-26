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
    ./ssh.nix
  ];



  home = {
    username = host.user;
    homeDirectory = lib.mkForce (builtins.toPath "/Users/${host.user}");
    stateVersion = info.home-manager.stateVersion;
    # 환경 변수 설정
    sessionVariables = {
      LANG = "ko_KR.UTF-8";
    };
  };

  # home-manager 자체 설정
  programs.home-manager = {
    enable = true;
  };
}
