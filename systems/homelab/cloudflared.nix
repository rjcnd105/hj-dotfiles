# Cloudflare Tunnel — 공개 인터넷 → homelab 서비스 라우팅
# systemd DynamicUser + LoadCredential 패턴으로 credentials 안전 전달.
#
# ingress 항목은 app-containers.nix가 앱별로 병합한다(services.cloudflared.tunnels.<id>.ingress).
# 여기서는 터널 자체와 credentials, 기본 거부 응답만 선언한다.
{
  config,
  myOptions,
  ...
}:
{
  services.cloudflared = {
    enable = true;
    tunnels."a19003a7-293f-4872-b8a5-1db544878f45" = {
      credentialsFile = config.sops.secrets."cloudflared-credentials".path;
      default = "http_status:404";
    };
  };

  systemd.services."cloudflared-tunnel-a19003a7-293f-4872-b8a5-1db544878f45" = {
    requires = [ "sops-install-secrets.service" ];
    after = [ "sops-install-secrets.service" ];
  };

  # Tunnel credentials JSON (sops binary format)
  # sops가 decrypt → /run/secrets/cloudflared-credentials에 원본 JSON 복원
  # → systemd LoadCredential이 서비스 credential dir로 전달
  sops.secrets."cloudflared-credentials" = {
    format = "binary";
    sopsFile = ../../secrets/homelab/cloudflared.json;
    mode = "0400";
  };
}
