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
    ./mise.nix
  ];

  programs = {

    # shell customize
    starship = {
      enable = true;
      enableZshIntegration = true;
      enableFishIntegration = true;
    };

    direnv = {
      enable = true;
      mise.enable = true;
      nix-direnv.enable = true;
    };

    zellij = {
      enable = true;
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
      enable = true;
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
