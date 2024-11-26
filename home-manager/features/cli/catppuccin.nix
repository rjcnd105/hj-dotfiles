{ inputs, ... }: {
    imports = [
        inputs.catppuccin.homeManagerModules.catppuccin
    ];

    catppuccin = {
      enable = true;
      flavor = "macchiato";
    };
}
