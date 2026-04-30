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

- `treefmt-nix` is the formatting boundary.
- Run `nix fmt` after Nix/TOML edits.
- Run `just check` or
  `nix flake check --all-systems --no-build --show-trace` after Nix changes.
- Do not add a second formatting system for Nix or TOML.
- Do not add CI checks that require homelab SSH, sudo, or live DNS.

## Homelab App Runtime

- App repos own app runtime intent through `devops/runtime-contract.nix`.
- App repos may provide `devops/homelab-admission.nix` as structured admission
  requests.
- `nix-dots` owns admission, host binding, registry auth, secrets, volumes,
  routes, Podman/Quadlet rendering, Caddy, Cloudflared, migrations, smoke checks,
  and `homelab-appctl`.
- Do not copy app-specific runtime shape from chat into `nix-dots` when the app
  repo can own a contract.
- Do not add app-specific homelab deploy scripts to app repos.
- OCI release manifests may exist for audit, but are not the deploy ABI.

## Homelab Deploy ABI

The host-side deploy interface is:

```sh
homelab-appctl list
homelab-appctl status <app> <channel>
homelab-appctl smoke <app> <channel>
homelab-appctl deploy <app> <channel> --dry-run
homelab-appctl deploy <app> <channel>
homelab-appctl rollback <app> <channel>
```

`homelab-appctl` reads generated metadata from:

```text
/etc/homelab-apps/<app>/<channel>.json
```

Do not make the app repo depend on this path. This path is a host adapter detail.

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
- Registry auto-update on services that own schema migrations.
- Secrets in `flake.nix`, app contracts, generated metadata, or docs.

## Sources

- [Homelab image deploy guide](../docs/guides/homelab-image-deploy-guide.md)
- [Release automation plan](../docs/plans/2026-04-30-001-feat-homelab-app-release-automation-plan.md)
