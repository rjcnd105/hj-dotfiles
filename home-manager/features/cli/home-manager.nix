{ pkgs, ...}:
{
  manual.manpages.enable = true;
  news.display = "show";

  home.packages = with pkgs; [
    home-manager
  ];

  programs.zsh.shellAliases = {
    hm = "home-manager switch";
  };

}
