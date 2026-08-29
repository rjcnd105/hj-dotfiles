# Beszel 모니터링 — hub·agent 모두 nixpkgs 네이티브 (platform-v2 Phase 4).
# 공개 노출은 Caddy(loopback) → cloudflared → Cloudflare Access 게이트 경유만 허용.
#
# 에이전트는 순수 listen 모드다: 허브가 KEY(공개키)로 127.0.0.1:45876에 SSH 접속해
# 지표를 가져간다. UI의 Add System에서 host/port로 시스템을 등록하면 된다.
#
# 2단계 활성화:
#   1. hub만 배포 → 사용자가 UI에서 관리자 계정 생성 + Add System(호스트 127.0.0.1,
#      포트 45876)으로 등록. 다이얼로그의 공개키가 BESZEL_AGENT_KEY와 일치해야 한다.
#   2. KEY를 sops(BESZEL_AGENT_KEY)에 추가 후 agent.enable
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
    agent.enable = lib.mkEnableOption "Beszel agent (requires BESZEL_AGENT_KEY sops secret)";
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
      # listen 모드는 허브의 공개키(KEY)만 있으면 된다. TOKEN은 에이전트→허브
      # WebSocket 등록(제거된 HUB_URL 경로)에서만 쓰였으므로 더는 렌더하지 않는다.
      sops.secrets.BESZEL_AGENT_KEY.mode = "0400";

      systemd.services.beszel-agent = {
        description = "Beszel monitoring agent";
        wantedBy = [ "multi-user.target" ];
        requires = [ "sops-install-secrets.service" ];
        after = [
          "sops-install-secrets.service"
          "beszel-hub.service"
        ];
        environment = {
          # 순수 listen 모드: 허브가 KEY(공개키)로 이 포트에 SSH 접속해 지표를 가져간다.
          # HUB_URL(에이전트→허브 WebSocket)을 함께 두면 에이전트가 별도로 등록을
          # 시도하는데, 그 인증 토큰은 허브 DB의 fingerprint에만 존재해 Nix가 소유하지
          # 못한다(불일치 시 10초마다 401). 같은 호스트이므로 SSH 경로 하나로 충분하다.
          LISTEN = "127.0.0.1:${toString agentPort}";
          # %d = LoadCredential 디렉토리. secret 값이 유닛 파일에 남지 않는다.
          KEY_FILE = "%d/agent-key";
          DATA_DIR = "/var/lib/beszel-agent";
          # Podman docker-호환 소켓 — 컨테이너별 지표.
          DOCKER_HOST = "unix:///run/docker.sock";
        };
        serviceConfig = {
          ExecStart = "${pkgs.beszel}/bin/beszel-agent";
          # 소켓 접근에 root 필요 (rootful podman). 파일시스템은 보호 유지.
          ProtectSystem = "strict";
          ProtectHome = true;
          StateDirectory = "beszel-agent";
          LoadCredential = [
            "agent-key:${config.sops.secrets.BESZEL_AGENT_KEY.path}"
          ];
          Restart = "on-failure";
          RestartSec = "5s";
        };
      };
    })
  ];
}
