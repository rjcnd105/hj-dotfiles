{ config, pkgs, ... }:
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
      settings = {
        default_shell = "nu";
        pane_frames = false;
        simplified_ui = true;
        # copy_command = "pbcopy";
        # copy_on_select=false
        keybinds = {
          unbind = [ "Alt Right" ];

        "shared_except \"locked\"" = {
            "bind \"alt 1\"" = { GoToTab = 1; };
            "bind \"alt 2\"" = { GoToTab = 2; };
            "bind \"alt 3\"" = { GoToTab = 3; };
            "bind \"alt 4\"" = { GoToTab = 4; };
            "bind \"alt 5\"" = { GoToTab = 5; };
            "bind \"alt 6\"" = { GoToTab = 6; };
            "bind \"alt 7\"" = { GoToTab = 7; };
            "bind \"alt 8\"" = { GoToTab = 8; };
            "bind \"alt 9\"" = { GoToTab = 9; };

            "bind \"alt H\"" = { NewPane = "Left"; };
            "bind \"alt J\"" = { NewPane = "Down"; };
            "bind \"alt K\"" = { NewPane = "Up"; };
            "bind \"alt L\"" = { NewPane = "Right"; };

            "bind \"alt w\"" = { CloseFocus = {}; };
          };
        };
      };
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

    nushell =
      {
        enable = true;
        extraEnv = ''
          sh -c "source /etc/profile"
          sh -c "source ~/.profile"
          $env.SHELL = "${config.home.profileDirectory}/bin/nu"
        '';
        extraConfig = ''
          $env.config = {
            show_banner: false
            display_errors: {
                exit_code: false
                termination_signal: true
            }
          }
            def --env load_zsh_env [] {
                let zsh_env = (^/bin/zsh -ic 'env' | lines | split column "=" --collapse-empty)
                let restricted_vars = ["PWD" "OLDPWD" "LAST_EXIT_CODE" "CMD_DURATION_MS" "SHELL"]

                for item in $zsh_env {
                    if ($item.column1 not-in $restricted_vars) {
                        load-env { $item.column1: $item.column2 }
                    }
                }
            }

            load_zsh_env


            def local_psql [db: string] {
                usql $"postgres://($env.PGHOST):($env.PGPORT)/($db)"
                }


            def start_zellij [] {
              if 'ZELLIJ' not-in ($env | columns) {
                if 'ZELLIJ_AUTO_ATTACH' in ($env | columns) and $env.ZELLIJ_AUTO_ATTACH == 'true' {
                  zellij attach -c
                } else {
                  zellij
                }

                if 'ZELLIJ_AUTO_EXIT' in ($env | columns) and $env.ZELLIJ_AUTO_EXIT == 'true' {
                  exit
                }
              }
            }

            start_zellij
        '';
      };

  };
  home.shellAliases = {
    y = "yazi";
  };
}
