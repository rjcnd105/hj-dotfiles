# NixOS Operations Rules

Use these rules before suggesting or running NixOS rebuild, deployment,
rollback, install, image-build, or live host verification commands.

## Execution Context First

Before suggesting commands, identify where they run:

| Setup | Editing machine | Rebuild/deploy machine | Rule |
|---|---|---|---|
| Local NixOS | NixOS host | Same host | `nixos-option`, `nixos-rebuild`, and `man configuration.nix` are local. |
| macOS to NixOS via GitOps | macOS | NixOS host pulls/switches | Use local `nix eval`; live checks require SSH or public endpoints. |
| macOS drives remote rebuild | macOS with Nix | NixOS target | Use `nixos-rebuild --target-host` only if that deployment mode is chosen. |
| CI deploy | CI runner | NixOS target | CI must validate with `nix flake check`; avoid interactive checks. |

If unclear, ask where configs are edited and where `nixos-rebuild` runs.

## Option Verification

- Do not suggest NixOS, Home Manager, or nix-darwin option names from memory
  alone when they are central to the change.
- Prefer repo-local `nix eval` against the exact flake when available.
- Use `search.nixos.org/options` or official manuals for options not present in
  the current repo.
- On a real NixOS host, `nixos-option <path>` and `man configuration.nix` are
  valid live references.
- Record version-sensitive option changes in the relevant guide or rule.

Examples:

```sh
nix eval .#nixosConfigurations.homelab_hj.config.services.caddy.enable
nix eval .#nixosConfigurations.homelab_hj.config.systemd.services.<name>
```

## Rebuild Safety

Prefer this safety ladder:

1. `nix eval` the exact generated option or file.
2. `nix flake check --all-systems --no-build --show-trace`.
3. Build or dry-activate when practical.
4. Use `nixos-rebuild test` for risky live changes.
5. Use `nixos-rebuild switch` only after the test path is acceptable.

For remote SSH/network/firewall changes, do not go straight to `switch` unless
there is an out-of-band recovery path.

Common commands:

```sh
nixos-rebuild build --flake .#homelab_hj
nixos-rebuild dry-activate --flake .#homelab_hj
nixos-rebuild test --flake .#homelab_hj
nixos-rebuild switch --flake .#homelab_hj
nixos-rebuild switch --rollback
nixos-rebuild list-generations
```

In this repo, direct rebuild commands are not the default local workflow for the
homelab. The host normally follows the GitOps/comin path; use live rebuilds only
when the user asks for them or when a runbook explicitly requires them.

## Generations and Rollback

- NixOS generations are the system rollback boundary.
- Keep enough boot entries to recover from bad generations.
- Do not delete generations as part of routine feature work.
- Treat `nix-collect-garbage -d` and generation deletion as destructive
  operations that need explicit user intent.

## Installation and Images

- Keep `hardware-configuration.nix` machine-specific and version-controlled.
- Do not manually edit generated hardware config unless the change is deliberate
  and documented.
- Set `system.stateVersion` once at install time and do not bump it as part of
  normal package or NixOS upgrades.
- If using disko, let disko own filesystem declarations; do not duplicate them
  manually.
- Prefer flake-visible image outputs for ISO, VM, or disk images.

## Operational Anti-Patterns

- `nix-env -i` for system packages. Use declarative package lists.
- Changing `system.stateVersion` to match the current NixOS release.
- Testing SSH/firewall changes with remote `switch` before `test`.
- Running migrations or deployments from activation scripts.
- Relying on unverified option names because they worked in an older release.
- Leaving `/boot` generation limits unbounded on systemd-boot hosts.

## Sources

- https://github.com/michalzubkowicz/nixos-management-skill
- https://raw.githubusercontent.com/michalzubkowicz/nixos-management-skill/main/nixos-managing/SKILL.md
- https://raw.githubusercontent.com/michalzubkowicz/nixos-management-skill/main/nixos-managing/vm-management.md
- https://raw.githubusercontent.com/michalzubkowicz/nixos-management-skill/main/nixos-managing/installation.md
- https://raw.githubusercontent.com/michalzubkowicz/nixos-management-skill/main/nixos-managing/anti-patterns.md
