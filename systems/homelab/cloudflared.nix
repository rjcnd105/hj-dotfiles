{
  config,
  lib,
  ...
}:
let
  cfg = config.homelab;
  hasPublicRoutes = cfg.publicRoutes != { };
  allReservedPorts = cfg.reservedLoopbackPorts ++ lib.optional hasPublicRoutes cfg.caddyPort;
  staticIngress = {
    # SSH — 라우터 인바운드 포워딩 없이 원격 접속하는 유일한 경로.
    # 클라이언트는 `cloudflared access ssh` ProxyCommand로 접속하며
    # CF Access(이메일 OTP)가 SSH 핸드셰이크 전에 인증을 요구한다.
    "ssh.deopjib.cc" = "ssh://localhost:22";
  };
  conflictingRouteDomains = builtins.filter (domain: builtins.hasAttr domain staticIngress) (
    builtins.attrNames cfg.publicRoutes
  );
  stagedCloudflaredConfig = {
    tunnel = config.sops.placeholder.CLOUDFLARED_TUNNEL_ID;
    credentials-file = config.sops.secrets."cloudflared-credentials".path;
    ingress = [
      {
        hostname = config.sops.placeholder.HOMELAB_SSH_HOSTNAME;
        service = "ssh://localhost:22";
      }
    ]
    ++ lib.mapAttrsToList (hostname: _route: {
      inherit hostname;
      service = "http://localhost:${toString cfg.caddyPort}";
    }) cfg.publicRoutes
    ++ [
      { service = "http_status:404"; }
    ];
  };
in
{
  options.homelab = {
    cloudflared.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable Cloudflare Tunnel daemon and credentials secret.";
    };

    cloudflareTunnelId = lib.mkOption {
      type = lib.types.str;
      default = "a19003a7-293f-4872-b8a5-1db544878f45";
      description = "Cloudflare Tunnel UUID for homelab ingress.";
    };

    caddyPort = lib.mkOption {
      type = lib.types.port;
      default = 18099;
      description = "Single loopback port where Caddy routes all public homelab domains by Host header.";
    };

    reservedLoopbackPorts = lib.mkOption {
      type = lib.types.listOf lib.types.port;
      default = [ ];
      description = "Loopback TCP ports claimed by homelab services, asserted globally unique.";
    };

    publicRoutes = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options.extraConfig = lib.mkOption {
            type = lib.types.lines;
            description = "Caddy site directives for this domain (bind 127.0.0.1 is prepended automatically).";
          };
        }
      );
      default = { };
      description = "Public homelab HTTP domains routed through loopback Caddy and Cloudflare Tunnel.";
    };
  };

  config = {
    assertions = [
      {
        assertion = lib.unique allReservedPorts == allReservedPorts;
        message = "homelab.reservedLoopbackPorts (including homelab.caddyPort) must be globally unique: ${toString allReservedPorts}";
      }
      {
        assertion = conflictingRouteDomains == [ ];
        message = "homelab.publicRoutes must not collide with static cloudflared ingress domains: ${toString conflictingRouteDomains}";
      }
    ];

    services.caddy = lib.mkIf hasPublicRoutes {
      enable = true;
      virtualHosts = lib.mapAttrs' (
        domain: route:
        lib.nameValuePair "http://${domain}:${toString cfg.caddyPort}" {
          extraConfig = ''
            bind 127.0.0.1

            ${route.extraConfig}
          '';
        }
      ) cfg.publicRoutes;
    };

    services.cloudflared = lib.mkIf cfg.cloudflared.enable {
      enable = true;
      tunnels.${cfg.cloudflareTunnelId} = {
        credentialsFile = config.sops.secrets."cloudflared-credentials".path;
        default = "http_status:404";
        ingress =
          staticIngress
          // lib.mapAttrs (_domain: _route: "http://localhost:${toString cfg.caddyPort}") cfg.publicRoutes;
      };
    };

    systemd.services."cloudflared-tunnel-${cfg.cloudflareTunnelId}" = lib.mkIf cfg.cloudflared.enable {
      requires = [ "sops-install-secrets.service" ];
      after = [ "sops-install-secrets.service" ];
    };

    users.users.cloudflared = lib.mkIf cfg.cloudflared.enable {
      isSystemUser = true;
      group = "cloudflared";
    };

    users.groups.cloudflared = lib.mkIf cfg.cloudflared.enable { };

    sops.secrets = lib.mkIf cfg.cloudflared.enable {
      "cloudflared-credentials" = {
        format = "binary";
        sopsFile = ../../secrets/homelab/cloudflared.json;
        owner = "cloudflared";
        group = "cloudflared";
        mode = "0400";
      };
      CLOUDFLARED_TUNNEL_ID.mode = "0400";
      HOMELAB_SSH_HOSTNAME.mode = "0400";
    };

    # 1단계 컷오버 준비: 새 sops 시크릿·템플릿과 cloudflared 유저를 먼저 배포해
    # /run/secrets/rendered/cloudflared-config.json 생성을 호스트에서 확인한 뒤
    # 2단계에서 유닛을 전환한다.
    sops.templates."cloudflared-config.json" = lib.mkIf cfg.cloudflared.enable {
      content = builtins.toJSON stagedCloudflaredConfig;
      owner = "cloudflared";
      group = "cloudflared";
      mode = "0400";
    };
  };
}
