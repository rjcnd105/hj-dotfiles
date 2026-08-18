{
  # https://github.com/junegunn/fzf
  programs.fzf = {
    enable = true;
    # fzf와 Atuin이 둘 다 Ctrl-R을 잡는다. Atuin 통합이 나중에 source되어
    # 실제로는 Atuin이 이기고 있었고, home-manager가 그 암묵 해결을 경고한다.
    # 현재 동작(Ctrl-R = Atuin)을 그대로 명시한다.
    # fzf에게 Ctrl-R을 주려면 이 줄을 지우고 Atuin flags에
    # "--disable-ctrl-r"을 추가하면 된다.
    historyWidget.command = "";
  };
}
