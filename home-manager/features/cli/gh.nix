{ config, pkgs, lib, ... }:
{
  # GitHub CLI 설정
  programs.gh = {
    enable = true;

    # gh 기본 설정
    settings = {
      prompt = "enabled";
    };
  };

  home.shellAliases = {
    prw = "pr view --web";
  };
}
