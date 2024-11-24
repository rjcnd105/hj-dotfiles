{
  # https://github.com/junegunn/fzf
  programs.fzf = {
    enable = true;
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
}
