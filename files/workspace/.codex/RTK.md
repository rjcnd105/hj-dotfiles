# RTK - Rust Token Killer (Codex CLI)

**Usage**: Token-optimized CLI proxy for shell commands.

## Rule

Use `rtk` for high-output shell commands when summarized output is acceptable.
Use raw commands when exact stdout/stderr, exit codes, TTY behavior, streaming,
shell syntax, or tool debugging matters. If `rtk` is unavailable, use raw
commands and continue.

Examples:

```bash
rtk git status
rtk cargo test
rtk npm run build
rtk pytest -q
```

## Meta Commands

```bash
rtk gain            # Token savings analytics
rtk gain --history  # Recent command savings history
rtk proxy <cmd>     # Run raw command without filtering
```

## Verification

```bash
rtk --version
rtk gain
which rtk
```
