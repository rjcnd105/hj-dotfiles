{
  programs.bat = {
    enable = true;
    extraPackages = [ ];
  };
  home.shellAliases = {
    cat = "bat --style=plain --paging=never";
  };
  home.sessionVariables = {
    FZF_CTRL_T_OPTS = "--preview 'bat -n --color=always --line-range :500 {}'";
  };
}
