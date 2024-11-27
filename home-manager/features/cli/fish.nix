{ config, pkgs, ... }: {
  programs.fish = {
    enable = true;
    # setup vi mode
    shellInit = ''
      # shut up welcome message
      set fish_greeting
    '';
    # # use abbreviations instead of aliases
    # preferAbbrs = true;
    # # seems like shell abbreviations take precedence over aliases
    # shellAbbrs = config.home.shellAliases;
  };
}
