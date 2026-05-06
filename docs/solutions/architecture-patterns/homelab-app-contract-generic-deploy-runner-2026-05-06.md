---
title: Homelab app contracts with a generic host deploy runner
date: 2026-05-06
category: architecture-patterns
module: homelab-app-runtime
problem_type: architecture_pattern
component: development_workflow
severity: medium
applies_when:
  - "App repos publish OCI images but should not know homelab internals"
  - "Routine dev deploys should not require a NixOS rebuild"
  - "Podman/Quadlet is the current renderer but k3s may replace it later"
related_components:
  - nix-dots
  - podman
  - quadlet
  - caddy
  - cloudflared
  - sops-nix
  - kubernetes
tags: [homelab, runtime-contract, podman, quadlet, app-deploy, release-automation, k3s]
---

# Homelab app contracts with a generic host deploy runner

## Context

The homelab needed a low-friction deploy path for development apps without
turning `nix-dots` into an app release platform. The pressure point was
Deopjib: its app repo can build and publish OCI images, but hard-coding
Deopjib-specific Quadlet, Caddy, secrets, migration, and release logic directly
in `nix-dots` would make every new app a custom host change.

The user also expects a later k3s/Flux migration. That makes the near-term
boundary more important: app intent should be expressed as data close to
Kubernetes primitives, while the current host renderer can stay Podman/Quadlet.

Session history showed the same boundary emerging earlier: a Deopjib dev deploy
worked best when the app repo owned `devops/runtime-contract.nix` and
`devops/homelab-admission.nix`, while `nix-dots` imported that contract and
owned the host envelope, generated units, ingress, and secrets (session
history). A separate Podman migration also established that NixOS should own the
stable runtime envelope while image updates happen through the container runtime
rather than through routine NixOS rebuilds (session history).

## Guidance

Use a three-layer model:

1. App repo owns the release and runtime intent.
2. `nix-dots` admits that intent onto a host and enforces policy.
3. A host-local generic command deploys admitted apps from generated metadata.

The app-owned contract should stay pure data. It can describe images, services,
ports, health paths, required secret names, routes, volumes, migrations, update
policy, and release channels. It should not import `nixpkgs`, read secrets,
read host state, run network calls, or know where the homelab stores generated
files.

The host binding should stay small and policy-shaped:

```nix
homelab.apps.my-app = {
  enable = true;
  contract = import "${inputs.my-app}/devops/runtime-contract.nix";

  host = {
    domain = "dev.example.test";
    loopbackPortBase = 18100;
    registryAuth = "ghcr-readonly";

    secretMap = {
      DATABASE_URL = "MY_APP_DEV_DATABASE_URL";
      SECRET_KEY_BASE = "MY_APP_DEV_SECRET_KEY_BASE";
    };
  };
};
```

Routine app release commands belong in app repos. For example,
`mise run deopjib:release-dev --minor` can create a PR, run CI, decide version
intent, publish OCI images, and move a channel pointer tag such as
`:dev-current`. It should not SSH into homelab or run an app-specific host
deploy script.

`nix-dots` should expose the host deploy surface generically:

```sh
homelab-appctl list
homelab-appctl status <app> <channel>
homelab-appctl smoke <app> <channel>
homelab-appctl deploy <app> <channel> --dry-run
homelab-appctl deploy <app> <channel>
homelab-appctl rollback <app> <channel>
```

`homelab-appctl` reads generated metadata under
`/etc/homelab-apps/<app>/<channel>.json`. That path is a host adapter detail,
not a public app ABI. The portable app output remains the OCI image plus the
documented runtime needs.

Do not make the optional OCI release manifest the deploy ABI. It is useful for
audit and provenance, but the host should deploy from admitted app metadata and
the app-owned runtime contract.

## Why This Matters

This keeps responsibilities narrow:

- App repos can move fast on release PRs, SemVer, CI, image publication, and
  channel tags.
- `nix-dots` keeps control of host admission, registry credentials, sops-backed
  secrets, persistent volumes, public ingress, Caddy, Cloudflared, Podman, and
  migration safety.
- Routine dev deploys do not require a NixOS rebuild once an app is admitted.
- Migration-owning services are protected from blind `registry-auto` updates.
- A later k3s renderer can consume the same app contract shape rather than
  reverse-engineering Podman-specific scripts.

The key design constraint is to avoid a false self-service surface. App repos
should be self-service for releases after admission, but not for host policy,
secrets, public domains, storage, or migration execution.

## When to Apply

- A new internal app needs to run on the homelab from an OCI image.
- An app repo wants one command to start a dev release workflow.
- The host already has an admitted app and routine deploys should be image tag
  movement plus `homelab-appctl deploy`.
- The current implementation is Podman/Quadlet, but the contract should remain
  portable enough for a future k3s/Flux renderer.

Do not apply this pattern to Hindsight yet without a separate redesign.
Hindsight has host-network and local AI dependencies that are deliberately
special in this repo.

## Examples

### Runtime contract release block

Keep release metadata declarative and host-relevant:

```nix
release = {
  versioning = "external";

  channels.dev = {
    tag = "dev-current";
    mode = "manual";
    strategy = "coordinated";
    smokePaths = [
      "/health"
      "/"
    ];
    migrate = "manual";
    rollback = "record-only";
  };
};
```

`versioning = "external"` is the important boundary. `nix-dots` does not infer
SemVer from app commits; app CI owns that.

### Host deploy sequence

The host-side deploy path should be predictable and metadata-driven:

```text
read generated metadata
pull/resolve service images
run manual migration unit if declared
restart rendered service units
smoke through Caddy using the public Host header
record before/after image state
```

`rollback = "record-only"` is intentionally conservative. Until image restore
and migration rollback are proven, rollback should report the prior image state
instead of pretending to be fully automatic.

### Anti-patterns

- Adding `systems/homelab/deopjib-stack.nix` by hand when the app repo can
  provide a runtime contract.
- Giving app CI broad SSH access to the homelab.
- Running migrations during NixOS activation.
- Enabling `registry-auto` on the service that owns schema migrations.
- Copying a chat snippet like `homelab.apps.deopjib = { ... }` between repos as
  the long-term interface.
- Introducing k3s only to avoid writing a small host admission binding.

## Related

- [`../tooling-decisions/homelab-podman-quadlet-runtime-migration-2026-04-27.md`](../tooling-decisions/homelab-podman-quadlet-runtime-migration-2026-04-27.md) — explains why Podman/Quadlet is the current homelab renderer and why image hot-swap should not require Docker or a NixOS rebuild.
- [`../../guides/homelab-image-deploy-guide.md`](../../guides/homelab-image-deploy-guide.md) — operator and agent guide for app-owned runtime contracts, admission, and host deploy commands.
- [`../../plans/2026-04-30-001-feat-homelab-app-release-automation-plan.md`](../../plans/2026-04-30-001-feat-homelab-app-release-automation-plan.md) — implementation plan for the generic release automation substrate.
- `systems/homelab/app-containers.nix` — current NixOS module that renders admitted app contracts, metadata, migration units, and `homelab-appctl`.
- `rules/repo-policy.md` — compact agent rules for preserving the app contract and host runtime boundary.
