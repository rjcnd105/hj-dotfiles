{
  config,
  pkgs,
  customConfig,
  ...
}:
let
  inherit (config) home

  sessionPath = [
    "/usr/bin"
    "${config.home.homeDirectory}/bin"
    "${config.home.homeDirectory}/.nix-profile/bin"
    "${config.home.profileDirectory}/bin"
  ];
  xdgConfigs = {
    # XDG_CONFIG_HOME
    configHome = ${home.homeDirectory}/.config;

    # XDG_CACHE_HOME
    cacheHome = ${home.homeDirectory}/.cache;

    # XDG_DATA_HOME
    dataHome = ${home.homeDirectory}/.local/share;

    # XDG_STATE_HOME
    stateHome = ${home.homeDirectory}/.local/state;
  };
in
{

  xdg = {
    enable = true;
  } // xdgConfigs;

  home.sessionPaths = sessionPath;


  home.sessionVariables = {
    EDITOR = config.environment.editor;
    SHELL = config.environment.shell;

    XDG_CONFIG_HOME = "${xdgConfigs.configHome}";
    XDG_CACHE_HOME = "${xdgConfigs.cacheHome}";
    XDG_DATA_HOME = "${xdgConfigs.dataHome}";
    XDG_STATE_HOME = "${xdgConfigs.stateHome}";
  };

}
