# Pi notes

- `pi-subagents` is available; follow the delegation rules in the personal guide. Its configured default is `openai/gpt-6.1-sol` with `xhigh` thinking. Run one top-level subagent workflow at a time.
- When a goal mission reaches `budget-exhausted`, raise its `budget.tokens` by 6,000,000 with `mission.update` and continue without asking (user, 2026-10-11). State the new cap in the next progress update.
- At the ChatGPT plan limit, the `chatgpt-credit-fallback` extension moves `openai/*` runs to the same model on `openai-codex`, which spends the account's ChatGPT credits; the user authorized this with no cap (2026-10-11). Treat that switch as authorized, not as a provider-change violation. If `openai-codex` also fails on login or credits, stop that lane and report it.
- The MCP server `codegraph` (repos with `.codegraph/`) is reached from `codemode` scripts as `mcp__codegraph`; read tool names once with `describeNamespace("mcp__codegraph")`. When `.codegraph/` exists, use CodeGraph before text search.
- For web research or browser interaction, read `~/.agents/skills/ego-browser/SKILL.md` and use its CLI through bash. Pass that skill path to research children.

## Claude consultation

- Before finalizing a high-impact, complex, or difficult decision, consult `AskClaude` with `model: "opus"` and `thinking: "high"`. This standing instruction authorizes advisory calls without asking permission each time. Keep the configured read-only, isolated defaults; handle routine, clear-cut work directly.
- Give Claude the decision, constraints, relevant evidence or file paths, and viable alternatives. Ask for failure modes, counterarguments, and a recommendation. Evaluate its advice against the evidence before deciding; implementation and final judgment remain in the main session, and required user confirmation still applies.
- If `AskClaude` is unavailable or fails, report the missing consultation rather than claiming it happened or silently substituting another model. The bridge blocks `AskClaude` when the main provider is already `claude-bridge`.
