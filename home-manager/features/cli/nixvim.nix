{
  programs.nixvim = {
    enable = true;

    plugins = {
      lualine.enable = true;
      bufferline.enable = true;
      web-devicons.enable = true;
      lspkind = {
        enable = true;
        cmp = {
            enable = true;
            menu = {
                nvim_lsp = "[LSP]";
                nvim_lua = "[api]";
                path = "[path]";
                luasnip = "[snip]";
                buffer = "[buffer]";
                neorg = "[neorg]";
                nixpkgs_maintainers = "[nixpkgs]";
            };
        };
     };
    }
    opts = {
      mouse = "a"; # Enable mouse control
    };

    extraPlugins = with pkgs.vimPlugins; [
      vim-nix
    ];
  };
}
