{ config, pkgs, ... }:
{
  programs = {

    bash = {
      # load the alias file for work
      bashrcExtra = ''
        alias_for_work=/etc/agenix/alias-for-work.bash
        if [ -f $alias_for_work ]; then
          . $alias_for_work
        else
          echo "No alias file found for work"
        fi
      '';
    };
    # shell customize
    starship = {
      enable = true;
      enableBashIntegration = true;
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
    };
    # db base cli history
    atuin = {
      enable = true;
      enableNushellIntegration = true;
    };
    # command complication
    carapace = {
      enable = true;
      enableNushellIntegration = true;
    };

    nushell = {
      enable = true;
      shellAliases = config.home.shellAliases;
      environmentVariables = config.home.sessionVariables;
      # configFile.source = config.xdg.configHome + "/nushell/config.nu";
      # envFile.source = config.xdg.configHome + "/nushell/env.nu";
      # # auto start zellij in nushell
      # extraConfig = ''
      #   # auto start zellij
      #   # except when in emacs or zellij itself
      #   if (not ("ZELLIJ" in $env)) and (not ("INSIDE_EMACS" in $env)) {
      #     if "ZELLIJ_AUTO_ATTACH" in $env and $env.ZELLIJ_AUTO_ATTACH == "true" {
      #       ^zellij attach -c
      #     } else {
      #       ^zellij
      #     }

      #     # Auto exit the shell session when zellij exit
      #     $env.ZELLIJ_AUTO_EXIT = "false" # disable auto exit
      #     if "ZELLIJ_AUTO_EXIT" in $env and $env.ZELLIJ_AUTO_EXIT == "true" {
      #       exit
      #     }
      #   }

      #   let carapace_completer = {
      #       |spans|
      #       carapace $spans.0 nushell $spans | from json
      #   }
      #   $env.config = {
      #       show_banner: false,
      #       completions: {
      #           case_sensitive: false # case-sensitive completions
      #           quick: true    # set to false to prevent auto-selecting completions
      #           partial: true    # set to false to prevent partial filling of the prompt
      #           algorithm: "fuzzy"    # prefix or fuzzy
      #           external: {
      #               # set to false to prevent nushell looking into $env.PATH to find more suggestions
      #               enable: true
      #               # set to lower can improve completion performance at the cost of omitting some options
      #               max_results: 100
      #               completer: $carapace_completer # check 'carapace_completer'
      #           }
      #       }
      #   }
      #   $env.PATH = ($env.PATH |
      #   split row (char esep) |
      #   prepend /home/myuser/.apps |
      #   append /usr/bin/env
      #   )
      # '';
    };

  };
  home.shellAliases = {
    y = "yazi";
  };
}
