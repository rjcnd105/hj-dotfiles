{ pkgs, config, ... }:

{
  programs = {

    fish = {
      enable = true;
      package = pkgs.fish;
      loginShellInit = ''
        set -Ua fish_features remove-percent-self test-require-arg

        for line in (bash -c "source /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh && env")
            set arr (echo $line | string split "=")
            if test (count $arr) -eq 2
                if not set -qx $arr[1]
                    or set -gx $arr[1] $arr[2] 2>/dev/null
                end
            end
        end

        fish_add_path --move --prepend  ${config.home.sessionVariables.CURRENT} ${config.home.sessionVariables.USER_PROFILE}
        set -gx SHELL ${pkgs.fish}/bin/fish

        zellij
      '';
    };
  };
}
