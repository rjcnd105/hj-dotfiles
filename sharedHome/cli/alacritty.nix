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
      };
      terminal.shell = {
        program = "${config.home.profileDirectory}/bin/fish";
        args = [
          "--login"
        ];
      };
      window = {
        decorations = "Buttonless";
        option_as_alt = "OnlyLeft";
        blur = true;
        opacity = 0.92;
      };
      font = {
        size = 11.5;
        normal.family = "JetBrainsMono Nerd Font";
        normal.style = "Light";

        bold.family = "JetBrainsMono Nerd Font";
        bold.style = "SemiBold";

        italic.family = "JetBrainsMono Nerd Font";
        italic.style = "Light Italic";

        bold_italic.family = "JetBrainsMono Nerd Font";
        bold_italic.style = "SemiBold Italic";
      };
    };
  };
}
