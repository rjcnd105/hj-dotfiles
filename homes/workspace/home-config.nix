{
  config,
  inputs,
  pkgs,
  lib,
  myOptions,
  ...
}:
{
  home.username = myOptions.userName;

  home.shellAliases = {
    ping = "gping";
    pskill = "ps -f | fzf | awk '{print $2}' | xargs kill";
    lzg = "lazygit";
  };

  home.sessionVariables = {
    HOME_VERSION = inputs.nixpkgs.lib.trivial.release;
    EDITOR = pkgs.helix + "/bin/hx";
    USER_PROFILE = config.home.profileDirectory;
  }
  // lib.optionalAttrs (myOptions.absoluteProjectPath != null) {
    PROJECT_PATH = myOptions.absoluteProjectPath;
  }
  // lib.optionalAttrs pkgs.stdenv.hostPlatform.isDarwin {
    VISUAL = "/usr/local/bin/zed";
    OBSIDIAN = "$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents";
    ZED_ALLOW_ROOT = "true";
    TERMINFO_DIRS = "${config.home.profileDirectory}/share/terminfo:/run/current-system/sw/share/terminfo:/usr/share/terminfo";
  };

  home.sessionPath = [
    "${config.home.homeDirectory}/.local/bin"
    "${config.home.homeDirectory}/.cache/.bun/bin"
    "${config.home.homeDirectory}/.local/scripts"
  ];

  home.stateVersion = "26.11";

  home.packages = [
    pkgs.zsh
    pkgs.helix
    pkgs.ripgrep
    pkgs.sd
    pkgs.jq
    pkgs.coreutils
    pkgs.file
    pkgs.fd
    pkgs.restic
    pkgs.pwgen
    pkgs.curl
    pkgs.cloudflared
    pkgs.gping
    pkgs.dua
    pkgs.p7zip
    pkgs.zstd
  ]
  ++ lib.optionals pkgs.stdenv.hostPlatform.isDarwin [
    pkgs.fontconfig
    pkgs.lima
  ];

  fonts.fontconfig.enable = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin true;
}
