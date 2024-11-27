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
        args = [ "--login" ];
      };
      fonts = {
        family = "D2CodingLigature Nerd Font Mono";
        size = 13;

        extras = [
          { family ="JetBrainsMono Nerd Font Mono"; }
        ];
      };
    };
  };

  home.sessionVariables.TERMINAL = "${config.programs.rio.package}/bin/rio";
}
