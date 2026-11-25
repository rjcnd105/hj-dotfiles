{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.homelab.beszel;
  domain = "beszel.deopjib.cc";
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
      homelab.reservedLoopbackPorts = [ hubPort ];
      homelab.publicRoutes.${domain}.extraConfig = ''
        reverse_proxy 127.0.0.1:${toString hubPort}
      '';

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
    })

    (lib.mkIf (cfg.enable && cfg.agent.enable) {
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
          KEY_FILE = "%d/agent-key";
          DATA_DIR = "/var/lib/beszel-agent";
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
