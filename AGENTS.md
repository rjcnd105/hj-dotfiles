# AGENTS.md

## Project Overview

This repository is the user's Nix dotfiles and homelab configuration. It manages
macOS through nix-darwin and the homelab through NixOS. Key surfaces are:

- `flake.nix` for host outputs, dev shells, checks, and formatter wiring.
- `systems/` for NixOS and nix-darwin system modules.
- `homes/` and `files/` for Home Manager and linked user configuration.
- `docs/guides/` and `docs/solutions/` for durable operational decisions.

## Core Workflow

- Prefer `jj` commands because this repo has `.jj`.
- Preserve unrelated dirty work. Do not revert user edits.
- Use `rg` / `rg --files` for search.
- Read [rules/README.md](rules/README.md) before making non-trivial Nix,
  NixOS, flake, or homelab runtime changes.
- For NixOS live operations, first identify the execution context: local NixOS,
  macOS editing with GitOps, remote rebuild, or CI. See
  [rules/nixos-operations.md](rules/nixos-operations.md).
- Run `just check` or `nix flake check --all-systems --no-build --show-trace`
  after Nix changes.
- Run `nix fmt` after editing Nix or TOML files.
- Do not run broad lockfile updates unless the user explicitly asks for them.

## Declarative Nix Rules

- Prefer declarative Nix modules and options over imperative host scripts.
- Do not hand-edit generated runtime files under `/etc`, `/run`, or
  `/etc/containers/systemd`; change the Nix module or app contract that renders
  them.
- Keep runtime shape as pure data where possible. App contracts should describe
  images, env, secrets, ports, routes, volumes, health, migrations, and release
  channels without reading secrets or host state.
- Use activation scripts only for host reconciliation that cannot be represented
  as normal NixOS options, and keep them idempotent.
- If a deploy action must be imperative, expose it as a generic Nix-provided
  command such as `homelab-appctl`, backed by generated metadata.
- Validate generated output with `nix eval` before relying on live host state.

## Flake Practices

- Keep important workflows exposed as flake outputs: `nixosConfigurations`,
  `darwinConfigurations`, `checks`, `formatter`, `devShells`, and templates.
- Prefer evaluating concrete outputs before changing structure, for example
  `nix eval .#nixosConfigurations.homelab_hj.config.<path>`.
- Keep host composition in Nix modules under `systems/` and user composition in
  Home Manager modules under `homes/`; avoid putting host logic in ad hoc shell
  scripts.
- Add checks that are cheap, deterministic, and build-light. Prefer eval and
  formatting checks over remote SSH, sudo, or live-host checks in CI.
- Do not update `flake.lock` broadly for unrelated work. If an input must move,
  update only that input and report why.
- Keep app repos as flake inputs only when `nix-dots` must import app-owned
  contracts. Do not copy app runtime details into this repo.
- Avoid new flake frameworks or major structure rewrites unless they remove real
  duplication in this repo.
- Preserve `treefmt-nix` as the formatting boundary; do not add parallel
  formatting mechanisms for Nix/TOML.

## Common Commands

```sh
just check
just fmt
just eval_hj-homelab
nix eval .#nixosConfigurations.homelab_hj.config.networking.hostName
nix flake check --all-systems --no-build --show-trace
```

## Homelab App Deployments

Read `docs/guides/homelab-image-deploy-guide.md` before changing homelab app
runtime, admission, release, or deploy behavior.

Responsibility boundary:

- App repos own OCI image build/publish, SemVer/release decisions, release PRs,
  channel tags such as `dev-current`, and app-owned `devops/runtime-contract.nix`.
- `nix-dots` owns host admission, registry auth, sops secrets, volumes, Caddy,
  Cloudflared, Podman/Quadlet rendering, migrations, smoke checks, and
  `homelab-appctl`.
- Do not add app-specific homelab deploy runners to app repos.
- Treat OCI release manifests as optional provenance/audit artifacts only, not
  the homelab deploy ABI.

Current host-side deploy ABI:

```sh
homelab-appctl list
homelab-appctl status <app> <channel>
homelab-appctl smoke <app> <channel>
homelab-appctl deploy <app> <channel> --dry-run
homelab-appctl deploy <app> <channel>
homelab-appctl rollback <app> <channel>
```

`homelab-appctl` is a `nix-dots` homelab adapter, not a public deploy platform.
Portable app output is the OCI image plus documented runtime needs.

## Safety Rules

- Keep secrets out of Nix literals and app repos; use sops-backed host secrets.
- Do not expose app containers directly to the public internet; route through
  Caddy and Cloudflared.
- Do not enable `registry-auto` for services that own or run schema migrations.
- Manual migrations may have one-shot systemd units, but must not run during
  NixOS activation or background auto-update.
- Keep Hindsight special until its host-network and local AI dependencies are
  deliberately redesigned.
