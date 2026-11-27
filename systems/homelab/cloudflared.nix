{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.homelab;
  hasPublicRoutes = cfg.publicRoutes != { };
  allReservedPorts = cfg.reservedLoopbackPorts ++ lib.optional hasPublicRoutes cfg.caddyPort;
  conflictingRouteDomains = builtins.filter (domain: builtins.hasAttr domain cfg.staticIngress) (
    builtins.attrNames cfg.publicRoutes
  );
  ingressRules =
    lib.optional cfg.cloudflared.sshIngress.enable {
      # SSH — 라우터 인바운드 포워딩 없이 원격 접속하는 경로.
      # 클라이언트는 `cloudflared access ssh` ProxyCommand로 접속하며
      # CF Access가 SSH 핸드셰이크 전에 인증을 요구한다.
      hostname = config.sops.placeholder.HOMELAB_SSH_HOSTNAME;
      service = "ssh://localhost:22";
    }
    ++ lib.mapAttrsToList (hostname: service: { inherit hostname service; }) cfg.staticIngress
    ++ lib.mapAttrsToList (hostname: _route: {
      inherit hostname;
      service = "http://localhost:${toString cfg.caddyPort}";
    }) cfg.publicRoutes
    ++ [
      { service = "http_status:404"; }
    ];
  cloudflaredConfig = {
    tunnel = config.sops.placeholder.CLOUDFLARED_TUNNEL_ID;
    credentials-file = config.sops.secrets."cloudflared-credentials".path;
    ingress = ingressRules;
  };
in
{
  options.homelab = {
    cloudflared = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable Cloudflare Tunnel daemon and sops-managed tunnel configuration.";
      };

      sshIngress.enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Expose loopback SSH (ssh://localhost:22) via sops-managed HOMELAB_SSH_HOSTNAME.";
      };
    };

    staticIngress = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Non-secret static cloudflared ingress mappings (hostname -> backend service URL).";
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

    users.users.cloudflared = lib.mkIf cfg.cloudflared.enable {
      isSystemUser = true;
      group = "cloudflared";
    };

    users.groups.cloudflared = lib.mkIf cfg.cloudflared.enable { };

    sops.secrets = lib.mkIf cfg.cloudflared.enable (
      {
        "cloudflared-credentials" = {
          format = "binary";
          sopsFile = ../../secrets/homelab/cloudflared.json;
          owner = "cloudflared";
          group = "cloudflared";
          mode = "0400";
          restartUnits = [ "homelab-cloudflared.service" ];
        };
        CLOUDFLARED_TUNNEL_ID.mode = "0400";
      }
      // lib.optionalAttrs cfg.cloudflared.sshIngress.enable {
        HOMELAB_SSH_HOSTNAME.mode = "0400";
      }
    );

    sops.templates."cloudflared-config.json" = lib.mkIf cfg.cloudflared.enable {
      content = builtins.toJSON cloudflaredConfig;
      owner = "cloudflared";
      group = "cloudflared";
      mode = "0400";
      restartUnits = [ "homelab-cloudflared.service" ];
    };

    # sops 템플릿으로 터널 UUID와 SSH 호스트명을 런타임에만 복호화한다.
    # wants: 다른 시크릿 변경으로 sops-install-secrets가 재실행될 때마다 터널이
    # 불필요하게 끊기지 않도록 하고, 실제 터널 설정/자격 변경은 restartUnits로 반영한다.
    systemd.services.homelab-cloudflared = lib.mkIf cfg.cloudflared.enable {
      description = "Cloudflare Tunnel for homelab ingress";
      wantedBy = [ "multi-user.target" ];
      wants = [
        "network.target"
        "network-online.target"
        "sops-install-secrets.service"
      ];
      after = [
        "network.target"
        "network-online.target"
        "sops-install-secrets.service"
      ];
      environment = {
        TUNNEL_EDGE_IP_VERSION = "4";
        TUNNEL_TRANSPORT_PROTOCOL = "auto";
      };
      serviceConfig = {
        Type = "simple";
        User = "cloudflared";
        Group = "cloudflared";
        ExecStart = "${lib.getExe pkgs.cloudflared} tunnel --config=${
          config.sops.templates."cloudflared-config.json".path
        } --no-autoupdate run";
        Restart = "on-failure";
        RestartSec = "5s";
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
      };
    };
  };
}
