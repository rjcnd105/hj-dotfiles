# Claude Code adapter

Use only in Claude Code, not as an execution-mode fallback. Personal skills load from `~/.claude/skills/<name>/SKILL.md`; a skill folder may be a symlink and Claude loads its target once. This installation links `~/.claude/skills/game-po-async` to the canonical `.agents` directory. Invoke `/game-po-async [request]`. Claude watches personal/project skills for changes; restart if a symlink-target edit is not reflected. No divergent copy or settings edit is required.

## Routing and capability gate

Inspect the actual available `Agent`, `SendMessage`, and stop/report tools, existing executable agent types/tool restrictions, parent/subagent model and effort, and configured limits. Use ordinary fresh-context subagents, not conversation forks or a skill `context: fork` that would displace main PO ownership. There is no Pi workflow/supervisor API here.

Resolve the required provider/model/effort from the invoking session's current user/project instructions; this adapter does not impose Pi's routing on Claude. If those instructions require an OpenAI Codex/Sol route (for example `openai-codex/gpt-6.1-sol` with `high` effort), standard Claude aliases (`sonnet`, `opus`, `haiku`, etc.) and `inherit` do not prove that route, and current native documentation does not establish an OpenAI Codex backend mapping. An explicitly authorized Claude-native route instead follows its verified Claude model/effort contract. If no already explicitly approved compatible backend/route exists, report **delegation blocked by routing**. Continue authorized planning/review or unrelated compliant work; do not silently choose a Claude model, install a bridge, edit settings/profiles, or launch a coding-agent CLI.

If the user explicitly authorizes a compatible route, verify the live session and existing subagent contract can honor it. Claude's documented per-invocation `model` takes precedence over agent configuration, but an organization allowlist can cause substitution. Effort is inherited from the session unless an existing subagent definition overrides it. Verify resolved model/effort rather than accepting defaults or substitution warnings. If the exposed contract cannot guarantee the authorized route, defer dispatch.

## Delegate, consume, decide

- Use the exposed `Agent` contract with a bounded prompt, selected existing type, and read-only tool contract for reviews. Regular subagents start fresh; forks inherit history. A role name alone is not a permission boundary. One main-owned lane board orchestrates all branches; children do not fan out.
- Background subagents run concurrently and report via native completion notifications. Interactive defaults and foreground/background availability depend on fork mode and background-task settings. Use `run_in_background` only if the actual Agent schema/mode accepts it. If native background execution is disabled, report the loss of async capability rather than changing settings or pretending a foreground launch is asynchronous.
- On a completion, consume that lane's actual result/diff/checks, launch its fresh read-only review, and let main record adopt/revise/defer before a bounded fix or ready successor. Independent slow lanes keep running. Yield to native notifications only when no safe ready action remains; do not repeatedly poll task output or use shell sleep.
- Reviewers return complete findings and inspected references in their final native result. Main records exact agent/run identity, received result and available report/output-file pointers in the existing plan/report. Read-only review does not require writing shared progress files. Pi `output`/`outputPathMapping`/`structuredOutput` are not Claude parameters; use only exposed native evidence contracts, or main evaluates the report manually.
- Main's decision is correlated to the exact review/run/gate with rationale, scope, conditions and user approval where reserved. `SendMessage` can deliver that bounded decision/continuation to an exact known target; a delivery receipt is not approval or a completed follow-up. Do not use team-only `plan_approval_response`/`shutdown_request` as a substitute for ordinary subagent communication. Agent calls carrying a name can launch teammates when teams are enabled: avoid team-launch semantics unless separately authorized.

## Continue, stop, recover

Current official docs for installed 2.1.285 describe resuming a completed subagent using `SendMessage` with its agent ID or name in `to`, rather than a new Agent invocation. The retained conversation continues in the background; `TaskStop`-stopped agents can resume once their stopped run exits. Built-in Explore/Plan are one-shot and return no resumable ID. User-cancelled agents do not auto-resume. Inspect exact identity/eligibility and current routing first; try a known eligible candidate before a documented fallback. Do not assume a new session can reach an old subagent just because its transcript exists.

Completed roles finish at handoff and retain evidence. `TaskStop` stops an active background task by exact ID (or supported agent ID/name); it is not transcript/workspace deletion. For turn-off, halt new dispatch, handle pending approval gates and agree bounded handoff or precise stop/checkpoint. Keep configured ceilings even where the runtime's resume path does not enforce the normal spawn limit.

For infrastructure failures, freeze the affected lane, capture exact error/run/cwd/ref and clean-state proof or partial diff, preserve safe sibling progress, and retry only the same native protocol after reconciliation. Route/execution-mode fallback requires explicit owner approval. Keep concurrent writers in exclusive workspaces; native Git worktree isolation is not jj workspace isolation. Engine imports remain serialized per checkout.

## Primary evidence

- [Official skills](https://code.claude.com/docs/en/skills): personal location, `/name`, symlink folders, live change detection and frontmatter.
- [Official subagents](https://code.claude.com/docs/en/sub-agents): fresh contexts, model/effort resolution, background completion notifications, limits and `SendMessage` resume/cancellation semantics.
- [Official tools](https://code.claude.com/docs/en/tools-reference): Agent/team distinction, SendMessage and TaskStop contracts.

Installed Claude Code 2.1.285 version/help and current primary docs were inspected; discovery/symlink checks are not a live Claude delegation or backend-compatibility test.
