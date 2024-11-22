{ pkgs, ... }:
{
  programs.neovim = {
    enable = true;
    vimAlias = true;
    defaultEditor = true;
    # vimdiff를 기본 diff 도구로 설정
    vimdiffAlias = true;
    extraConfig = (builtins.readFile ../../../config/vim/vimrc);
    plugins = [

      # LSP 지원
      pkgs.vimPlugins.nvim-lspconfig
      # 구문 향상
      pkgs.vimPlugins.nvim-treesitter

      #####START########
      # plugin for file tree
      ##################

      #####START########
      # plugin for editing
      ##################
      {
        plugin = pkgs.vimPlugins.supertab;
        config = "let g:SuperTabDefaultCompletionType = '<c-n>'";
      }
      pkgs.vimPlugins.auto-pairs
      pkgs.vimPlugins.vim-better-whitespace
      pkgs.vimPlugins.goyo-vim
      {
        plugin = pkgs.vimPlugins.limelight-vim;
        config = ''
          let g:limelight_conceal_ctermfg = 'gray'
          autocmd! User GoyoEnter Limelight
          autocmd! User GoyoLeave Limelight!
        '';
      }
      #####END##########

      #####START########
      # plugin for searching
      ##################
      {
        plugin = pkgs.vimPlugins.fzf-vim;
        config = ''
            let $FZF_DEFAULT_COMMAND = 'rg --files'
            let $FZF_DEFAULT_COMMAND = 'fd --type f'

            nnoremap <C-p> :Files<CR>
            nnoremap <C-f> :Rg<CR>
          '';
      }
      #####END##########

      #####START########
      # plugin for MISC
      ##################
      pkgs.vimPlugins.vim-css-color
      {
        plugin = pkgs.vimPlugins.vim-startify;
        config = "let g:startify_change_to_vcs_root = 0";
      }
      {
          plugin = pkgs.vimPlugins.vim-floaterm;
          config = ''
            let g:floaterm_keymap_toggle = '<C-/>'
            let g:floaterm_width = 0.9
            let g:floaterm_height = 0.9

            " lazygit 설정
            let g:floaterm_keymap_new = '<Leader>lg'
            command! Lazygit FloatermNew --autoclose=2 --height=0.9 --width=0.9 lazygit
            nnoremap <silent> <leader>lg :Lazygit<CR>

            cnoreabbrev Term FloatermToggle
          '';
      }

      #####END##########

      #####START########
      # plugin for git
      ##################
      # show status line

      pkgs.vimPlugins.lualine-nvim

      # show git branch info
      pkgs.vimPlugins.vim-fugitive


      pkgs.vimPlugins.catppuccin-nvim
      # git file 탐색
      pkgs.vimPlugins.nvim-tree-lua
      # show git diff info
      pkgs.vimPlugins.vim-gitgutter

      #####END##########


      #####START########
      # plugin for markdown
      ##################
      {
        plugin = pkgs.vimPlugins.vim-table-mode;
        config = "let g:table_mode_corner='|'";
      }
      #####END##########
    ];
  };
  home.packages = with pkgs; [
    xclip # for clipboard
  ];
}
