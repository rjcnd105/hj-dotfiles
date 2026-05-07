# AGENTS.md

## Project Overview

This repository is the user's Nix dotfiles and homelab configuration. It manages
macOS through nix-darwin and the homelab through NixOS. Key surfaces are:

- `flake.nix` for host outputs, dev shells, checks, and formatter wiring.
- `systems/` for NixOS and nix-darwin system modules.
- `homes/` and `files/` for Home Manager and linked user configuration.
- `docs/guides/` and `docs/solutions/` for durable operational decisions.
  `docs/solutions/` is organized by category with YAML frontmatter such as
  `module`, `tags`, and `problem_type`, useful when implementing or debugging in
  documented areas.

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

## Technical Documentation Lookup

- For library/framework/API documentation, prefer Context7 MCP when the
  `context7` MCP server is visible in the current Codex tool list.
- If the MCP tool is not available, use `ctx7 library <name> <query>` to resolve
  the library ID, then `ctx7 docs <libraryId> <query>` before falling back to
  web search.
- Keep source-specific claims tied to the fetched docs, and cite the source URL
  when using external documentation in a final answer.

## Nix Analysis In Codex

`nixd` and `nil` are installed for editor use, and this repo's Zed/Cursor
settings prefer `nixd` where configured. Codex does not currently expose the
Claude `LSP` deferred tool or `claude-code-lsps` plugin surface in this repo.

For Codex sessions:

- Do not claim LSP-backed answers unless a live Codex LSP/MCP tool is actually
  visible in the current tool list.
- Use repo files plus `nix eval`, `nix flake check`, and `just check` as the
  authoritative Nix verification path.
- Use `nixd --version` only to verify the language server binary exists; it is
  not by itself an agent-callable code intelligence tool.
- Tree-sitter can be used as a Codex-native syntax/AST layer for `.nix` files
  when `tree-sitter-nix` is wired explicitly. It can support structural search,
  import/attribute extraction, and graph building, but it does not replace
  nixd's semantic evaluation, option typing, package completion, or cross-file
  Nixpkgs/module resolution.

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
sudo -n homelab-appctl deploy <app> <channel>
sudo -n homelab-appctl rollback <app> <channel>
```

`homelab-appctl` is a `nix-dots` homelab adapter, not a public deploy platform.
Portable app output is the OCI image plus documented runtime needs.
`deploy` and `rollback` are root operations with a narrow passwordless sudo
rule for the homelab operator user.

## Safety Rules

- Keep secrets out of Nix literals and app repos; use sops-backed host secrets.
- Do not expose app containers directly to the public internet; route through
  Caddy and Cloudflared.
- Do not enable `registry-auto` for services that own or run schema migrations.
- Manual migrations may have one-shot systemd units, but must not run during
  NixOS activation or background auto-update.
- Keep Hindsight special until its host-network and local AI dependencies are
  deliberately redesigned.

## graphify

This project has a graphify knowledge graph at graphify-out/.

Rules:
- Before answering architecture or codebase questions, read
  `graphify-out/GRAPH_REPORT.md` for god nodes and community structure when it
  exists.
- If `graphify-out/wiki/index.md` exists, navigate it instead of reading raw
  files.
- If `graphify-out/graph.json` or `GRAPH_REPORT.md` is missing, say the graph is
  not built yet and fall back to normal repo inspection.
- For cross-module "how does X relate to Y" questions, prefer
  `graphify query "<question>"`, `graphify path "<A>" "<B>"`, or
  `graphify explain "<concept>"` over grep. These traverse the graph's
  EXTRACTED and INFERRED edges instead of scanning files.
- After modifying code files in this session, run `graphify update .` to keep
  the graph current only when `graphify-out/graph.json` already exists.
