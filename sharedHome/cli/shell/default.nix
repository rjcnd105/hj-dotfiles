{
  config,
  inputs,
  myOptions,
  pkgs,
  ...
}:
{
  imports = [
    ./mise.nix
  ];

  programs = {

    fish = {
      enable = true;
      package = pkgs.fish;
      shellAliases = config.home.shellAliases;

      loginShellInit = ''
        source "~/.config/fish/login.fish";

        set -gx USER_PROFILE_DIR ${config.home.profileDirectory}
        set -gx SHELL ${config.home.profileDirectory}/bin/fish
      '';

      shellInit = ''
        source "~/.config/fish/config.fish";
      '';
    };

    # shell customize
    starship = {
      enable = true;
      enableZshIntegration = true;
      enableFishIntegration = true;
    };

    direnv = {
      enable = true;
      mise.enable = true;
      nix-direnv.enable = true;
      enableFishIntegration = true;
    };

    zellij = {
      enable = true;
      enableFishIntegration = true;
    };

    # folder viewer
    yazi = {
      enable = true;
      settings = {
        manager = {
          show_hidden = true;
          sort_by = "mtime";
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
      flags = [
        "--disable-up-arrow"
      ];
    };
    # command complication
    carapace = {
      enable = true;
    };

  };
  home.shellAliases = {
    y = "yazi";
  };
}
