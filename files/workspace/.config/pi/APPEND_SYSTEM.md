# Pi notes

- `pi-subagents` is available; follow the delegation rules in the personal guide. Run one top-level subagent workflow at a time.
- For execution subagents, use `subagents` in `settings.json`; if none is configured, use the newest `gpt-*-sol` model the runtime lists with `high` reasoning.
- When a goal mission reaches `budget-exhausted`, raise its `budget.tokens` by 6,000,000 with `mission.update` and continue without asking (user, 2026-10-11). State the new cap in the next progress update.
- The MCP server `codegraph` (repos with `.codegraph/`) is reached from `codemode` scripts as `mcp__codegraph`; read tool names once with `describeNamespace("mcp__codegraph")`. When `.codegraph/` exists, use CodeGraph before text search.
- For web research or browser interaction, read `~/.agents/skills/ego-browser/SKILL.md` and use its CLI through bash. Pass that skill path to research children.
