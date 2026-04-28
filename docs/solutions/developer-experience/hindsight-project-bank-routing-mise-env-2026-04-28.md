---
title: Hindsight project bank routing with mise env
date: 2026-04-28
category: developer-experience
module: hindsight-memory-plugin
problem_type: developer_experience
component: tooling
severity: low
applies_when:
  - "A project should use one Hindsight bank from nested working directories"
  - "Hindsight dynamicBankId maps the project to the current cwd basename"
  - "mise env is the project-local source for Codex/Hindsight environment variables"
tags: [hindsight, codex, mise, bank-id, memory-routing, developer-experience]
---

# Hindsight project bank routing with mise env

## Context

Hindsight's Codex integration can derive a bank dynamically, but the current
`dynamicBankId` path builds the `project` segment from `os.path.basename(cwd)`.
That means work inside `A/B/C` routes to `C`, even when the intended memory
boundary is the parent project `A`.

For these repos, the desired behavior is a stable project bank regardless of
which nested directory Codex starts from:

- `/Users/hj/dot/nix-dots` -> `nix-dots`
- `/Users/hj/study_ex/my-backend/deopjib` and nested `backend/` -> `deopjib`
- `/Users/hj/work/gm/gentle-renewal` -> `gentle-renewal`

## Guidance

Use project-local `mise.toml` or `.mise.local.toml` as the owner of the bank
boundary. Keep `dynamicBankId` off and set an explicit `HINDSIGHT_BANK_ID` at
the ancestor directory that should own the memory bank.

Use string values for boolean-looking env vars:

```toml
[env]
HINDSIGHT_DYNAMIC_BANK_ID = "false"
HINDSIGHT_BANK_ID = "deopjib"
```

Do not use TOML boolean `false` for `HINDSIGHT_DYNAMIC_BANK_ID` when the
Hindsight plugin reads it through `os.environ`. In this environment, `mise x`
did not export the boolean value as an env var, while the string `"false"`
produced the expected runtime value.

## Why This Matters

If `dynamicBankId` remains enabled, `HINDSIGHT_BANK_ID` is ignored by
`derive_bank_id()`. If it is disabled but no project-local bank is set, the
session falls back to whatever global `HINDSIGHT_BANK_ID` was already present,
which can mix unrelated memories from multiple repos.

Project-local static bank ids preserve the desired memory boundary without
patching the plugin's bank derivation logic.

## When to Apply

- When a parent project owns several nested working directories.
- When `dynamicBankId` chooses the leaf directory but the memory bank should be
  the parent project.
- When unrelated Hindsight memories are injected because several projects share
  a global bank.

## Examples

`nix-dots` root:

```toml
[env]
HINDSIGHT_DYNAMIC_BANK_ID = "false"
HINDSIGHT_BANK_ID = "nix-dots"
```

`deopjib` root, inherited by `backend/`, `client/`, and `devops/` unless a
child config overrides it:

```toml
[env]
HINDSIGHT_DYNAMIC_BANK_ID = "false"
HINDSIGHT_BANK_ID = "deopjib"
```

`gentle-renewal` local config:

```toml
[env]
HINDSIGHT_DYNAMIC_BANK_ID = "false"
HINDSIGHT_BANK_ID = "gentle-renewal"
```

Verify with `mise x` from the project and from representative nested
directories:

```bash
mise x -- python3 -c 'import os; print(os.environ.get("HINDSIGHT_BANK_ID")); print(os.environ.get("HINDSIGHT_DYNAMIC_BANK_ID"))'
```

Existing Codex sessions may keep stale environment variables. Restart the shell
or Codex session before judging active Hindsight behavior.

## Related

- `docs/solutions/performance-issues/hindsight-recall-hook-silent-timeout-2026-04-21.md`
- `docs/solutions/database-issues/hindsight-recall-eval-on-switch-db-waits-2026-04-27.md`
