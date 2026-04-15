# Cloudflare Tunnel — 공개 인터넷 → homelab 서비스 라우팅
# systemd DynamicUser + LoadCredential 패턴으로 credentials 안전 전달.
# dry-run 단계에서는 hindsight-test.deopjib.site 사용.
# Unit 6(DNS cutover)에서 hindsight.deopjib.site로 교체 예정.
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
        "hindsight-test.deopjib.site" = "http://localhost:8888";
      };
      default = "http_status:404";
    };
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
