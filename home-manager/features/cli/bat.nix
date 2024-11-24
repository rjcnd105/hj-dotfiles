{
  programs.bat = {
    enable = true;
    config = {
      theme = "Catppuccin Mocha";
    };
    extraPackages = [ ];
  };
  programs.zsh.shellAliases = {
    cat = "bat --style=plain --paging=never";
  };
}
