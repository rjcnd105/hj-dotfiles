---
title: treefmt Taplo check fails on unformatted Codex notify array
date: 2026-06-10
category: build-errors
module: nix-dots formatter checks
problem_type: build_error
component: tooling
symptoms:
  - "`checks.x86_64-linux.formatting` fails in CI with `treefmt-check.drv` exit code 1"
  - "`treefmt` reports `files/workspace/.codex/config.toml` as the only changed file"
  - "CI diff rewrites the `notify` array from one line to Taplo's multi-line format"
root_cause: config_error
resolution_type: config_change
severity: medium
tags: [treefmt, taplo, codex, toml, ci, formatting, jj]
---

# treefmt Taplo check fails on unformatted Codex notify array

## Problem

The `main` branch CI failed on `checks.x86_64-linux.formatting` after a Codex
configuration change. The failing derivation did not expose a Nix evaluation or
dependency issue; it showed that `treefmt` would rewrite one TOML file.

## Symptoms

- CI failed building `treefmt-check.drv`.
- The log showed `treefmt v2.5.0` traversed the repo, processed 56 files, and
  changed exactly one file.
- The only diff was `files/workspace/.codex/config.toml`, where `notify` was
  reformatted from a one-line array to a multi-line array.

## What Didn't Work

- Treating the dirty local working copy as the fix scope would have mixed the
  CI repair with unrelated in-progress changes. At the time, the working copy
  also contained Codex MCP config edits, Zed settings, `flake.lock`, and
  homelab thermal alert work.
- Running broader cleanup would have obscured the actual CI failure. The CI log
  already identified a single formatter-owned diff.

## Solution

Apply the formatter output exactly where CI reported it:

```toml
notify = [
  "/Users/hj/.codex/computer-use/Codex Computer Use.app/Contents/SharedSupport/SkyComputerUseClient.app/Contents/MacOS/SkyComputerUseClient",
  "turn-ended",
]
```

Keep the repair isolated from unrelated dirty work:

```sh
jj new main
nix fmt -- files/workspace/.codex/config.toml
nix flake check --all-systems --no-build --show-trace
nix build .#checks.aarch64-darwin.formatting --show-trace
jj commit -m "style(codex): format notification config"
jj bookmark move main --to @-
jj git push --remote origin --bookmark main
```

After pushing, rebase the pre-existing dirty change onto the new `main` so the
operator's unfinished work remains intact:

```sh
jj rebase -r <dirty-change> -d main
jj edit <dirty-change>
```

## Why This Works

`flake.nix` wires `treefmt-nix` as the repo formatter/check boundary and enables
Taplo for TOML files. The CI formatting check builds
`treefmtEval.${system}.config.build.check self`, so any file that Taplo would
rewrite causes the check derivation to fail.

The `notify` value was valid TOML, but it was not in the canonical Taplo output
for this long array. Formatting the array removes the only generated diff, so
the check has no changes to report.

## Prevention

- Run `nix fmt -- <path>` after editing TOML or Nix files in this repo.
- When CI reports a treefmt diff, apply the formatter output exactly before
  looking for deeper build causes.
- In a dirty JJ working copy, create an isolated change from `main` for CI-only
  fixes and rebase the existing dirty change afterward.
- Verify formatter fixes with at least:

```sh
nix flake check --all-systems --no-build --show-trace
```

For the exact formatter derivation on the local system, also run:

```sh
nix build .#checks.$(nix eval --raw --impure --expr builtins.currentSystem).formatting --show-trace
```

## Related Issues

- None recorded.
