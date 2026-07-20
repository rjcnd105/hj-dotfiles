{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.homelab.podmanDnsLifecycle;
  members = lib.sort builtins.lessThan (lib.unique cfg.members);
  topology = builtins.toFile "podman-dns-lifecycle-members" (
    lib.concatMapStrings (unit: "${unit}\n") members
  );
in
{
  options.homelab.podmanDnsLifecycle = {
    unit = lib.mkOption {
      type = lib.types.str;
      default = "podman-dns-lifecycle.service";
      readOnly = true;
      internal = true;
      description = "Systemd unit coordinating rootful Podman DNS workloads.";
    };

    members = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      internal = true;
      description = "Systemd services sharing the rootful Podman Aardvark DNS process.";
    };
  };

  config = lib.mkIf (cfg.members != [ ]) {
    assertions = [
      {
        assertion = config.virtualisation.podman.enable;
        message = "homelab.podmanDnsLifecycle requires virtualisation.podman.enable.";
      }
      {
        assertion = builtins.length cfg.members == builtins.length members;
        message = "homelab.podmanDnsLifecycle.members must have one owner per systemd unit.";
      }
      {
        assertion = builtins.all (lib.hasSuffix ".service") cfg.members;
        message = "homelab.podmanDnsLifecycle.members entries must be systemd service units.";
      }
    ];

    # Rootful Podman shares one Aardvark process across bridge networks. The
    # content-addressed topology trigger also handles first-time member adoption.
    systemd.services.${lib.removeSuffix ".service" cfg.unit} = {
      description = "Coordinate Podman DNS-backed containers across runtime upgrades";
      wantedBy = [ "multi-user.target" ];
      restartTriggers = [
        config.virtualisation.podman.package
        topology
      ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.coreutils}/bin/true";
        RemainAfterExit = true;
      };
    };
  };
}
