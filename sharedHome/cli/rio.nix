{ pkgs, config, ... }:
{
  programs.rio = {
    enable = true;
    package = pkgs.rio;

    settings = {
      confirm-before-quit = false;
      option-as-alt = "left";

      padding-x = 4;
      padding-y = [4 4];

      window = {
        width = 1200;
        height = 700;
        decorations = "Disabled";
        opacity = 0.95;
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
