{ config, pkgs, lib, ... }:
{
  # GitHub CLI 설정
  programs.gh = {
    enable = true;

    # gh 기본 설정
    settings = {
      prompt = "enabled";

      aliases = {
        prw = "pr view --web";
      };
    };
  };

  # gh completion 설정 (zsh 사용 시)
  programs.zsh.initExtra = lib.mkIf (config.programs.zsh.enable && config.programs.gh.enable) ''
    eval "$(gh completion -s zsh)"
  '';
}
