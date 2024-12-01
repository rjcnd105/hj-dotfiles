{ config, pkgs, ... }: {
  programs.fish = {
    enable = true;
    # setup vi mode
    shellInit = ''
      # shut up welcome message
      set fish_greeting
    '';
  };
}
