{
  config,
  lib,
  pkgs,
  ...
}:
let
  homedir = config.home.homeDirectory;
in
{
  xdg = {
    enable = true;

    # --- Base Dirs ---
    cacheHome = "${homedir}/.cache";
    configHome = "${homedir}/.config";
    dataHome = "${homedir}/.local/share";
    stateHome = "${homedir}/.local/state";

    # --- MIME Type Handling ---
    # TODO: Move to separate file: mimetypes.nix
    # TODO: Set MimeType for default terminal application: `x-scheme-handler/terminal`
    # TODO: Configure: `~/.config/handlr/handlr.toml`
    #xdg.mimeApps = { associations = { added={}; removed={}; }; defaultApplications={}; };
    #home.packages = [pkgs.handlr];
    mimeApps.enable = true;
    mime.enable = true;

    systemDirs = {
      config = [ "/etc/xdg" ];
      data = [
        "/usr/share"
        "/usr/local/share"
      ];
    };

    userDirs = {
      enable = true;
      createDirectories = true;
      extraConfig = with config.xdg; {

        XDG_APPS_DIR = "${homedir}/.local/apps";
        XDG_SYNC_DIR = "${homedir}/.local/sync";
        XDG_LAUNCHERS_DIR = "${dataHome}/applications";
        XDG_UNITS_DIR = "${configHome}/systemd";
        XDG_BIN_DIR = "${homedir}/.local/bin";
        XDG_SCRIPTS_DIR = "${homedir}/.local/scripts";
        XDG_SECRETS_DIR = "${homedir}/.local/secrets";
        XDG_AUTOSTART_DIR = "${dataHome}/autostart";
      };
    };
  };

  nix.settings.use-xdg-base-directories = true;
  home.sessionVariables = {
    XDG_CONFIG_HOME = xdgPaths.configHome;
    XDG_CACHE_HOME = xdgPaths.cacheHome;
    XDG_DATA_HOME = xdgPaths.dataHome;
    XDG_STATE_HOME = xdgPaths.stateHome;
  };

  home.sessionPath = with config.xdg.userDirs.extraConfig; [
    # --- Custom Executables ---
    XDG_APPS_DIR
    XDG_BIN_DIR
    XDG_SCRIPTS_DIR

  ];

  home = {
    # TODO: Package: https://github.com/doron-cohen/antidot
    packages = [
      pkgs.handlr
      pkgs.xdg-ninja
    ];
    preferXdgDirectories = true;
    #profileDirectory = "${dataDir}/nix/profiles";
    shellAliases = {
      o = "xdg-open";
      open = "xdg-open";

      cd-config = "cd $XDG_CONFIG_HOME";
      cd-data = "cd $XDG_DATA_HOME";
      cd-cache = "cd $XDG_CACHE_HOME";
      cd-state = "cd $XDG_STATE_HOME";

      ls-config = "ls $XDG_CONFIG_HOME";
      ls-data = "ls $XDG_DATA_HOME";
      ls-cache = "ls $XDG_CACHE_HOME";
      ls-state = "ls $XDG_STATE_HOME";
    };
  };

  xdg.configFile = {
    zellij = {
      recursive = true;
      source = config.lib.file.mkOutOfStoreSymlink "${myOptions.dotEnv}/zellij";
    };
    nushell = {
      recursive = true;
      source = config.lib.file.mkOutOfStoreSymlink "${myOptions.dotEnv}/nushell";
    };
  };

  # --- System -----------------------------------
  pam.yubico.authorizedYubiKeys.path = "${config.xdg.dataHome}/yubico/authorized_yubikeys";

  programs =
    with config.xdg;
    with config.xdg.userDirs.extraConfig;
    {

      # --- Shells -----------------------------------
      bash.historyFile = "${dataHome}/bash/history";
      zsh.history.path = "${dataHome}/zsh/history";
      nushell = {
        configFile.source = "${configHome}/nushell/config.nu";
        envFile.source = "${configHome}/nushell/env.nu";
      };

      # --- CLI Programs -----------------------------
      gpg.homedir = "${dataHome}/gnupg";
      navi.settings.cheats.paths = [
        "${dataHome}/cheats"
        "${configHome}/navi/cheats"
      ];
      script-directory.settings.SD_ROOT = XDG_SCRIPTS_DIR;
    };

  # --- GUI Programs -----------------------------
  # services =
  #   with config.xdg.userDirs.extraConfig;
  #   with config.xdg;
  #   {

  #   };

}
