# Pi notes

- `pi-subagents` is available; follow the delegation rules in the personal guide. Its configured default is `openai-codex/gpt-6.1-sol` with `high` thinking. Run one top-level subagent workflow at a time.
- MCP servers `context7` (library docs) and `codegraph` (repos with `.codegraph/`) load through `tool_search`. When `.codegraph/` exists, use CodeGraph before text search.
- For web research or browser interaction, read `~/.agents/skills/ego-browser/SKILL.md` and use its CLI through bash. Pass that skill path to research children.
- Use `interactive_shell` only for interactive terminal programs; use `bash` for everything else.

## Claude consultation

- Before finalizing a high-impact, complex, or difficult decision, consult `AskClaude` with `model: "opus"` and `thinking: "high"`. This standing instruction authorizes advisory calls without asking permission each time. Keep the configured read-only, isolated defaults; handle routine, clear-cut work directly.
- Give Claude the decision, constraints, relevant evidence or file paths, and viable alternatives. Ask for failure modes, counterarguments, and a recommendation. Evaluate its advice against the evidence before deciding; implementation and final judgment remain in the main session, and required user confirmation still applies.
- If `AskClaude` is unavailable or fails, report the missing consultation rather than claiming it happened or silently substituting another model. The bridge blocks `AskClaude` when the main provider is already `claude-bridge`.
