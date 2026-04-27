---
title: homelab Podman/Quadlet runtime migration with Docker compatibility
date: 2026-04-27
category: tooling-decisions
module: homelab
problem_type: tooling_decision
component: tooling
severity: medium
applies_when:
  - "NixOS homelab app containers need image hot-swap without nixos-rebuild"
  - "Docker CLI compatibility must be preserved while removing the Docker daemon"
  - "Existing Docker-backed oci-containers need a small Podman/Quadlet migration"
related_components:
  - hindsight
  - podman
  - quadlet
  - nixos
  - sops-nix
tags: [homelab, podman, quadlet, docker-compat, oci-containers, nixos, hindsight, hot-swap]
---

# homelab Podman/Quadlet runtime migration with Docker compatibility

## Context

The homelab originally ran Hindsight through NixOS `virtualisation.oci-containers` with the Docker backend. That made app image updates part of the NixOS container declaration shape: unit names were Docker-shaped (`docker-hindsight.service`, `docker-hindsight-db.service`) and routine app deploys tended to imply changing Nix config or accepting Docker as the app runtime boundary.

The desired boundary is different: NixOS owns the stable infrastructure envelope, while app images can be updated by registry pull plus systemd restart or Podman auto-update. This is especially relevant for future stacks such as deopjib, where pointer tags or digests may move independently from the homelab NixOS config.

## Guidance

Use NixOS Podman as the runtime and generate Quadlet files manually when the NixOS channel does not expose a native `virtualisation.quadlet` module.

```nix
virtualisation.podman = {
  enable = true;
  dockerCompat = true;
  dockerSocket.enable = true;
  defaultNetwork.settings.dns_enabled = true;
};

systemd.timers.podman-auto-update.wantedBy = [ "timers.target" ];
```

This removes the Docker daemon from the declarative runtime, but keeps Docker compatibility through Podman:

- `docker` command maps to `podman`
- `/run/docker.sock` maps to Podman's Docker-compatible socket
- users that need the socket belong to the `podman` group, not the `docker` group

For existing Docker-backed `oci-containers`, map each container to a Quadlet file under `/etc/containers/systemd/` via `environment.etc`:

```nix
environment.etc."containers/systemd/hindsight.container".text = ''
  [Unit]
  Description=Hindsight API container
  Requires=hindsight-db.service
  After=network-online.target hindsight-db.service llama-swap.service embed-prefix-proxy.service
  Wants=network-online.target

  [Container]
  ContainerName=hindsight
  Image=ghcr.io/vectorize-io/hindsight:0.5.2-slim
  Pull=missing
  LogDriver=journald
  EnvironmentFile=/run/secrets/rendered/services.env
  Network=host

  [Service]
  Restart=on-failure
  RestartSec=5s
  TimeoutStartSec=0
  TimeoutStopSec=120

  [Install]
  WantedBy=multi-user.target
'';
```

For stateful volumes, prefer continuity over a risky live data move during the runtime migration. Hindsight DB kept the existing Docker volume data in place, but made Podman own it through a Quadlet volume:

```nix
let
  legacyDbVolumePath = "/var/lib/docker/volumes/hindsight-db-data/_data";
in
{
  system.activationScripts.hindsightDbVolumePath = ''
    mkdir -p ${legacyDbVolumePath}
  '';

  environment.etc."containers/systemd/hindsight-db-data.volume".text = ''
    [Volume]
    VolumeName=hindsight-db-data
    Device=${legacyDbVolumePath}
    Type=none
    Options=bind
  '';
}
```

The path still contains `docker`, but the Docker daemon is not required. Treat that path as a compatibility bridge; move it later during a planned DB downtime if a cleaner storage path is worth the operational cost.

On macOS workspace, install Podman tools and provide CLI wrappers when users expect `docker` commands:

```nix
let
  dockerCompat = pkgs.writeShellScriptBin "docker" ''
    exec ${pkgs.podman}/bin/podman "$@"
  '';
  dockerComposeCompat = pkgs.writeShellScriptBin "docker-compose" ''
    exec ${pkgs.podman-compose}/bin/podman-compose "$@"
  '';
in
{
  home.packages = with pkgs; [
    podman
    podman-compose
    dockerCompat
    dockerComposeCompat
  ];
}
```

Do not set a static `DOCKER_HOST` in Home Manager for macOS unless the Podman machine socket path is also declaratively stable. CLI compatibility is reliable through the wrappers; API clients may still need the environment emitted by `podman machine start` or `podman machine inspect`.

