# Claude Code adapter

Personal skills load from `~/.claude/skills/<name>/SKILL.md`; this entry is a symlink to the canonical `~/.agents/skills/game-po-async`, and edits there are picked up live (restart if not). Invoke `/game-po-async [request]`.

## Executors available here

Inspect the tools actually exposed this session (`Agent`, `SendMessage`, `TaskStop`, Bash background jobs) and the agent types listed with their tool sets. Then map the project's executor binding to one of three routes:

- **External session through the project's mailbox.** A project may name an already-running agent session (another runtime) as its executor and give commands to message it and to wait for its posts. Messaging that existing session is the project's protocol, not launching a coding-agent CLI. Send the plan pointer with its message command. Arm the project's wait command once as a Bash background job; its exit is the completion notification. Re-arm it after handling each post. Never watch that session's files or transcripts.
- **Agent subagents.** Use fresh subagents (a named `subagent_type`, not `fork`). A fork copies main's whole context into every call and blurs ownership. Subagents run in the background and notify on completion; they cannot spawn further agents. `SendMessage` with the agent's ID or name continues a completed subagent with its context intact. Built-in Explore/Plan are one-shot. `TaskStop` stops a running task by ID; that is not deletion.
  - Use subagents for scouts and reviews, and for writing only where the project assigns writing to Claude.
  - Explore and Plan have no Edit/Write but still have Bash. When a review must be strictly read-only, pick an agent type without Bash, Edit, or Write, and give it the diff as a file.
- **Main itself.** Main does the work the project reserves for it. Some tools have one live target, such as an editor window driven through an MCP bridge. Only one agent may write to such a target at a time, so keep that work in main or in exactly one lane.

## Routing

Use the model and effort the user or project names. A preference phrased "when the runtime offers it" falls back to the session's default subagent model when Claude Code does not offer that model; it is not a block. Block dispatch only when the instructions require a route that no exposed option meets, and keep doing authorized planning and main-owned work meanwhile. Pass `effort` only when instructions ask for it. Never edit settings, install a bridge, or swap backends to get a route.

## Checkout

The Agent `isolation: "worktree"` option makes a Git worktree. It is not a jj workspace, and it breaks a project rule that shares one checkout. Use it only where the project uses Git worktrees for isolation. In a shared checkout, give each writing subagent disjoint owned paths and land through the project's landing command.

## Recovery

Before continuing a lane in a new session, check that its agent ID or name is still reachable. A transcript on disk is not a live agent. If it cannot be reached, start a fresh same-role subagent from the plan. Freeze only a lane whose tool or runtime broke, record the exact error, and keep the other lanes moving.

## Primary sources

- [Skills](https://code.claude.com/docs/en/skills)
- [Subagents](https://code.claude.com/docs/en/sub-agents)
- [Tools reference](https://code.claude.com/docs/en/tools-reference)
