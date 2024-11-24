{
  packages.thefuck = {
    enable = true;
  };

  programs.zsh.shellAliases = {
    f = "fuck";  # thefuck의 짧은 단축어
  };

  programs.zsh = {
    initExtra = ''
      eval $(thefuck --alias)
    '';
  };
}
