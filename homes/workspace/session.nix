{
  config,
  pkgs,
  customConfig,
  ...
}:
{

  xdg = {
    enable = true;
    # XDG_CONFIG_HOME
    configHome = ${config.home.homeDirectory}/.config;

    # XDG_CACHE_HOME
    cacheHome = ${config.home.homeDirectory}/.cache;

    # XDG_DATA_HOME
    dataHome = ${config.home.homeDirectory}/.local/share;

    # XDG_STATE_HOME
    stateHome = ${config.home.homeDirectory}/.local/state;
  };

  home.sessionPath = [
      "/usr/bin"
      "${config.home.homeDirectory}/bin"
      "${config.home.homeDirectory}/.nix-profile/bin"
      "${config.home.profileDirectory}/bin"
    ];

  home.sessionVariables = {
    EDITOR = config.environment.editor;
    SHELL = config.environment.shell;

    XDG_CONFIG_HOME = "${xdg.configHome}";
    XDG_CACHE_HOME = "${xdg.cacheHome}";
    XDG_DATA_HOME = "${xdg.dataHome}";
    XDG_STATE_HOME = "${xdg.stateHome}";
  };

}
