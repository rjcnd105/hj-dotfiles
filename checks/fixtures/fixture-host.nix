# eval 전용 픽스처 호스트: 계약 v2 렌더링 검증에 필요한 최소 스텁만 제공한다.
{ ... }:
{
  boot.loader.grub.enable = false;
  fileSystems."/" = {
    device = "none";
    fsType = "tmpfs";
  };
  system.stateVersion = "26.05";
  networking.hostName = "fixture";

  virtualisation.podman.enable = true;

  sops.validateSopsFiles = false;
  sops.defaultSopsFile = ./sops-dummy.yaml;
  sops.age.keyFile = "/var/lib/sops-nix/key.txt";

  # app-containers.nix가 참조하는 터널 id의 eval 스텁 (cloudflared는 비활성).
  services.cloudflared.tunnels."a19003a7-293f-4872-b8a5-1db544878f45" = {
    credentialsFile = "/dev/null";
    default = "http_status:404";
  };
}
