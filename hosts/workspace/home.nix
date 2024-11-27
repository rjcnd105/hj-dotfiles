{
  pkgs,
  config,
  lib,
  inputs,
  host,
  envVars,
  ...
}:
let
  info = import ../../config/info.nix;
in
{

  warnings = [
      "envVars keys: ${(builtins.toJSON envVars)}"
    ];

  home = {
    username = host.user;
    homeDirectory = lib.mkForce (builtins.toPath "/Users/${host.user}");
    stateVersion = info.home-manager.stateVersion;
    sessionPath = [ "${config.home.homeDirectory}/.nix-profile/bin" ];
    # 환경 변수 설정
    sessionVariables = envVars // {
      HOME = config.home.homeDirectory;
      XDG_CONFIG_HOME = "${config.home.homeDirectory}/.config";
      XDG_DATA_HOME = "${config.home.homeDirectory}/.local/share";
      XDG_CACHE_HOME = "${config.home.homeDirectory}/.cache";
      XDG_RUNTIME_DIR = "${config.home.homeDirectory}/.local/run";
      # 환경 변수 설정
      TERMINAL = "${config.programs.rio.package}/bin/rio";
    };
  };


  # home-manager 자체 설정
  programs.home-manager = {
    enable = true;
  };


  imports = [
    ../../home-manager/presets/workspace.nix
    ./ssh.conf.nix
  ];
}
