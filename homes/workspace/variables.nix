{
  config,
  pkgs,
  customConfig,
  ...
}:
let
  xdgConfigs = {
    # XDG_CONFIG_HOME
    configHome = ${config.home.homeDirectory}/.config;

    # XDG_CACHE_HOME
    cacheHome = ${config.home.homeDirectory}/.cache;

    # XDG_DATA_HOME
    dataHome = ${config.home.homeDirectory}/.local/share;

    # XDG_STATE_HOME
    stateHome = ${config.home.homeDirectory}/.local/state;
  };
in
{

  xdg = {
    enable = true;
  } // xdgConfigs;



  home.sessionVariables = {
    EDITOR = config.environment.editor;
    SHELL = config.environment.shell;

    XDG_CONFIG_HOME = "${xdgConfigs.configHome}";
    XDG_CACHE_HOME = "${xdgConfigs.cacheHome}";
    XDG_DATA_HOME = "${xdgConfigs.dataHome}";
    XDG_STATE_HOME = "${xdgConfigs.stateHome}";
  };

}
