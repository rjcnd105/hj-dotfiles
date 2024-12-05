{ pkgs, config, ... }:
{
  programs.rio = {
    enable = true;
    package = pkgs.rio;

    settings = {
      confirm-before-quit = false;

      shell = {
        program = "${config.home.profileDirectory}/bin/nu";
        args = [
          "--login"

        ];
      };
      fonts = {
        family = "D2CodingLigature Nerd Font";
        size = 13;

        extras = [
          { family = "Lilex Nerd Font"; }
        ];

      };
    };
  };
}
