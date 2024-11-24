{
  programs.home-manager.enable = true;
  manual.manpages.enable = true;
  news.display = "show";

  # 별칭 설정
  shellAliases = {
    hm = "home-manager switch";
  };

}
