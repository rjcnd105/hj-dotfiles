{ pkgs, config, ... }:

{
  programs = {

    fish = {
      enable = true;
      package = pkgs.fish;
      loginShellInit = ''
        for line in (bash -c "source /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh && env")
            set arr (echo $line | string split "=")
            if test (count $arr) -eq 2
                if not set -qx $arr[1]
                    or set -gx $arr[1] $arr[2] 2>/dev/null
                end
            end
        end

        set -gx USER_PROFILE_DIR ${config.home.profileDirectory}
        set -gx SHELL ${config.home.profileDirectory}/bin/fish

        zellij
      '';
    };
  };
}
