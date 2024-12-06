{ pkgs, config, ... }:
{
  programs.rio = {
    enable = true;
    package = pkgs.rio;

    settings = {
      confirm-before-quit = false;
      option-as-alt = "left";

      window = {
        width = 1400;
        height = 800;
        decorations = "Disabled";
        opacity = 0.9;
        blur = true;
      };

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
