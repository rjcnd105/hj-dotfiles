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

        set -g fish_greeting

        # VIM 모드 커서 모양 설정
        set fish_cursor_default block
        set fish_cursor_insert line
        set fish_cursor_replace_one underscore
      '';
    };
  };
}
