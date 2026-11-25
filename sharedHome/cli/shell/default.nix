{
  pkgs,
  ...
}:
{
  imports = [
    ./fish.nix
    ./mise.nix
  ];

  programs = {
    starship = {
      enable = true;
      enableZshIntegration = true;
      enableFishIntegration = true;
      settings = {
        add_newline = false;
        character = {
          success_symbol = "[➜](bold green)";
          error_symbol = "[✗](bold red)";
        };
        package.disabled = true;
      };
    };

    direnv = {
      enable = true;
      nix-direnv.enable = true;
    };

    yazi = {
      enable = true;
    };

    atuin = {
      package = pkgs.atuin;
      enable = true;
      enableFishIntegration = true;
      flags = [
        "--disable-up-arrow"
      ];
    };

    carapace = {
      enable = true;
    };
  };

  home.shellAliases = {
    y = "yazi";
  };
}
