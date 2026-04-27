# Cloudflare Tunnel — 공개 인터넷 → homelab 서비스 라우팅
# systemd DynamicUser + LoadCredential 패턴으로 credentials 안전 전달.
#
# hindsight 0.5.2-slim은 API만 포함(9999 대시보드 없음) → hostname 단일 매핑으로 충분.
# 존재하지 않는 경로는 hindsight API가 404 반환. VPS Caddyfile 대비 공개 표면 축소.
#
# 본 변경은 DNS 전환(Unit 5) 전까지 외부 영향 없음 —
# hindsight.deopjib.site DNS가 VPS Caddy를 가리키는 동안 homelab은 준비 상태만 유지.
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
      ingress = {
        "hindsight.deopjib.site" = "http://localhost:8888";
      };
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
