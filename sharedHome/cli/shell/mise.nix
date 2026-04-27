{ lib, ... }:
{
  # mise는 Nix/Home Manager가 설치하거나 shell integration을 생성하지 않는다.
  programs.mise.enable = lib.mkDefault false;
}
