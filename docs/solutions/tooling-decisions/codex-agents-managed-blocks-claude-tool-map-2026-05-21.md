---
title: Preserve managed blocks when optimizing global Codex AGENTS instructions
date: 2026-05-21
category: tooling-decisions
module: Codex global instructions
problem_type: tooling_decision
component: assistant
severity: medium
applies_when:
  - "Editing repo-managed global Codex AGENTS files under files/workspace/.codex"
  - "Preserving automatically managed JJ, Compound Codex tool-map, and references blocks"
  - "Translating Claude Code tool references into actual Codex primitives"
  - "Verifying dotfile-managed instructions through prompt-visible runtime state"
related_components:
  - tooling
  - documentation
  - vcs
tags: [codex, agents-md, tool-mapping, jj, rtk, dotfiles, prompt-visible, runtime-verification]
---

# Preserve managed blocks when optimizing global Codex AGENTS instructions

## Context

Global Codex guidance can drift into a mix of durable behavior rules, generated
compatibility mappings, tool-specific habits, and dotfile ownership details. In
this setup, the live `~/.codex/AGENTS.md` file resolves back to the repo-managed
source at `files/workspace/.codex/AGENTS.md`, so edits must preserve the source
contract and then verify the live and prompt-visible surfaces.

The specific failure mode was over-pruning: removing or rewriting managed
comment blocks while trying to simplify the global instructions. Those blocks
are not ordinary prose. They carry automation and compatibility meaning for JJ,
Compound/Codex tool mapping, and referenced files such as `@RTK.md`.

## Guidance

Keep global `AGENTS.md` prose short and operational:

- role and communication defaults
- evidence-first workflow
- action-by-default behavior
- user-change preservation
- smallest responsible code changes
- verification before claims
- short final reporting

Preserve managed comment blocks as control surfaces, while fixing obvious marker
typos when the managed contract is otherwise clear:

```md
<!-- BEGIN JJ MAP -->
...
<!-- END JJ MAP -->

<!-- BEGIN COMPOUND CODEX TOOL MAP -->
...
<!-- END COMPOUND CODEX TOOL MAP -->

<!-- BEGIN REFERENCES MAP -->
@RTK.md
<!-- END REFERENCES MAP -->
```

When Claude-oriented tool names appear inside Codex-visible guidance, translate
them to the actual Codex runtime surface instead of leaving placeholder names:

```md
- Bash: use functions.exec_command
- LS: use ls via functions.exec_command
- Edit/MultiEdit: use apply_patch
- Task (subagent dispatch) / Subagent / Parallel: use the available Codex subagent primitive when present; if unavailable, run isolated structured passes in the main thread and report degraded coverage. Use multi_tool_use.parallel only for independent tool calls.
```

Wrapper guidance should be conditional, not universal. `rtk` is useful when a
summarized high-output command is acceptable, but raw commands are necessary
when exact stdout/stderr, exit codes, TTY behavior, streaming, shell syntax, or
tool debugging matters.

## Why This Matters

Global instructions load into many unrelated tasks. Stale tool names such as
`shell_command`, over-specific model prose, or rigid wrapper rules make agents
spend effort reconciling impossible instructions instead of doing the work.

Managed blocks have a different risk profile from prose. Removing them can break
external mapping or generated compatibility behavior. Rewriting their internals
without Codex-compatible tool names creates misleading guidance. The durable
pattern is short human-facing global prose plus preserved, corrected
machine-facing blocks.

Verification needs three layers:

- source file: `files/workspace/.codex/AGENTS.md`
- live file: `~/.codex/AGENTS.md`
- runtime prompt surface: `codex debug prompt-input`

File-visible is not enough for agent instruction changes; the prompt-visible
surface is the decisive check.

## When to Apply

- When editing global or repo-level agent instructions.
- When migrating Claude-oriented instructions into Codex.
- When a dotfile-managed home path is symlinked from repo source.
- When managed comment blocks exist inside instruction files.
- When wrapper tooling such as `rtk` is useful sometimes but unsafe as a universal rule.
- When a change must be proven prompt-visible, not just file-visible.

## Examples

Before, the Compound tool map named a tool surface Codex did not expose:

```md
- Bash: use shell_command
- LS: use ls via shell_command
```

After, it names the callable Codex surface:

```md
- Bash: use functions.exec_command
- LS: use ls via functions.exec_command
```

Before, the `RTK.md` include forced every shell command through a summarizing
wrapper:

```md
Always prefix shell commands with `rtk`.
```

After, the wrapper is scoped to the cases where summarization is useful:

```md
Use `rtk` for high-output shell commands when summarized output is acceptable.
Use raw commands when exact stdout/stderr, exit codes, TTY behavior, streaming,
shell syntax, or tool debugging matters.
```

Useful verification commands:

```sh
rg -n 'BIGIN|REFREENCES|shell_command|Always prefix' \
  files/workspace/.codex/AGENTS.md files/workspace/.codex/RTK.md

cmp -s ~/.codex/AGENTS.md files/workspace/.codex/AGENTS.md

codex debug prompt-input 'Show active instructions'
```

Expected result:

- `rg` finds no stale marker, stale tool-name, or stale wrapper-rule strings.
- `cmp` exits `0`, proving the live home file matches the repo source.
- `codex debug prompt-input` shows the updated guidance in the active Codex
  prompt surface.

## Related

- [Prefer decision rules over score thresholds in Codex agent instructions](codex-agent-instructions-decision-rules-over-score-thresholds-2026-05-08.md)
- [JJ review skill subagent diff strategy](../best-practices/jj-review-skill-subagent-diff-strategy-2026-04-03.md)
- [Editor plugin and lspmux boundary](editor-plugin-lspmux-boundary-2026-05-08.md)
- [Global Codex AGENTS source](../../../files/workspace/.codex/AGENTS.md)
- [RTK wrapper guidance](../../../files/workspace/.codex/RTK.md)
