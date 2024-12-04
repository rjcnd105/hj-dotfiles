{
  config,
  pkgs,
  customConfig,
  ...
}:
let
  inherit (config.home) homeDirectory profileDirectory;

  sessionPath = [
    "/usr/bin"
    "${homeDirectory}/bin"
    "${homeDirectory}/.nix-profile/bin"
    "${profileDirectory}/bin"
  ];
  xdgConfigs = {
    # XDG_CONFIG_HOME
    configHome = homeDirectory / ".config";

    # XDG_CACHE_HOME
    cacheHome = homeDirectory / ".cache";

    # XDG_DATA_HOME
    dataHome = homeDirectory / ".local/share";

    # XDG_STATE_HOME
    stateHome = homeDirectory / ".local/state";
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
