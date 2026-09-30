# Codex adapter

Use only in Codex, not as a CLI fallback for a failed Pi/Claude lane. Codex discovers user skills at `~/.agents/skills`; invoke `$game-po-async [request]` (or select through `/skills`). Changes are detected automatically; restart Codex if discovery remains stale. No Pi link/copy or config edit is required.

## Capability and routing gate

Inspect the actual exposed tool schemas, available agent/model descriptions, parent provider/model/effort, and configured ceilings. Installed CLI 0.159.2 has both v1 and v2 native multi-agent schemas; availability and override fields vary by session. The live schema, not a version guess, selects the branch below. If delegation is disabled/absent, report that constraint and continue authorized planning; do not enable features or install a bridge.

Resolve the required provider/model/effort from the invoking session's current user/project instructions before dispatch; this adapter does not set a cross-runtime default. For example, if the operator requires `openai-codex/gpt-6.1-sol:high`, verify the native Codex backend mapping to `gpt-6.1-sol` and `high`, rather than passing the Pi composite string blindly. A Pi-only routing override does not replace the Codex session's own policy. Where the exposed spawn schema supports overrides, use its `model` and `reasoning_effort` fields explicitly. They can be hidden/removed; verified compliant inheritance is then the only acceptable existing route. If provider/model/effort cannot be verified or honored, block that dispatch, seek explicit approval for any alternative, and keep safe compliant work moving. Selecting a model without effort can use a model default; that is not proof of `high`.

## Native delegation and continuation

Use one main-owned lane board and native child tools, not Pi JavaScript or another scheduler. Inspect the exact exposed namespace and parameter requirements before calling:

| Exposed contract | Launch/context | Messages and continuation | Lifecycle |
| --- | --- | --- | --- |
| v1 | `spawn_agent`; fresh context via `fork_context: false`; bounded `message` | `send_input` to the exact returned target; if closed, `resume_agent` with known `id` before sending the continuation | `close_agent` with exact `target` after evidence capture releases completed open agents; its shutdown also affects descendants |
| v2 | `spawn_agent`; required `task_name` and `message`; fresh context via `fork_turns: "none"` (default is all) | `send_message` with exact `target` and `message` delivers guidance but does not start a turn; `followup_task` triggers a turn on an idle retained non-root target | `interrupt_agent` stops the target's current turn, leaving it available; this is not close/retirement |

Capture actual returned identity: v1 returns `agent_id`; v2 returns canonical `task_name` and may omit metadata. Use a short task name satisfying the exposed schema and keep it stable in the evidence board. v2 `list_agents`, when exposed, lists live agents, not all persisted history. Do not assume v1 `resume_agent`/`close_agent` exist in v2 or invent a v2 close equivalent. Completed roles hand off and receive no new work unless a useful bounded continuation is ready; preserve evidence even when using a supported close.

Native spawned-agent completion notifications carry final status/result into the parent thread/mailbox. On each completion, inspect that lane now, launch a fresh read-only review, and let main decide before a fix or ready successor; unrelated slow lanes continue. Use a verified read-only role/tool contract and isolated writer cwd/workspace; Codex's native children do not imply workspace isolation.

Yield to native notifications when no safe action remains. If the actual turn contract needs a bounded native `wait_agent`, use its exposed semantics: v1 waits for terminal status; v2 waits for mailbox activity and returns an activity summary, not the report content. Read the delivered completion/evidence before advancing. Neither is a reason for repeated status/timeouts or a global all-lanes barrier.

## Approval, evidence, recovery

A fresh reviewer returns complete findings and inspected references in its native final result. There is no Pi `output` binding, `structuredOutput`, or `subagent_supervisor` API here. Main records an adopt/revise/defer decision tied to the exact review run/target and artifacts, with player-facing rationale and scope; use native messaging for a correlated decision/follow-up only after approval. A delivery receipt or a message to an idle v2 agent is not a completed review or continuation. User-reserved gates remain user-owned.

Main durably records the actual native final report/thread identity and available artifact paths in the existing project plan/report; do not ask a read-only child to write shared progress or invent output mappings. Retain structured verdict data only through an actually exposed contract, or main evaluates the report manually.

For recovery, inspect exact originating thread/run status, ownership and dirty/partial workspace before any retained follow-up. Try the known eligible target first; record an authoritative eligibility failure before fallback. No duplicate writer or assumed cross-session authority. Freeze only an infrastructure-failed lane, capture exact error/cwd/ref/partial evidence, and retry the same native path after reconciliation; different runtimes/models require explicit owner approval. Turning off stops new dispatch and explicitly handles active targets/pending gates without deleting evidence.

## Primary evidence

- [Official skills](https://developers.openai.com/codex/skills/): user `.agents/skills`, `$`/`/skills` invocation, symlink support and automatic change detection.
- [Official subagents](https://developers.openai.com/codex/subagents/): delegation, inheritance/overrides, configured limits and thread management.
- [0.159.2 native schemas](https://github.com/openai/codex/blob/rust-v0.159.2/codex-rs/core/src/tools/handlers/multi_agents_spec.rs): both tool families, fresh-context options, optional model/effort exposure, notification/wait and lifecycle semantics.
- [0.159.2 completion watcher](https://github.com/openai/codex/blob/rust-v0.159.2/codex-rs/core/src/agent/control.rs#L421-L518): parent completion mailbox/notification delivery for thread-spawned children.

Verified by installed version/help and primary docs/source inspection, not a live Codex delegation run. Native tools and routing remain session-dependent.
