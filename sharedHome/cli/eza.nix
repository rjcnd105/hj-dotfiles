let
  lt2 = "eza --tree --icons -L 2";
  lt3 = "eza --tree --icons -L 3";
in
{
  programs.eza = {
    enable = true;
    icons = "always";
    enableFishIntegration = true;

    extraOptions = [
      "--group-directories-first"
      "--header"
      "--octal-permissions"
      "--hyperlink"
    ];
  };

  home.sessionVariables = {
    FZF_ALT_C_OPTS = "--preview 'eza --tree --color=always {} | head -200'";
  };

  home.shellAliases = {
    ls = "eza --icons --git";
    ll = "eza -l --icons --git";
    la = "eza -la --icons --git";
    lt1 = "eza --tree --icons -L 1";
    inherit lt2 lt3;
    lt = lt2;
    llt1 = "eza -l --tree --icons -L 1";
    llt2 = "eza -l --tree --icons -L 2";
    llt3 = "eza -l --tree --icons -L 3";
    tree = lt2;
    tree3 = lt3;
    lg = "eza -l --icons --git-ignore";
    lm = "eza -l --icons --sort=modified";
    lsize = "eza -l --icons --sort=size";
    ldot = "eza -ld --icons .*";
    ldir = "eza -lD --icons";
    lfile = "eza -lf --icons";
  };
}
