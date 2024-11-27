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

  warnings = [ "fish path: ${toString pkgs.fish}" "profile path: ${toString config.home.profileDirectory}" ];
  home = {
    username = host.user;
    homeDirectory = lib.mkForce (builtins.toPath "/Users/${host.user}");
    stateVersion = info.home-manager.stateVersion;
    # 환경 변수 설정
    sessionVariables = {
      LANG = "ko_KR.UTF-8";
      HOME = config.home.homeDirectory;
      PATH = "${config.home.profileDirectory}/bin:$PATH";
      XDG_CONFIG_HOME = "${config.home.homeDirectory}/.config";
      XDG_DATA_HOME = "${config.home.homeDirectory}/.local/share";
      XDG_CACHE_HOME = "${config.home.homeDirectory}/.cache";
      XDG_RUNTIME_DIR = "${config.home.homeDirectory}/.local/run";
      # 환경 변수 설정
      TERMINAL = "${config.programs.rio.package}/bin/rio";
    };
  };

  fonts.fontconfig.enable = true;

  # home-manager 자체 설정
  programs.home-manager = {
    enable = true;
  };


  imports = [
    ../../home-manager/presets/workspace.nix
    ./ssh.conf.nix
  ];
}
