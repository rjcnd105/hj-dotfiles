# Pi adapter

Use only in Pi with native `pi-subagents` capabilities. Discover installed package guidance rather than pinning its install path/version. Pi discovers `~/.agents/skills`; `/skill:game-po-async [request]` expands this skill. Use `/reload` in an active session after migration/editing. Leave the old Pi-specific skill location absent to avoid duplicate authority.

## Discover and launch

Discover once per session, then cite what you learned instead of re-reading. Read installed `pi-subagents/SKILL.md`, run `action: "list", capabilities: true` and `action: "models"`, and record the installed pi and pi-subagents versions in the project plan. The large `guide` topics (`workflows`, `tool-reference`) and package references run to ~200 KB together: open them only when the recorded versions changed, a call fails validation, or you need an API not yet used in this plan, and read just the relevant section. Use `action: "status"` to answer a specific question after a notification or a suspected hang, not as a polling loop. Resolve the required route from current user/project instructions. This installation currently requires `openai-codex/gpt-6.1-sol:high` for Pi subagents; that observation is not a portable default or an override of later explicit routing. Copy the exact discovered provider/model/effort; unavailable routing blocks dispatch, not authorized planning.

Keep exactly one active top-level `async: true` workflow. Reuse one parameterized script per task (brief path, cwd, optional review) rather than writing a new script each round. Children launch only inside the workflow script, passed with the installed version's argument (`workflowScriptPath`/`workflowScript` through 0.73.x; from 0.74.0 a path string `workflow: "./x.workflow.js"`, or `workflow: true` with a fenced `js workflow` block). Check the installed `docs/workflows.md` once when the recorded version changes. Validate the same script with native `action: "validate"` before launch. Use stable keys, short verb + behavior labels, explicit model, fresh context, bounded tasks, and explicit cwd. jj workspace isolation uses project-native jj plus per-child cwd, not Pi's Git `isolation: "worktree"` shortcut.

Use `runs.run` with rolling `Promise.race` for event-local follow-up. Joint `runs.all`/`Promise.all` barriers require actual joint prerequisites. Use top-level await, plain helpers, or Promise chains; nested async functions/arrows/methods are unsupported. Observe every stored launch/steer promise, including error paths. Omit child `async: true` when the workflow needs final results: explicit child async returns only a launch receipt, and reusing its key does not refresh it.

## Review and main approval

- Select a discovered read-only tool contract. Bind each final report through native `output` and `outputMode: "inline"`. A read-only child returns the complete report; the runtime persists it. Prose filenames and file-only instructions are not durable API bindings.
- For scripted verdict gates, use `outputSchema` and consume `result.structuredOutput`. A typed host gate and child `outputSchema` are alternative structured-output sources, not combinable ones. Keep reviewer verdict (`pass`, `revise`, `blocked`) distinct from main decision (`adopt`, `revise`, `defer`). `ok: true` alone is not approval.
- The reviewer finishes and returns its verdict through `outputSchema`; main decides on the completed result and schedules the fix or successor in the workflow. A blocked child holds a concurrency slot and its `contact_supervisor` wait times out after 10 minutes, so reserve `reason: "need_decision"` for a decision without which the child cannot finish (see SKILL.md "Keep effort proportional"). When a request is pending, main answers it with `subagent_supervisor({ action: "reply", replyTo: <exact request id>, message: <decision, rationale, scope, conditions> })` and retains the native request/reply evidence; steering cannot resolve approval.
- For user-reserved gates, main obtains explicit user approval or replies with defer; unrelated lanes can continue. Reviewer final output records findings and correlated decision evidence. Consume valid final evidence before scheduling the bounded fix/re-review or ready successor inside that same workflow. Let unrelated slow siblings continue.

## JSON boundary and durable evidence

Workflow `emit`/`return` values must be JSON-compatible: no `undefined`, functions, promises, or host objects. Optional native fields may be absent. Omit them or normalize absent `outputReference`/`outputPathMapping` to `null` and `artifactPaths` to `[]`, including minimal-result and error branches. An absent optional `outputPathMapping` is not a failed review when the actual required report resolves. Test minimal/error result serialization before launch; do not emit an absent property blindly.

Preserve returned `runId`, status, keys, cwd/ref, checks, native `outputReference`, `outputPathMapping` and `artifactPaths` only when supplied. Inspect actual native bindings/mappings before accepting reports, rather than trusting prose filenames. Recover report evidence or rerun a bounded read-only review if necessary, not the successful writer by default.

## Continue, recover, retire

Known workflow children: `action: "children.list"` returns a session-scoped, incomplete retained roster. For a known direct child, inspect exact `action: "status", id`. Try authoritative `action: "resume", id, message` only when eligible; within an active workflow use awaited `runs.run` with `resume` instead of `agent`, a new stable key, and the latest returned run id. Retained resume preserves its model/tool contract. Record eligibility rejection before a same-role fallback; do not answer another session's pending supervisor request by assumption.

Freeze a lane on infrastructure failure; retain exact error, failure kind, run/cwd/ref, and clean-state proof or partial diff. Retry the same native protocol after process/ownership reconciliation, or request explicit owner approval for CLI/foreground/model fallback. Keep observing safe siblings. Native completion/decision notifications drive follow-up; yield rather than sleep/poll/`bg_wait` solely for ordinary children.

Completed runs finish at handoff and remain evidence-addressable. For turn-off or an active failure, inspect exact status and use native `stop`/checkpoint as appropriate; no workspace/artifact deletion follows from retirement.

## Primary evidence

- Installed Pi `docs/skills.md`: user/Agent Skills discovery, relative references, `/skill:name [args]`, `/reload`. Installed `dist/core/skills.js` and `AgentSession._expandSkillCommand` are the static loading/expansion authority.
- Installed pi-subagents `docs/workflows.md`: scripted/rolling workflows, JSON result boundary, validation and supervisor coordination; `docs/tool-reference.md`: output binding, retained children, status/control. Obtain current copies via the installed guidance and `guide` topics above.

These documents support the adapter; reading/loader checks are not a live delegation test.
