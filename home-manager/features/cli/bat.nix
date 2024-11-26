{
  programs.bat = {
    enable = true;
    extraPackages = [ ];
  };
  programs.zsh.shellAliases = {
    cat = "bat --style=plain --paging=never";
  };
}
