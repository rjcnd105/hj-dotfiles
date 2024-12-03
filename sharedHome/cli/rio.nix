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
