{ pkgs, ... }:
{
  # programs.jujutsu 미사용: files/workspace/.config/jj/config.toml이
  # file.nix 심링크로 관리되어 config 충돌 발생
  home.packages = [ pkgs.jujutsu ];
}
