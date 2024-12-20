{ pkgs, config, ... }:
{
  programs = {

    fish = {
      enable = true;
      package = pkgs.fish;

      loginShellInit = ''
        source ~/.config/fish/loginInit.fish

        set -gx USER_PROFILE_DIR ${config.home.profileDirectory}
        set -gx SHELL ${config.home.profileDirectory}/bin/fish
      '';

      shellInit = ''
        source ~/.config/fish/shellInit.fish
      '';
    };
  };
}
