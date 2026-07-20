---
title: Hindsight auto-consolidation backlog saturated homelab Postgres CPU
date: 2026-07-03
category: performance-issues
module: homelab-hindsight-runtime
problem_type: performance_issue
component: tooling
symptoms:
  - "Homelab CPU Tctl reached about 90C and fans stayed loud"
  - "A Hindsight Postgres backend used nearly one full CPU core for more than a day"
  - "Hindsight v0.8.4 still claimed consolidation tasks after upgrade"
  - "Worker logs showed consolidation using both reserved and shared worker capacity"
root_cause: config_error
resolution_type: config_change
severity: high
related_components:
  - hindsight
  - postgres
  - homelab
  - podman
  - quadlet
  - comin
tags: [hindsight, homelab, consolidation, postgres, worker-slots, nixos, comin, quadlet]
---

# Hindsight auto-consolidation backlog saturated homelab Postgres CPU

## Problem

The homelab was running hot because Hindsight consolidation work drove a
long-running PostgreSQL backend at nearly one full CPU core. Upgrading from
`ghcr.io/vectorize-io/hindsight:0.6.1-slim` to v0.8.4 was necessary, but not
sufficient: the local Nix runtime policy still let Hindsight's scheduler claim
consolidation backlog through shared worker capacity.

This was not purely an upstream Hindsight bug. Hindsight v0.8.4 included
relevant fixes, but the deployed host policy still combined auto-consolidation
with a shared worker slot in a way that let expensive backlog run again.

## Symptoms

- Live host process inspection showed a Hindsight PostgreSQL backend using
  about 99-100% CPU for roughly 1d22h.
- CPU `Tctl` was about 90C during the incident.
- The old application image was
  `ghcr.io/vectorize-io/hindsight:0.6.1-slim`.
- GitHub showed Hindsight v0.8.4 as latest. GHCR did not publish a semantic
  `0.8.4-slim` tag, so the host pinned the verified `latest-slim` digest whose
  OCI label reported `0.8.4-slim`.
- After v0.8.4 startup, the worker still claimed consolidation tasks and
  started a new PostgreSQL `SELECT` consuming about 90% CPU.
- Hindsight logs showed the policy mismatch:

```text
slots=2/2
reserved: [consolidation=2/1(avail=0)]
shared=1/1(avail=0)
my_active: consolidation:my(1), consolidation:::nix-dots(1)
```

The important detail is the distinction between a reserved slot and a shared
slot. `HINDSIGHT_API_WORKER_CONSOLIDATION_MAX_SLOTS=1` limited the explicit
consolidation reservation, but it did not prevent consolidation from using the
remaining shared capacity.

## What Didn't Work

- Image upgrade alone did not fix the workload. v0.8.4 removed or improved
  relevant upstream hotspots, including lazy reranker behavior, consolidation
  deadlock sorting, and migration performance, but it still allowed this host's
  backlog to be claimed.
- `pg_cancel_backend(...)` and `pg_terminate_backend(...)` returned `true`, but
  the operating-system PostgreSQL backend continued running until the stuck
  backend process was killed.
- The prior worker policy assumed `WORKER_MAX_SLOTS=2` and
  `WORKER_CONSOLIDATION_MAX_SLOTS=1` left the other slot effectively available
  for retain work. Hindsight's scheduler does not work that way: it claims from
  reserved pools first, then from a shared pool, and consolidation can use
  shared capacity if it remains after non-consolidation tasks.
- Session history search found no earlier direct fix for this exact Hindsight
  consolidation issue; related sessions only reinforced the repo pattern of
  making homelab runtime behavior declarative in Nix and verifying it through
  checks plus comin deployment (session history).

## Solution

Pin the verified v0.8.4 image digest, disable automatic consolidation
submission, and reserve the whole worker for retain work so no shared capacity
exists for consolidation.

```nix
# systems/homelab/hindsight-stack.nix
images = {
  # GHCR does not publish a semantic 0.8.4-slim tag; latest-slim's OCI
  # index digest is pinned here and its image label is 0.8.4-slim.
  hindsight = "ghcr.io/vectorize-io/hindsight:latest-slim@sha256:9873b311f77a3e25813cadd14ccb10d730583aeb9d2c6e2107350e00c7af12bf";
  db = "timescale/timescaledb-ha:pg18";
};
```

```nix
Environment=HINDSIGHT_API_ENABLE_AUTO_CONSOLIDATION=false
Environment=HINDSIGHT_API_DB_STATEMENT_TIMEOUT=120
Environment=HINDSIGHT_API_WORKER_ID=homelab
Environment=HINDSIGHT_API_WORKER_MAX_SLOTS=1
Environment=HINDSIGHT_API_WORKER_RETAIN_MAX_SLOTS=1
Environment=HINDSIGHT_API_WORKER_CONSOLIDATION_MAX_SLOTS=0
Environment=HINDSIGHT_API_RETAIN_MAX_CONCURRENT=1
Environment=HINDSIGHT_API_RETAIN_CHUNK_BATCH_SIZE=25
```

The slot invariant is:

- total worker slots: `1`
- retain reserved slots: `1`
- consolidation reserved slots: `0`
- shared slots: `0`

Add a flake check so later comin-deployed changes cannot silently reintroduce
the risky shape:

