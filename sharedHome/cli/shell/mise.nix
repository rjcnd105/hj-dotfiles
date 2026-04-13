{ lib, pkgs, ... }:
{
  # NixOS는 FHS 비호환으로 mise 바이너리 실행 불가 — darwin에서만 활성화
  programs.mise = lib.mkIf pkgs.stdenv.isDarwin {
    enable = true;
    enableFishIntegration = true;
  };
}
