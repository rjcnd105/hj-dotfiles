{ inputs, ... }: {
    imports = [
        inputs.catppuccin.homeManagerModules.catppuccin
    ];
    # frappe, latte, macchiato, mocha 중 선택
    colorscheme = inputs.catppuccin.colorSchemes.macchiato;

    # Catppuccin 테마 활성화
    catppuccin.enable = true;
}
