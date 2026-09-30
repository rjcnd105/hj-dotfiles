---
name: game-po-async
description: Opt-in game designer/PO-led asynchronous delegation in Pi, Codex, or Claude Code. Use only when the user explicitly enables game-po-async by name or its skill command; explaining the mode does not activate it.
---

# Game PO async

Main is the game designer/PO and integration owner, not a fanout clerk. Advance dependency-ready work with the invoking runtime's verified native primitives. Project instructions, applicable model/effort routing, and user-reserved approval gates remain authoritative.

## Activate and select the adapter

Explicit named activation (`game-po-async 모드로 [요청]`) enables this conversation/request until turned off. Explaining/comparing the mode is read-only, not permission to dispatch. New sessions activate by name again and rehydrate evidence; local skill files persist, not immortal live agents.

Identify the actual runtime and exposed capabilities, then read only its adapter before dispatch:

| Runtime | Invocation | Adapter |
| --- | --- | --- |
| Pi | `/skill:game-po-async [request]` | [references/pi.md](references/pi.md) |
| Codex | `$game-po-async [request]` | [references/codex.md](references/codex.md) |
| Claude Code | `/game-po-async [request]` | [references/claude-code.md](references/claude-code.md) |

One canonical source lives in `~/.agents/skills/game-po-async`; Claude Code's personal skill entry links to it. Pi and Codex discover the canonical location directly. Use the adapter's refresh guidance, not extra copies or settings edits.

**Done:** runtime, native delegation/notification/continuation capabilities, and required routing are identified. If capabilities or the required route are unavailable, report that execution constraint; continue authorized planning/review or unrelated compliant work. Default capability/model inheritance is not permission to substitute a backend, install a bridge, or switch execution mode.

## 1. Frame the outcome

Read the user's goal, nearest instructions, canon/contracts, owner routes, and existing plan/report. Reuse local design learning, including recorded video/research lessons; research only a material evidence gap.

Define the player outcome, bounded deliverables, acceptance evidence, dependencies, exclusive file owners, integration owner, and approval gates. Review choice, feedback, risk/reward, pacing, variety, economy, and saving effects in proportion to the change. Main adopts, revises, or defers within delegated scope; reserved decisions go to the user.

**Done:** a durable plan identifies ready work, blocked work, and who can approve each gate.

## 2. Prepare useful lanes

Partition by deliverable/dependency/file owner, not a fixed roster or agent count. Discover executable roles and actual model/effort capabilities before dispatch. Create only useful roles when prerequisites and capacity permit; preserve configured concurrency/depth/spawn/tool ceilings. Role selection does not authorize profile/settings changes.

Give each child a fresh bounded context: objective, cwd/ref, exclusive files or read-only boundary, source pointers, constraints, checks, final-report contract, and stop/ask conditions. Leaves do not fan out. A role name or prompt alone does not remove edit authority; select a verified read-only contract for reviews or report its absence.

Use `VCS_KIND`. One writer per cwd/workspace; isolate concurrent writers. Main exclusively owns shared files/integration. For jj, including colocated jj, use native jj workspaces/mutations rather than Git worktree shortcuts. Serialize engine imports per checkout. Bound writers by a coherent slice and safe checkpoint, not a hard tool-call cap.

**Done:** routing, capacity, ownership, and prerequisites permit non-overlapping launches.

## 3. Advance branch-locally

Keep one parent-owned orchestration at a time; children and follow-ups stay within that owner's runtime-native protocol. Validate any executable workflow before launch. Observe all launches/results, including surviving siblings after a lane failure; dispatch receipts are not completed reports.

For each delivered slice: **writer → fresh read-only review → main PO decision → bounded fix/re-review or next step**. Consume actual changes, reports, and checks at each dependency barrier. Keep reviewer verdict and main decision distinct; successful tool exit and verdict prose are not approval. Use verified structured outputs when scripts branch on a verdict, rather than parsing prose.

Record main's decision, player-facing rationale, scope, conditions, and exact correlated request/run/artifact evidence. Use native reply on the exact pending request where supported; otherwise main records the gated decision and sends a correlated native continuation only after approval. Steering/delivery receipts alone are not approval proof. Read-only children return complete final evidence using the adapter's supported handoff, without being asked to write shared progress files.

On native completion/decision notifications, triage immediately and schedule safe ready follow-ups. Hold only real dependencies or joint integration barriers, not unrelated slow lanes. Yield when no safe immediate action remains and record the revisit trigger. Use native notifications rather than sleep/status polling; a runtime's bounded event wait is appropriate only when its actual turn contract needs one.

At genuine phase/completion opportunities, use [references/observer.md](references/observer.md) for occasional bounded observation of **main and the whole portfolio**. Max-one limits observer instances, not observed lanes; observations do not gate production.

**Done:** lanes are accepted, deferred at explicit gates, or blocked with preserved evidence; main verifies integration behavior, not just report aggregation.

## Rehydrate, recover, turn off

- Rehydrate: read the durable plan/report, exact run status/originating session, cwd/ref, dirty/partial work and ownership, approval evidence, and available artifact references before dispatch. Try an eligible known retained child before a documented same-role fallback; authoritative continuation eligibility and route must be checked. Never duplicate a live writer, overwrite unrelated edits, or assume cross-session reply authority.
- Infrastructure failure: freeze the affected lane. Record exact error/failure kind, run/status, cwd/ref, and clean-state proof or captured partial diff. Preserve sibling evidence and advance independent safe work. Diagnose and retry through the same native protocol, or seek explicit owner approval for another execution mode/model/backend. Repair a review binding/schema mismatch before that gate advances; do not rerun a successful writer merely to recover a review report.
- Turn off: stop further mode dispatch. Handle active jobs and pending requests explicitly: agree bounded handoff or exact-run stop/checkpoint and preserve partial evidence. Retire completed roles through available native lifecycle controls, retaining run identity for selective continuation; retirement does not authorize deleting workspaces/artifacts.

## Completion

Return adopted/revised/deferred outcomes with PO rationale, checks and actual behavior verified, pending gates/material risks, exact run/cwd/ref identities, and returned native report pointers (where available). Omit or normalize absent fields; never invent an artifact mapping or require an optional one. Update the existing project plan/report with next-ready actions and revisit triggers. Static orchestration checks do not establish measured throughput or game quality.

Plan-only evaluation cases and rubrics: [evals/evals.json](evals/evals.json). Evaluation runners must provide baseline agents only the derived prompt-only inputs, never this rubric.
