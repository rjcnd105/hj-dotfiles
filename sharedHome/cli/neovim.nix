{ pkgs, ... }:
{
  programs.neovim = {
    enable = true;
    programs.neovim = {
      enable = true;
      plugins = with pkgs.vimPlugins; [
        nvim-cmp
        cmp-nvim-lsp
        cmp-path
        cmp-buffer
        cmp-cmdline
      ];
    };
  };
}
