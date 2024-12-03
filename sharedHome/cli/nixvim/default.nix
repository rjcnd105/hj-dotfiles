{
  pkgs,
  inputs,
  lib,
  customConfig,
  ...
}:
{
  programs.nixvim = {
    enable = true;

    imports = [
      ./settings.nix
      ./plugins/lazygit.nix
      ./plugins/lsp.nix
      ./plugins/schema.nix
      ./plugins/treesitter.nix
    ];

    colorschemes.catppuccin = {
      enable = true;
      flavor = "macchiato";
    };

    plugins.lualine.enable = true;

  };
}
