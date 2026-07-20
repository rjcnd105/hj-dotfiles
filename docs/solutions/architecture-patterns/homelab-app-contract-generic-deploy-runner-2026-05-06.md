---
title: Homelab app contracts with a generic host deploy runner
date: 2026-05-06
last_verified: 2026-07-20
category: architecture-patterns
module: homelab-app-runtime
problem_type: architecture_pattern
component: development_workflow
severity: medium
applies_when:
  - "App repositories publish OCI images but should not know homelab internals"
  - "Routine image releases should not require a NixOS rebuild"
  - "A coordinated release contains more than one application image"
related_components:
  - nix-dots
  - podman
  - quadlet
  - systemd
  - caddy
  - cloudflared
  - sops-nix
tags: [homelab, runtime-contract, release-manifest, exact-digest, podman, quadlet, app-deploy]
---

# Homelab app contracts with a generic host deploy runner

## Problem

The first generic runner treated mutable Quadlet image units as the deploy
authority and restarted those units before restarting the app services. A
coordinated backend/web release therefore had two activation paths. On Deopjib,
the database and backend could also start without an explicit readiness edge,
causing transient DNS and PostgreSQL startup failures before a later retry
passed.

An optional release manifest did not solve this. A release containing two image
digests needs one immutable identity; reconstructing it from mutable channel
tags makes the result timing-dependent.

## Decision

Keep two authorities with a narrow join:

- the app repository owns release target, exact application image digests, and
  runtime intent;
- `nix-dots` owns admission, the pinned app revision, secrets, network,
  storage, ingress, Quadlet/systemd rendering, and host activation.

The join is the SHA-256 set for the runtime contract, homelab admission,
manifest schema, and manifest generator. App CI writes all four into the release
manifest. NixOS independently writes the pinned values into generated app
metadata. `homelab-appctl` rejects a release when any differs.

For `manual` services:

- the release manifest is the immutable image identity;
- Quadlet uses the channel reference with `Pull=never`;
- no `.image` unit is rendered;
- `homelab-appctl` pulls `name@digest`, moves the local channel tag, migrates,
  and restarts all release-managed services once.

For `pinned-digest` services:

- the contract contains the complete `name:tag@sha256:...` reference;
- the normal declarative Quadlet image unit remains;
- app releases do not restart that service.

Service graph facts stay in the app contract. `dependsOn` becomes native
systemd `Requires`/`After`; `readiness` becomes Quadlet health settings and
`Notify=healthy`. Each channel also admits an explicit target pattern, so a prod
channel can reject dev snapshot targets before mutation. This replaces retry
sleeps and host-specific scripts.

## Deploy Transaction

```text
release target
  -> download manifest
  -> validate app, target, deployment source hashes, image names, exact digests
  -> acquire app/channel lock and publish in-progress record
  -> snapshot local image ids
  -> pull exact application digests
  -> move local channel tags
  -> run migration once
  -> restart release-managed units once as one systemd transaction
  -> smoke declared paths once
  -> write deploy record
```

A successful target is a no-op only when the latest record also contains
byte-identical admitted metadata. That prevents a contract change from being
hidden behind an old release id.

There is no rollback subcommand. Rollback is a deploy of a known-good release
target through the same path. If that target belongs to an older deployment
contract, first revert the pinned app input through PR/comin. Database migrations
remain an explicit recovery concern.

## NixOS Integration

The app repository exports:

```text
devops/runtime-contract.nix
devops/homelab-admission.nix
```

`nix-dots` pins the app repository as a flake input and imports only the
admission request from `systems/homelab/app-admissions.nix`. The typed
`homelab.apps` module adds the allowed HTTPS release origin, validates, and
renders it. Host-specific values do not go
in `systems/homelab/default.nix`, and no activation shell script performs app
deployment.

Routine image releases do not move the flake input. A contract change does:

1. app release is published but automatic host dispatch stops;
2. a `nix-dots` PR updates only the app input and validates generated output;
3. comin activates merged NixOS configuration;
4. the same release target is dispatched and now passes source-hash admission.

For the first strict-manifest cutover, that app release must reuse the currently
known-good backend/web digest pair. After comin activation, dry-run and deploy
that same target first so the new controller has a compatible `ok` rollback
baseline before any later image release.

This keeps NixOS declarative while avoiding a NixOS rebuild for every app image
release.

## Verification

Local macOS validation evaluates all outputs without pretending to build Linux:

```sh
nix flake check --all-systems --no-build --show-trace --no-write-lock-file \
  --override-input deopjibRuntime path:/absolute/path/to/app
```

Linux CI additionally runs:

- an app-generator-produced manifest, negative admission cases, and a generated
  `homelab-appctl deploy --dry-run`;
- a stubbed full deploy transaction covering exact pulls/tags, migration,
  combined restart, no-op, recovery failure, and concurrent calls;
- Quadlet lifecycle assertions for direct release refs, `Pull=never`, native DB
  readiness, and backend-to-DB ordering;
- an assertion that only one release-service restart command exists and no
  image unit is restarted.

Host verification after activation must confirm:

```sh
homelab-appctl deploy deopjib dev --target <release-id> --dry-run
sudo -n homelab-appctl deploy deopjib dev --target <release-id>
systemctl show deopjib-dev-db.service deopjib-dev-backend.service deopjib-dev-web.service \
  -p ActiveState -p SubState -p NRestarts
homelab-appctl smoke deopjib dev
```

The deploy log should contain exact digest pulls, one migration, one combined
backend/web restart, and one smoke pass. It must not restart PostgreSQL.

## Rejected Alternatives

- Per-app host scripts duplicate admission, sudo, secret, migration, and smoke
  policy.
- Mutable channel tags cannot identify a coordinated multi-image release.
- A NixOS rebuild per image release couples app cadence to host configuration.
- Kubernetes, Flux, Nomad, or a separate app catalog add a controller before
  the current single-host requirement needs one.

Revisit a controller when multiple apps require continuous reconciliation,
rollout strategies, multi-host scheduling, or shared cluster primitives that
make the controller smaller than this runner.

## References

- `systems/homelab/app-containers.nix`
- `systems/homelab/app-admissions.nix`
- `.github/workflows/deploy-homelab-app.yml`
- `docs/guides/homelab-image-deploy-guide.md`
