{ config, ... }:
let
  defaultPATH = builtins.getEnv "PATH";
in
{
  programs.alacritty = {
    enable = true;
    settings = {
      env = {
        TERM = "xterm-256color";
        PATH = defaultPATH;
        SHELL = "${config.home.profileDirectory}/bin/fish";
      };
      terminal.shell = {
        program = "${config.home.profileDirectory}/bin/zellij";
        args = [
          "--layout"
          "default"
        ];
      };
      window = {
        decorations = "Buttonless";
        option_as_alt = "Both";
        blur = true;
        opacity = 0.92;
      };
      font = {
        size = 11.5;
        normal.family = "D2CodingLigature Nerd Font";
        normal.style = "Regular";

        bold.family = "D2CodingLigature Nerd Font";
        bold.style = "Bold";

        italic.family = "D2CodingLigature Nerd Font";
        italic.style = "Italic";
      };
      window.dimensions = {
        columns = 250;
        lines = 62;
      };
    };
  };
}
