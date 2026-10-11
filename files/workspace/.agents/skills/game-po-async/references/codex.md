# Codex adapter

Codex discovers user skills in `~/.agents/skills`; invoke `$game-po-async [request]` or pick it through `/skills`. Changes are detected automatically; restart Codex if discovery stays stale.

## Capability and routing

Inspect the tool schemas this session actually exposes, the agent and model descriptions, the parent model and effort, and the configured ceilings. The live schema, not a version guess, decides between the two native multi-agent families below. If delegation is absent or disabled, report that and continue planning and main-owned work. Do not enable features or install a bridge.

Use the model and effort the current user or project instructions name. Where the spawn schema exposes `model` and `reasoning_effort`, pass them explicitly. Where it hides them, verified inheritance is the only acceptable route. A model chosen without an effort may run at that model's default effort, which does not prove the effort the instructions require. If a required route cannot be verified, block that dispatch and keep other compliant work moving.

## Native delegation

| Schema | Launch | Messages and continuation | Lifecycle |
| --- | --- | --- | --- |
| v1 | `spawn_agent` with `fork_context: false` and a bounded `message` | `send_input` to the returned target; if closed, `resume_agent` with the known `id` first | `close_agent` on the exact target after its evidence is captured; also closes descendants |
| v2 | `spawn_agent` with `task_name`, `message`, `fork_turns: "none"` | `send_message` delivers guidance without starting a turn; `followup_task` starts a turn on an idle retained target | `interrupt_agent` stops the current turn and keeps the agent |

- **Identity.** Record the identity each call returns (v1 `agent_id`, v2 canonical `task_name`). v2 `list_agents` shows live agents only. Do not assume v1 `resume_agent` or `close_agent` exist under v2.
- **Completions.** A child's completion arrives in the parent's thread or mailbox with its final result. Handle it at once: read the report, diff, and checks, then decide, land, or fix. Unrelated slow lanes keep running.
- **Waiting.** Use `wait_agent` only when the turn contract needs a bounded wait. Under v1 it returns at terminal status. Under v2 it returns on mailbox activity with a summary, not the report itself.
- **Checkout.** Native children do not imply workspace isolation. They share the checkout and own disjoint paths, unless the project provides isolated workspaces.
- **Reviews.** A reviewer returns its findings and the references it inspected in its final result. There is no `output` binding, `structuredOutput`, or `subagent_supervisor` here. Main reads the report and records its decision against the exact target.

## Recovery

Before a retained follow-up, check the exact originating thread, the target's status, and the state of the files it owns. Try the known target first; record why it is ineligible before starting a fresh one. Freeze only a lane whose infrastructure failed, and retry through the same native path.

## Primary sources

- [Skills](https://developers.openai.com/codex/skills/)
- [Subagents](https://developers.openai.com/codex/subagents/)
