{ pkgs, config, ... }:
let
  defaultPATH = builtins.getEnv "PATH";
in
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

      developer = {
        log-level = "Debug";
      };
      env-vars = [
        "PATH=${defaultPATH}"
      ];
      shell = {
        program = "${config.home.profileDirectory}/bin/fish";
        args = [
          "--login"
        ];
      };
      fonts = {
        size = 12;
        family = "D2CodingLigature Nerd Font";

        regular.weight = 500;
        italic.weight = 500;

      };
    };
  };
}
