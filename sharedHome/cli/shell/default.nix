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
        extraConfig = ''
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
            echo "get env from zsh"
        '';
      };

  };
  home.shellAliases = {
    y = "yazi";
  };
}
