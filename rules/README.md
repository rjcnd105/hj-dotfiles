# Rule Index

These rules are the agent-facing operating guide for Nix, NixOS, and flakes in
this repository. Read the smallest matching rule file before editing code.

## Rule Files

- [Nix Language Rules](nix-language.md)
  - Quoted URLs, `let` over broad `rec`, avoiding top-level `with`,
    reproducible imports, source path hygiene, and nested attrset updates.
- [Flake Output Rules](flake-outputs.md)
  - Standard flake outputs, lock handling, git-tracked file behavior, flake
    checks, input policy, and examples of what not to do.
- [NixOS Module Rules](nixos-modules.md)
  - Declarative NixOS modules, typed options, submodules, package options,
    systemd service generation, activation scripts, and generated files.
- [NixOS Operations Rules](nixos-operations.md)
  - Execution context, option verification, rebuild safety, generations,
    rollback, installation, image building, and operational anti-patterns.
- [Repository Policy Rules](repo-policy.md)
  - `nix-dots`-specific layout, homelab app deployment boundary, app-owned
    contracts, `homelab-appctl`, and CI expectations.

## Precedence

1. Current user instruction.
2. Repository `AGENTS.md`.
3. The matching file in `rules/`.
4. Existing code patterns in this repo.
5. Official Nix, NixOS, nixpkgs, and nix.dev documentation.

When these disagree, prefer the narrower and more concrete rule. If a rule looks
stale, verify the current official docs before changing behavior.

## Baseline Commands

```sh
just check
just fmt
nix flake check --all-systems --no-build --show-trace
nix eval .#nixosConfigurations.homelab_hj.config.<path>
```

## Source Baseline

These rules were refreshed against current official documentation on
2026-04-30:

- Nix Reference Manual, latest `nix flake`.
- Nix Reference Manual, stable `nix flake check`.
- nix.dev Best practices.
- nix.dev Working with local files.
- NixOS Manual, Writing NixOS Modules.
- Nixpkgs Reference Manual.
- `michalzubkowicz/nixos-management-skill` for agent-oriented task routing and
  NixOS operations anti-pattern coverage.