## Why This Matters

This keeps the operational boundary clear:

- NixOS declares the durable host envelope: Podman runtime, socket compatibility, Quadlet files, systemd ordering, firewall, sops templates, memory hardening.
- App deploys can mutate image state without mutating Nix config: `podman pull` plus `systemctl restart <unit>`, or `AutoUpdate=registry` on future Quadlet units.
- Existing Docker-oriented runbooks keep working at the command level because `docker` is Podman-backed, while new runbooks can use `podman` explicitly.
- Hindsight's previous host-network fix remains intact. The app container still uses `Network=host`, Cloudflared/Caddy continue to reach `localhost:8888`, and the DB is still reachable through host `127.0.0.1:5432`.

The important review boundary is to avoid unrelated cleanup while migrating runtime ownership. In this migration, replacing `docker` group with `podman` was correct, but removing `linger = true` was not: homelab user systemd services may depend on linger to survive reboot without login. Keep that setting unless a separate user-service cleanup explicitly removes the need.

## When to Apply

- A NixOS host currently uses Docker-backed `virtualisation.oci-containers`, but app images need runtime hot-swap.
- The service already has stable systemd dependencies, sops environment files, host-network assumptions, or stateful volumes that must be preserved exactly.
- Docker CLI or Docker socket compatibility is still needed for existing habits, scripts, or tools, but Docker itself should stop being the container daemon.
- Future stacks should use image tags or digests that change outside Nix config while NixOS keeps the service envelope reproducible.

## Examples

### Hindsight unit mapping

| Docker-backed unit | Podman/Quadlet unit | Container name |
| --- | --- | --- |
| `docker-hindsight.service` | `hindsight.service` | `hindsight` |
| `docker-hindsight-db.service` | `hindsight-db.service` | `hindsight-db` |
| Docker named volume | `hindsight-db-data-volume.service` | `hindsight-db-data` |

Operational smoke checklist after deploy:

```bash
systemctl status hindsight-db.service
systemctl status hindsight.service
podman ps
podman logs hindsight
podman logs hindsight-db
curl -H 'Host: hindsight.deopjib.site' http://localhost:8888
```

Because Docker compatibility is enabled on homelab, `docker ps` and `docker logs hindsight` should also hit Podman. Prefer `podman` in new documentation so the runtime boundary stays obvious.

### Verification commands used during migration

```bash
nix eval .#nixosConfigurations.homelab_hj.config.virtualisation.podman.dockerCompat
nix eval .#nixosConfigurations.homelab_hj.config.virtualisation.podman.dockerSocket.enable
nix eval .#nixosConfigurations.homelab_hj.config.virtualisation.docker.enable
nix eval .#nixosConfigurations.homelab_hj.config.systemd.sockets.podman.socketConfig.Symlinks
nix eval .#nixosConfigurations.homelab_hj.config.users.users.hj.extraGroups
nix eval .#nixosConfigurations.homelab_hj.config.users.users.hj.linger
nix eval --raw '.#nixosConfigurations.homelab_hj.config.environment.etc."containers/systemd/hindsight.container".text'
nix eval --raw '.#nixosConfigurations.homelab_hj.config.environment.etc."containers/systemd/hindsight-db.container".text'
nix eval --raw '.#nixosConfigurations.homelab_hj.config.environment.etc."containers/systemd/hindsight-db-data.volume".text'
```

Expected high-level results:

- Podman Docker compatibility: `true`
- Podman Docker socket compatibility: `true`
- Docker daemon config: `false`
- Docker socket symlink: `[ "/run/docker.sock" ]`
- User groups include `podman`, not `docker`
- `linger = true`
- Quadlet text contains the expected image, container name, env file, volume, network, and systemd ordering

## Related

- [`../integration-issues/docker-host-access-host-network-2026-04-17.md`](../integration-issues/docker-host-access-host-network-2026-04-17.md) — prior Hindsight host-network decision. This migration preserves that behavior while changing the runtime from Docker to Podman.
- [`../developer-experience/claude-remote-control-nixos-systemd-user-service-2026-04-17.md`](../developer-experience/claude-remote-control-nixos-systemd-user-service-2026-04-17.md) — why `users.users.<name>.linger = true` matters for homelab user systemd services.
- `systems/homelab/hindsight-stack.nix` — concrete Quadlet mapping for Hindsight.
- `systems/homelab/default.nix` — Podman runtime and Docker compatibility settings.
- `homes/workspace/default.nix` — macOS workspace Podman packages and Docker CLI wrappers.
