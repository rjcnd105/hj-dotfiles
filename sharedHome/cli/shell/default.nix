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

    nushell =
      {
        enable = true;
        package = pkgs.nushell;
      }
      // (
        if pkgs.stdenv.isDarwin then
          {
            loginFile.source = ./login.nu;
          }
        else
          { }
      );

  };
  home.shellAliases = {
    y = "yazi";
  };
}
