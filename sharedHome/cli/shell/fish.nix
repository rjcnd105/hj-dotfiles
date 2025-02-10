{ pkgs, config, ... }:

{

  programs = {

    fish = {
      enable = true;
      package = pkgs.fish;

      loginShellInit = ''
        set -gx fish_features remove-percent-self test-require-arg

        set -gx SHELL ${pkgs.fish}/bin/fish

        # echo $PATH | tr ' ' '\n' | grep -v mise
      '';

      interactiveShellInit = ''
        source $HOME/.config/fish/user-functions.fish
        fish_add_path -maP /usr/bin /usr/sbin /bin /sbin

      '';
    };
  };
}
