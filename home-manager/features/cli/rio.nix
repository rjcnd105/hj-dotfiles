{
  programs.rio = {
    enable = true;

    settings = {
      confirm-before-quit = false;
      editor = {
        program = "zed";
        args = [ ];
      };
      shell = {
          program = "${pkgs.fish}";
          args = [ ];
      };
      fonts = {
        family = "JetBrainsMono Nerd Font";
        size = 11;

        regular = {
          style = "normal";
          weight = 300;
        };
        bold = {
          style = "normal";
          weight = 500;
        };
        italic = {
          style = "italic";
          weight = 300;
        };
        bold-italic = {
          style = "italic";
          weight = 500;
        };
      }
    };
  };
}
