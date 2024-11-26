{
  # https://github.com/junegunn/fzf
  programs.fzf = {
    enable = true;
    enableFishIntegration = true;
  };

  # https://github.com/junegunn/fzf-git.sh?tab=readme-ov-file
  # fzf-git.sh 설정 추가
  programs.zsh = {
    initExtra = ''
      # fzf-git.sh 설치 및 로드
      if [[ ! -f ~/.config/fzf-git.sh ]]; then
        mkdir -p ~/.config
        curl -o ~/.config/fzf-git.sh https://raw.githubusercontent.com/junegunn/fzf-git.sh/main/fzf-git.sh
      fi
      source ~/.config/fzf-git.sh
    '';
  };

  home.sessionVariables = {
    FZF_CTRL_T_OPTS = "--preview 'bat -n --color=always --line-range :500 {}'";
    FZF_ALT_C_OPTS = "--preview 'eza --tree --color=always {} | head -200'";
  }
}
