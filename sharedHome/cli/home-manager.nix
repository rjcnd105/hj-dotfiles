{ pkgs, ... }:
{
  news.display = "show";

  home.packages = with pkgs; [
    home-manager
  ];

  home.shellAliases = {
    hm = "home-manager switch";
  };

}
