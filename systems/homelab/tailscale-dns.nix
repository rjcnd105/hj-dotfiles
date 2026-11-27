{
  config,
  lib,
  ...
}:
let
  cfg = config.homelab.tailscaleDns;
  domains = lib.sort builtins.lessThan (builtins.attrNames cfg.records);
in
{
  options.homelab.tailscaleDns = {
    enable = lib.mkEnableOption "Tailscale Split DNS responder via dnsmasq";

    interface = lib.mkOption {
      type = lib.types.str;
      default = "tailscale0";
      description = "Network interface on which dnsmasq serves Split DNS queries.";
    };

    records = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Map of domain names to IPv4 addresses answered over Tailscale Split DNS.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.services.tailscale.enable;
        message = "homelab.tailscaleDns requires services.tailscale.enable.";
      }
      {
        assertion = cfg.records != { };
        message = "homelab.tailscaleDns.records must define at least one domain record.";
      }
    ];

    services.dnsmasq = {
      enable = true;
      # 기본값이 true라서 끄지 않으면 homelab 자체 /etc/resolv.conf가 dnsmasq로 덮어써진다.
      resolveLocalQueries = false;
      settings = {
        # tailscale0에만 동적 바인딩해 부팅 순서 문제와 podman aardvark-dns(10.90.x.1:53) 충돌을 피한다.
        # dnsmasq는 interface= 사용 시 loopback도 자동 추가하므로 except-interface=lo를 명시한다.
        interface = cfg.interface;
        except-interface = "lo";
        bind-dynamic = true;
        no-resolv = true;
        no-hosts = true;

        # dnsmasq 2.86+에서 address=만 쓰면 AAAA/HTTPS(type 65) 질의가 upstream으로 넘어가
        # NXDOMAIN이 돌아오고 iOS Safari가 간헐 실패한다. local=을 함께 넣어 NODATA로 응답한다.
        local = map (domain: "/${domain}/") domains;
        address = map (domain: "/${domain}/${cfg.records.${domain}}") domains;
      };
    };

    networking.firewall.interfaces.${cfg.interface} = {
      allowedUDPPorts = [ 53 ];
      allowedTCPPorts = [ 53 ];
    };
  };
}
