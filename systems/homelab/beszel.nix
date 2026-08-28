# Beszel 모니터링 — hub·agent 모두 nixpkgs 네이티브 (platform-v2 Phase 4).
# 공개 노출은 Caddy(loopback) → cloudflared → Cloudflare Access 게이트 경유만 허용.
#
# 2단계 활성화:
#   1. hub만 배포 → 사용자가 UI에서 관리자 계정 생성 + Add System으로 KEY/TOKEN 발급
#   2. KEY/TOKEN을 sops(BESZEL_AGENT_KEY/BESZEL_AGENT_TOKEN)에 추가 후 agent.enable
#      (sops-install-secrets는 누락 키에서 switch를 죽이므로 secrets 선행이 필수)
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.homelab.beszel;
  domain = "beszel.deopjib.site";
  # 앱 레인(loopbackPortBase 18100+, caddy 18099)과 겹치지 않는 로컬 포트.
  caddyPort = 18090;
  hubPort = 18091;
  agentPort = 45876;
in
{
  options.homelab.beszel = {
    enable = lib.mkEnableOption "Beszel monitoring hub behind Caddy + cloudflared + CF Access";
    agent.enable = lib.mkEnableOption "Beszel agent (requires BESZEL_AGENT_KEY/TOKEN sops secrets)";
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      systemd.services.beszel-hub = {
        description = "Beszel monitoring hub";
        wantedBy = [ "multi-user.target" ];
        wants = [ "network-online.target" ];
        after = [ "network-online.target" ];
        environment.BESZEL_HUB_APP_URL = "https://${domain}";
        serviceConfig = {
          ExecStart = "${pkgs.beszel}/bin/beszel-hub serve --http 127.0.0.1:${toString hubPort}";
          DynamicUser = true;
          StateDirectory = "beszel-hub";
          WorkingDirectory = "/var/lib/beszel-hub";
          Restart = "on-failure";
          RestartSec = "5s";
        };
      };

      # 앱 레인과 같은 패턴: cloudflared → 도메인별 loopback Caddy vhost → 서비스.
      services.caddy.virtualHosts."http://${domain}:${toString caddyPort}" = {
        extraConfig = ''
          bind 127.0.0.1

          reverse_proxy 127.0.0.1:${toString hubPort}
        '';
      };

      services.cloudflared.tunnels."a19003a7-293f-4872-b8a5-1db544878f45".ingress.${domain} =
        "http://localhost:${toString caddyPort}";
    })

    (lib.mkIf (cfg.enable && cfg.agent.enable) {
      sops.secrets = {
        BESZEL_AGENT_KEY.mode = "0400";
        BESZEL_AGENT_TOKEN.mode = "0400";
      };

      systemd.services.beszel-agent = {
        description = "Beszel monitoring agent";
        wantedBy = [ "multi-user.target" ];
        requires = [ "sops-install-secrets.service" ];
        after = [
          "sops-install-secrets.service"
          "beszel-hub.service"
        ];
        environment = {
          LISTEN = "127.0.0.1:${toString agentPort}";
          HUB_URL = "http://127.0.0.1:${toString hubPort}";
          KEY_FILE = "%d/agent-key";
          TOKEN_FILE = "%d/agent-token";
          # Podman docker-호환 소켓 — 컨테이너별 지표.
          DOCKER_HOST = "unix:///run/docker.sock";
        };
        serviceConfig = {
          ExecStart = "${pkgs.beszel}/bin/beszel-agent";
          # 소켓 접근에 root 필요 (rootful podman). 파일시스템은 보호 유지.
          ProtectSystem = "strict";
          ProtectHome = true;
          StateDirectory = "beszel-agent";
          Environment = [ "DATA_DIR=/var/lib/beszel-agent" ];
          LoadCredential = [
            "agent-key:${config.sops.secrets.BESZEL_AGENT_KEY.path}"
            "agent-token:${config.sops.secrets.BESZEL_AGENT_TOKEN.path}"
          ];
          Restart = "on-failure";
          RestartSec = "5s";
        };
      };
    })
  ];
}
