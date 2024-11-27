{ pkgs, config, ... }:{
  programs.rio = {
    enable = true;

    settings = {
      confirm-before-quit = false;
      editor = {
        program = "zed";
        args = [ ];
      };

      shell = {
        program = "${config.home.profileDirectory}/bin/fish";
        args = [ ];
      };
      fonts = {
        family = "JetBrainsMono Nerd Font Mono";
        size = 12;

        regular = {
          style = "Normal";
          weight = 400;
        };
        bold = {
          style = "Normal";
          weight = 600;
        };
        italic = {
          style = "Italic";
          weight = 400;
        };
        bold-italic = {
          style = "Italic";
          weight = 600;
        };
      };
    };
  };

  home.sessionVariables.TERMINAL = "${config.programs.rio.package}/bin/rio";
}
