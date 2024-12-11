{
  config,
  pkgs,
  customConfig,
  ...
}:
{
  xdg.configFile = {
    zellij = {
      recursive = true;
      source = config.lib.file.mkOutOfStoreSymlink "${customConfig.dotEnv}/zellij";
    };
    nushell = {
      recursive = true;
      source = config.lib.file.mkOutOfStoreSymlink "${customConfig.dotEnv}/nushell";
    };
  };

  programs = {

    # shell customize
    starship = {
      enable = true;
      enableZshIntegration = true;
      enableNushellIntegration = true;
    };

    direnv = {
      enable = true;
      mise.enable = true;
      nix-direnv.enable = true;
      enableNushellIntegration = true;
    };

    zellij = {
      enable = true;
    };

    # folder viewer
    yazi = {
      enable = true;
      enableNushellIntegration = true;
      settings = {
        manager = {
          show_hidden = true;
          sort_by = "modified";
          sort_dir_first = true;
          tab_size = 2;
          sort_reverse = true;
          ratio = [
            2
            3
            3
          ];
        };
      };
    };
    # db base cli history
    atuin = {
      enable = true;
      enableNushellIntegration = true;
      flags = [
        "--disable-up-arrow"
      ];
    };
    # command complication
    carapace = {
      enable = true;
      enableNushellIntegration = true;
    };

    nushell = {
      enable = true;
      package = pkgs.nushell;
    };

  };
  home.shellAliases = {
    y = "yazi";
  };
}
