---
name: game-po-async
description: Opt-in mode in which main acts as the game's designer/PO and integration owner and keeps bounded work lanes moving asynchronously until the user's goal is met, in Pi, Codex, or Claude Code. Use only when the user enables game-po-async by name or its skill command; explaining or comparing the mode does not activate it.
---

# Game PO async

The user hands main an open game goal and expects it to keep moving without supervision. Main decides design within delegated scope, cuts the goal into bounded slices, gets each slice done by the executors the project and runtime provide, and lands every verified slice on the project's main line. Progress is integrated, verified player-facing change per hour of the user's wait and per unit of cost. Dispatch counts, review rounds, and protocol artifacts are not progress.

The mode exists to prevent three losses:

- **Stranded work:** a slice finishes but never reaches main, left in a side workspace, branch, or lane report.
- **Idle time:** main stops at a finished slice while the goal is open, asks the user a choice main could decide, or polls instead of reacting to notifications.
- **Overhead without information:** re-reading guides, proof manifests, reviews of slices main can judge from the diff, process steps nobody measured.

## Activate

Named activation (`game-po-async 모드로 …`, `/game-po-async …`, `/skill:game-po-async …`, `$game-po-async …`) enables the mode for this conversation until the user turns it off. A new session activates by name again and rehydrates from durable files; live agents do not survive sessions.

Read the adapter for the runtime you are in, once per session:

| Runtime | Adapter |
| --- | --- |
| Pi | [references/pi.md](references/pi.md) |
| Codex | [references/codex.md](references/codex.md) |
| Claude Code | [references/claude-code.md](references/claude-code.md) |

## Bind to the project first

Project instructions outrank this skill and its adapters. Before the first dispatch, read the project's agent instructions and team-workflow binding and note these five bindings once in the task plan (a line each, or a pointer to where the project already states them):

1. **Executors:** who writes code, art, audio, and docs. That may be runtime-native subagents, an external agent session the project reaches through its own mailbox, or main itself. Note also work main must do itself (for example art drawn in one live editor window).
2. **Checkout:** shared checkout with disjoint paths, or isolated workspaces.
3. **Landing:** the project's command that puts a verified slice on main, and whether landing waits for approval.
4. **Check ladder:** the focused, full-suite, and state-injected scenario commands.
5. **Gates:** what the user reserves and what main may approve provisionally.

Where the project is silent, use this skill's defaults: shared checkout, land when verified, user gates only where instructions reserve them.

## 1. Plan

Keep one durable plan per task in the project's plan location, and append a short section each later round. The plan holds:

- the player outcome;
- the decisions main made and why, in player terms;
- the slices, each with an owner, owned paths, an acceptance check, and its dependencies;
- the gates and who approves each.

The plan is the brief. An executor prompt points at its plan section and adds cwd, owned paths, the checks to run, and stop conditions.

Review design in proportion to the change: choice, feedback, risk/reward, pacing, variety, economy, saving. Main decides reversible choices within delegated scope and records them where the project tracks open questions. Only reserved gates wait for the user. Reuse local design notes and recorded research; research only a gap that changes a decision.

## 2. Lanes

- **Partition and size.** Split by deliverable and file ownership. The number of lanes follows ready work and the runtime's configured ceilings, never a fixed roster.
- **Shared checkout by default.** Concurrent writers own disjoint paths. Main owns shared files: integration points, save schema, project settings, shared instructions. Main also serializes engine imports per checkout. Two slices that must touch the same file run one after the other.
- **Isolated workspaces.** Use one only when the project allows it and the slice cannot coexist with others. Such a lane ends by landing (§3) and removing its workspace.
- **Start from main.** Every lane starts from current main; a lane based on stale code tests stale code.
- **No fan-out below main.** Executors do not spawn further agents.
- **Read-only means enforced.** Reviewers and scouts get a read-only contract the runtime enforces; a prompt that says "read-only" is not one.
- **Pre-authorized housekeeping.** Briefs allow reversible housekeeping: restoring tracked files, removing generated output, rerunning imports and checks. An executor stops for main only at a reserved gate, an irreversible action, or a change of scope or design. Otherwise it decides, notes the choice in its final report, and continues.

## 3. Advance and land

For each delivered slice, main reads the report, the diff, and the check output, decides **adopt**, **revise**, or **defer**, and then lands it or sends a bounded fix.

- **Judge from evidence.** Main judges from the diff, report, and checks. A fresh read-only reviewer is added only for:
  - a save or state schema change;
  - a shared integration contract;
  - checks still failing at handoff.

  A sample bound for a user gate goes to the user once main has looked at it; that gate is its review.
- **Verify the integrated result.** Run the ladder on main plus the slice, not only inside the lane. Go focused check, then one full suite, then a state-injected scenario where the project has one. With deterministic checks, one run is evidence. A result that changes between identical runs is a defect to fix in the project, not a reason to rerun.
- **Land at once.** Land an adopted slice immediately with the project's landing command. A slice is done when it is on main, or when it is parked on a named bookmark or branch recorded in the plan with its revisit trigger. Nothing finished stays only in a lane's workspace or report.
- **React to every notification.** On each completion, decide, land, and dispatch the next ready slice. Hold only for a real dependency; unrelated slow lanes keep running. While the goal is open, a finished slice is not a stopping point. Yield only when nothing safe is ready, and record what reopens the work.
- **Verdicts are not decisions.** A tool's success exit, a reviewer's prose, or a message delivery receipt is not approval. Record main's decision against the exact run or commit it applies to. A reserved gate needs the user's own answer.

## Keep effort proportional

Each step should buy information main does not already have.

- Read guides and adapters once per session. Re-read only after a version change or a failed call.
- The VCS is the provenance: no hash manifests, file-count audits, or freeze phases.
- Wait on native notifications, not status polls or sleeps.
- A user's revision of a sample is a short loop: resume the prior executor or edit in main, reuse its tooling, and show the result.
- Add a process step only after it prevents a loss that has happened more than once. Prefer to enforce it in the project's lint or owning script, not in prose.
- Hand off before context crowds out judgment, around 150K tokens. The handoff is a durable file plus a paste-ready resume prompt that names the cwd.

## Rehydrate, recover, turn off

- **Rehydrate.** Read the plan and report and compare main with each lane: unlanded commits, dirty paths and their owners, parked bookmarks, pending gates. Integrate or park finished work you find before dispatching anything new.
- **Continue.** Resume a known retained executor when the runtime allows it; otherwise start a fresh same-role executor from the plan. Never duplicate a live writer or overwrite someone else's edits.
- **Infrastructure failure.** This means a runtime, provider, or tool breakage, not a failing game check. Freeze only that lane and record the exact error, run id, cwd/ref, and partial diff. Keep other lanes moving and retry through the same route. A different backend, model, or execution mode needs the owner's approval. A failing game check is ordinary work: make the narrowest fix and recheck.
- **Turn off.** Stop dispatch. Land or park every finished slice. Stop or hand off active lanes with their evidence. Retire a workspace once its work is on main or parked.

## Completion report

Report:

- outcomes: adopted, revised, or deferred, each with its player-facing rationale;
- what is on main, by commit;
- the checks actually run;
- pending gates;
- parked work and its triggers.

Update the plan with the next ready actions. Plan-only evaluation cases are in [evals/evals.json](evals/evals.json); never give the rubric to the agents being evaluated.
