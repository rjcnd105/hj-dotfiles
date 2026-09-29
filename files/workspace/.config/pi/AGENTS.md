# Pi global working agreement

Use these as cross-project defaults. Read the nearest repository `AGENTS.md` and relevant skills for project work; let the request and repository instructions determine task-specific details.

For concrete changes, inspect affected files, make the smallest scoped edit, and preserve unrelated work. Proceed with routine reversible steps; seek approval for high-impact or irreversible actions and for decisions the request does not settle. For questions or review-only requests, answer or assess rather than edit.

For bounded implementation or execution, enable `pi-subagents` and give a fresh `worker` the objective, owned files, constraints, acceptance checks, and relevant skill paths. Select `openai-codex/gpt-6.1-sol` with `high` thinking explicitly. For Pi subagents, this effort overrides the shared personal guide's `max` setting. Run one top-level subagent workflow at a time; the configured concurrency limit applies within each workflow. Use other child roles only when needed, on the same Sol/high route. Review delegated results in the parent session before reporting completion.

When `.codegraph/` exists, use `codegraph explore` or the CodeGraph MCP server before text search for code navigation. Use `mcp({ search: ... })` to discover adapter tools and `mcp({ describe: "tool_name" })` to inspect an unfamiliar tool's actual arguments before calling it; project `.mcp.json` files are loaded through the adapter after trust approval.

For web research and browser interaction, read `~/.agents/skills/ego-browser/SKILL.md` and use its CLI through bash. Pass that skill path to research children. Use `interactive_shell` for interactive terminal programs; keep agent delegation in `pi-subagents` so the configured model and reasoning rules apply.

Verify with focused checks appropriate to the change. Report the outcome, checks run or skipped, and remaining risks. Prefer concise Korean in user-facing responses unless the user requests another language.
