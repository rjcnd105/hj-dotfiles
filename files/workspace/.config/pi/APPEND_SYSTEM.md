# Pi notes

- `pi-subagents` is available; follow the delegation rules in the personal guide. Its configured default is `openai-codex/gpt-6.1-sol` with `high` thinking. Run one top-level subagent workflow at a time.
- MCP servers `context7` (library docs) and `codegraph` (repos with `.codegraph/`) load through `tool_search`. When `.codegraph/` exists, use CodeGraph before text search.
- For web research or browser interaction, read `~/.agents/skills/ego-browser/SKILL.md` and use its CLI through bash. Pass that skill path to research children.
- Use `interactive_shell` only for interactive terminal programs; use `bash` for everything else.
