{
  config,
  inputs,
  myOptions,
  pkgs,
  ...
}:
{
  imports = [
    ./fish.nix
    # ./mise.nix
  ];

  programs = {

    # shell customize
    starship = {
      enable = true;
      enableZshIntegration = true;
      enableFishIntegration = true;
      # 현대적인 프리셋 적용
      settings = {
        add_newline = false;
        # Transient Prompt 기능과 유사한 깔끔한 설정
        character = {
          success_symbol = "[➜](bold green)";
          error_symbol = "[✗](bold red)";
        };
        package.disabled = true; # 불필요한 정보 숨김
      };
    };

    direnv = {
      enable = true;
      # mise.enable = true;
      nix-direnv.enable = true;
    };

    zellij = {
      enable = true;
      enableFishIntegration = false;
    };
    # folder viewer
    yazi = {
      enable = true;
      settings = {
        manager = {
          show_hidden = true;
          sort_by = "mtime";
          sort_dir_first = true;
          tab_size = 2;
          sort_reverse = true;
          ratio = [
            2
            3
            3
          ];
        };
      };
    };
    # db base cli history
    atuin = {
      package = pkgs.atuin;
      enable = true;
      enableFishIntegration = true;
      flags = [
        "--disable-up-arrow"
      ];
    };
    # command complication
    carapace = {
      enable = true;

    };

  };
  home.shellAliases = {
    y = "yazi";
  };
}
