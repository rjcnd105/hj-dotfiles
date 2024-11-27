{ catppuccin, ... }: {
    imports = [
      catppuccin.homeManagerModules.catppuccin
    ];

    catppuccin = {
      enable = true;
      flavor = "macchiato";
    };
}
