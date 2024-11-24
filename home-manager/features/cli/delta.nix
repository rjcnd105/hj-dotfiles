# https://github.com/dandavison/delta
{ pkgs, ... }:
{
  home.packages = with pkgs; [
    delta  # delta 패키지 설치
  ];

  programs.git = {
    delta = {  # git diff 강화
        enable = true;
        options = {
            hyperlinks = true;
            line-numbers = true;
            hunk-header-style = "syntax";
        };
    };
  };
}