```nix
pkgs.runCommand "homelab-hindsight-runtime-invariants" { } ''
  stack=${./systems/homelab/hindsight-stack.nix}

  ${pkgs.gnugrep}/bin/grep -F 'hindsight = "ghcr.io/vectorize-io/hindsight:latest-slim@sha256:9873b311f77a3e25813cadd14ccb10d730583aeb9d2c6e2107350e00c7af12bf";' "$stack" >/dev/null
  ${pkgs.gnugrep}/bin/grep -F 'Environment=HINDSIGHT_API_DB_STATEMENT_TIMEOUT=120' "$stack" >/dev/null
  ${pkgs.gnugrep}/bin/grep -F 'Environment=HINDSIGHT_API_ENABLE_AUTO_CONSOLIDATION=false' "$stack" >/dev/null
  ${pkgs.gnugrep}/bin/grep -F 'Environment=HINDSIGHT_API_WORKER_MAX_SLOTS=1' "$stack" >/dev/null
  ${pkgs.gnugrep}/bin/grep -F 'Environment=HINDSIGHT_API_WORKER_RETAIN_MAX_SLOTS=1' "$stack" >/dev/null
  ${pkgs.gnugrep}/bin/grep -F 'Environment=HINDSIGHT_API_WORKER_CONSOLIDATION_MAX_SLOTS=0' "$stack" >/dev/null
  if ${pkgs.gnugrep}/bin/grep -F 'HINDSIGHT_API_LAZY_RERANKER' "$stack" >/dev/null; then
    echo 'Hindsight v0.8 removed HINDSIGHT_API_LAZY_RERANKER; keep reranker init on the upstream eager path' >&2
    exit 1
  fi

  touch "$out"
'';
```

## Why This Works

`HINDSIGHT_API_ENABLE_AUTO_CONSOLIDATION=false` stops retain-time and
maintenance-triggered consolidation submissions. That prevents the host from
creating fresh consolidation work while existing backlog is being contained.

`HINDSIGHT_API_WORKER_MAX_SLOTS=1` plus
`HINDSIGHT_API_WORKER_RETAIN_MAX_SLOTS=1` consumes the entire worker capacity
with a retain reservation. `HINDSIGHT_API_WORKER_CONSOLIDATION_MAX_SLOTS=0`
gives consolidation no reserved capacity. Because shared capacity is now also
zero, pending consolidation tasks can remain claimable but cannot be assigned to
this worker.

Post-deploy logs matched the intended invariant:

```text
slots=0/1
reserved: [retain=0/1(avail=1)]
shared=0/0(avail=0)
my_active: none
PENDING_BREAKDOWN consolidation: total=3 claimable=3
```

`pg_stat_activity` then reported no long-running active Hindsight query, the
Hindsight health endpoint stayed healthy, and CPU `Tctl` dropped to the low
40C range.

## Prevention

- Treat Hindsight worker slots as scheduler policy, not just concurrency
  tuning. If consolidation must not run on a host, both reserved consolidation
  capacity and shared capacity must be zero.
- Keep `HINDSIGHT_API_ENABLE_AUTO_CONSOLIDATION=false` unless the host is
  deliberately sized and scheduled for consolidation backlog.
- Keep the flake invariant check for the pinned image digest, statement
  timeout, auto-consolidation disablement, retain-only worker shape, and absence
  of the removed `HINDSIGHT_API_LAZY_RERANKER`.
- Before declaring a future Hindsight upgrade successful, verify all three
  layers: generated systemd unit environment, Hindsight worker claim logs, and
  PostgreSQL long-running activity.

Minimal live checks after deploy:

```sh
systemctl cat hindsight.service |
  rg 'HINDSIGHT_API_(ENABLE_AUTO_CONSOLIDATION|WORKER_MAX_SLOTS|WORKER_RETAIN_MAX_SLOTS|WORKER_CONSOLIDATION_MAX_SLOTS|DB_STATEMENT_TIMEOUT|WORKER_ID)'

journalctl -u hindsight.service --since '10 minutes ago' --no-pager |
  rg 'slots=|shared=|my_active|consolidation'

CONTAINER_HOST=unix:///run/podman/podman.sock \
  podman exec hindsight-db psql -U hindsight -d hindsight -c \
  "select count(*) from pg_stat_activity where now() - query_start > interval '5 minutes' and state = 'active';"
```

## Related Issues

- [`hindsight-recall-hook-silent-timeout-2026-04-21.md`](hindsight-recall-hook-silent-timeout-2026-04-21.md)
  covers recall latency from reranker/model-swap behavior, not background
  consolidation worker policy.
- [`hindsight-reranker-vulkan-acceleration-2026-04-19.md`](hindsight-reranker-vulkan-acceleration-2026-04-19.md)
  covers GPU acceleration for rerank latency, a separate Hindsight performance
  path.
- [`../database-issues/hindsight-recall-eval-on-switch-db-waits-2026-04-27.md`](../database-issues/hindsight-recall-eval-on-switch-db-waits-2026-04-27.md)
  is related because it captured Hindsight DB waits and worker contention, but
  it did not identify the auto-consolidation/shared-slot policy issue.
- [`../tooling-decisions/homelab-podman-quadlet-runtime-migration-2026-04-27.md`](../tooling-decisions/homelab-podman-quadlet-runtime-migration-2026-04-27.md)
  explains why the Hindsight runtime envelope is rendered through NixOS
  Podman/Quadlet and therefore must be kept declarative.
