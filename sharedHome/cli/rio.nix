{ pkgs, config, ... }:
{
  programs.rio = {
    enable = true;

    settings = {
      confirm-before-quit = false;

      shell = {
        # program = "${config.home.profileDirectory}/bin/nu";
        program = "${config.home.profileDirectory}/bin/nu";
        args = [
          "--login"
          "--config"
          "${config.home.sessionVariables.XDG_CONFIG_HOME}/nushell/config.nu"
          "--env-config"
          "${config.home.sessionVariables.XDG_CONFIG_HOME}/nushell/env.nu"
        ];
      };
      fonts = {
        family = "D2CodingLigature Nerd Font Mono";
        size = 13;

        extras = [
          { family = "JetBrainsMono Nerd Font Mono"; }
        ];

      };
    };
  };

}
