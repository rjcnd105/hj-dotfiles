{ pkgs, ... }: {
  programs.nixvim = {

    plugins = {
      lualine.enable = true;
      bufferline.enable = true;
      web-devicons.enable = true;
      nvim-treesitter.enable = true;
      lsp.enable = true;
    };
  };
}
