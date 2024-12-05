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
    "$HOME/bin"
    "$HOME/.nix-profile/bin"
    "$HOME/.local/bin"
    "/etc/profiles/per-user/${customConfig.userName}/bin"
  ];
  xdgConfigs = {
    # XDG_CONFIG_HOME
    configHome = homeDirectory + "/.config";

    # XDG_CACHE_HOME
    cacheHome = homeDirectory + "/.cache";

    # XDG_DATA_HOME
    dataHome = homeDirectory + "/.local/share";

    # XDG_STATE_HOME
    stateHome = homeDirectory + "/.local/state";
  };
in
{

  xdg = {
    enable = true;
  } // xdgConfigs;

  home.sessionPath = sessionPath;

  home.sessionVariables = {
    IS_HOME_MANAGED = "1";
    XDG_CONFIG_HOME = toString xdgConfigs.configHome;
    XDG_CACHE_HOME = toString xdgConfigs.cacheHome;
    XDG_DATA_HOME = toString xdgConfigs.dataHome;
    XDG_STATE_HOME = toString xdgConfigs.stateHome;
  } // customConfig.environment.variables;
}
