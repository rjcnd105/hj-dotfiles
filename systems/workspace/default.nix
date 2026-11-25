{
  pkgs,
  ...
}:
{
  config = {
    environment.systemPackages = [
      pkgs.devenv
    ];

    homebrew = {
      enable = true;
    };

    programs.fish.enable = true;

    environment.shells = [
      pkgs.bashInteractive
      pkgs.zsh
      pkgs.fish
    ];

    fonts.packages = [
      pkgs.sarasa-gothic
      pkgs.nerd-fonts.d2coding
      pkgs.nerd-fonts.jetbrains-mono
    ];

    security.pam.services.sudo_local.touchIdAuth = true;

    # Determinate Nix 사용 — nix-darwin의 nix 관리 비활성화
    # https://determinate.systems/blog/nix-darwin-updates/#what-you-should-change
    nix.enable = false;
  };
}
