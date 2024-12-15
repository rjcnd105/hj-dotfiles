{
  config,
  inputs,
  myOptions,
  pkgs,
  ...
}:
{

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

      shellAliases = config.home.shellAliases;

      environmentVariables = {
        USER_PROFILE_DIR = toString config.home.profileDirectory;
        SHELL = "${config.home.profileDirectory}/bin/nu";
      };

      extraEnv = ''
        source "~/.config/nushell/env.nu";
      '';
      extraLogin = ''
        source "~/.config/nushell/login.nu";
      '';
      extraConfig = ''
        source "~/.config/nushell/config.nu";
      '';
    };

  };
  home.shellAliases = {
    y = "yazi";
  };
}
