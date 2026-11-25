# Repository Policy Rules

Use these rules for `nix-dots`-specific decisions that are stricter than generic
Nix guidance.

## Repo Layout

- `systems/` owns host-level NixOS and nix-darwin modules.
- `homes/` owns Home Manager modules.
- `files/` owns linked user configuration files.
- `docs/guides/` owns durable operator and agent guides.
- `docs/plans/` owns reviewed implementation plans.
- `rules/` owns compact agent rules and anti-patterns.

## Formatting and Checks

Formatting and local check commands live in `AGENTS.md` (`Core Workflow`).
Do not add a second formatting system for Nix or TOML, and do not add CI checks
that require homelab SSH, sudo, or live DNS.

## Homelab App Runtime

- App repos own app runtime intent through `devops/runtime-contract.nix`
  (`deopjib/devops/` in the `my-app` monorepo).
- App repos may provide `devops/homelab-admission.nix` as structured admission
  requests.
- `nix-dots` owns admission, host binding, secrets, volumes,
  routes (`homelab.publicRoutes`), Podman/Quadlet rendering, Caddy, Cloudflared,
  migrations, smoke checks, and `homelab-appctl`.
- Do not copy app-specific runtime shape from chat into `nix-dots` when the app
  repo can own a contract.
- Do not add app-specific homelab deploy scripts to app repos.
- Services deploy exact image digests from a v2 app release manifest.
  `nix-dots` checks schema version `2`, app, target, target pattern, and image
  names before any host mutation. App contract changes normally reach the host
  through the approved `Admit Homelab App` workflow.

## Homelab Deploy ABI

Run `homelab-appctl --help` for the authoritative CLI interface (`list`,
`status`, `logs`, `smoke`, `deploy`). `homelab-appctl` reads generated metadata
from `/etc/homelab-apps/<app>/<channel>.json` (host adapter detail; app repos
must not depend on this path).

`deploy` requires root because it writes deploy records and controls system
services. The runner's passwordless sudo rule grants only `homelab-appctl deploy *`,
and the operator user holds `homelab-appctl *` through `systems/homelab/operator.nix`.
A rollback is another deploy of a known-good target; restoring an older contract
first requires a signed commit on `main` that reverts the pinned app input, then
`comin` activation, because `Admit Homelab App` refuses backward moves.

`deploy` pulls exact digests, runs any declared migration by exact digest before
moving `-current` tags, restarts release services once, runs loopback smoke
checks against Caddy, and writes `summary.json` plus `metadata.json`. No-op
matching semantics live in `packages/homelab-appctl/deploy.go` and its tests.

External app repos request dev deploys through `.github/workflows/request-homelab-deploy.yml`, which
dispatches `.github/workflows/deploy-homelab-app.yml` or
`.github/workflows/admit-homelab-app.yml`. Prod promotions dispatch
`deploy-homelab-app.yml` directly. Those workflows must stay host-owned and
input-validated, and host mutation runs only on the homelab runner. Do
not put SSH, systemd, Caddy, secret, migration, or direct `homelab-appctl`
implementation details in app repos.

## Kubernetes Migration Boundary

- Podman/Quadlet is the current renderer.
- Keep app contracts close to Kubernetes primitives: image, env, secrets, port,
  route, volume, health, migration, release channel.
- Do not introduce k3s only to move app-specific settings out of `nix-dots`.
- Revisit k3s when app count, rollout needs, Jobs, service discovery, or Flux
  automation justify a control plane.

## Anti-Patterns

- Broad `nix flake update` during an app admission change.
- Direct edits to generated Quadlet files.
- App-specific deployment code in app repos that knows homelab internals.
- NixOS activation scripts that run migrations or deployments.
- Secrets in `flake.nix`, app contracts, generated metadata, or docs.

## Sources

- [Homelab image deploy guide](../docs/guides/homelab-image-deploy-guide.md)
- [Release automation plan](../docs/plans/2026-04-30-001-feat-homelab-app-release-automation-plan.md)
