{ config, pkgs, ... }:
  programs.fish = {
    enable = true;
    # setup vi mode
    interactiveShellInit = ''
      fish_vi_key_bindings
    '';
    shellInit = ''
      # shut up welcome message
      set fish_greeting

      # set options for plugins
      set sponge_regex_patterns 'password|passwd'

      # bind --mode default \t complete-and-search
    '';
    # use abbreviations instead of aliases
    preferAbbrs = true;
    # seems like shell abbreviations take precedence over aliases
    shellAbbrs = config.home.shellAliases // {
      ehistory = "nvim ${config.xdg.dataHome}/fish/fish_history";
    };
  };

    # fish plugins, home-manager's programs.fish.plugins has a weird format
    home.packages = with pkgs.fishPlugins; [
        # do not add failed commands to history
        sponge
    ];
}
