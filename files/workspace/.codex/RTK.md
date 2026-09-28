# RTK - Rust Token Killer (Codex CLI)

**Usage**: The Codex `PreToolUse` hook condenses output from supported shell commands.

## Rule

Run shell commands normally. Use `rtk proxy <cmd>` for exact captured
stdout/stderr or exit status. For TTY, streaming, shell syntax, or hook
debugging, use a command form the hook skips, such as `sh -c '<command>'`;
verify it with `rtk hook check --agent codex <command>`.

## Meta Commands

```bash
rtk gain            # Token savings analytics
rtk gain --history  # Recent command savings history
rtk proxy <cmd>     # Bypass filtering of captured output
```

## Verification

```bash
rtk --version
rtk gain
which rtk
```
