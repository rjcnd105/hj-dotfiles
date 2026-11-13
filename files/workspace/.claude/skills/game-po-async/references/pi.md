# Pi adapter

Pi discovers `~/.agents/skills`; invoke `/skill:game-po-async [request]`, and run `/reload` after editing the skill. Delegation uses the `pi-subagents` extension. Its installed `docs/workflows.md` and `docs/tool-reference.md` are the API authority (checked against 0.78.0).

## Discover once

Once per session, read the installed `pi-subagents` SKILL.md and run `subagent({ action: "list", capabilities: true })` and `action: "models"`. Record the pi and pi-subagents versions in the task plan. Open the large guide topics only when the recorded version changed, a call fails validation, or you need an API this plan has not used yet, and then read only that section. Use `action: "status"` to answer a specific question after a notification or a suspected hang, not as a polling loop.

Copy the exact provider/model/effort the current user or project instructions name from the `models` listing. If a required route is missing, that blocks dispatch, not planning.

## One workflow per task

- **One top-level workflow.** Keep exactly one top-level `async: true` workflow call and launch children only inside it.
- **One script per task.** Reuse one parameterized script for the task, taking the plan section, cwd, owned paths, and checks as arguments. Pass it as `workflow: "./x.workflow.js"`, or as `workflow: true` with one fenced `js workflow` block in the same reply.
- **Validate before launch.** Run `subagent({ action: "validate", … })` on the same script first.
- **Children.** Give each child a stable key, a short verb-and-behavior label, an explicit model, fresh context, a bounded task, and an explicit cwd.
- **Shared checkout.** Children share the project checkout by default, each with disjoint owned paths. `worktree: true` gives a child a Git worktree. Use it only where the project isolates with Git worktrees; in a jj repository, isolation means a jj workspace the project allows.
- **Lane boards.** `runs.lanes(...)` runs a writer → review → fix board in which a blocked lane does not stop its siblings. For conditional or rolling follow-ups, use `runs.run` with `Promise.race` over the pending promises. Use `runs.all` only for a real joint prerequisite.
- **Script syntax.** Use top-level `await`, plain helpers, or promise chains. Nested async functions are unsupported. Await or return every `runs.run` and `runs.steer` promise, including error paths.
- **Child results.** Omit child `async: true` when the script needs the result; an async child returns only a launch receipt.
- **JSON boundary.** `emit` and `return` values must be plain JSON. Omit absent optional fields or normalize them to `null` or `[]`.

## Reviews and decisions

- **Reviewer contract.** Give reviewers a discovered read-only tool set and bind their report with native `output` and `outputMode: "inline"`. When the script branches on a verdict, use `outputSchema` and read `result.structuredOutput`. Reviewer prose is never parsed.
- **Verdict and decision.** The reviewer's verdict (`pass`, `revise`, `blocked`) is distinct from main's decision (`adopt`, `revise`, `defer`). `ok: true` alone is not approval.
- **Blocking requests.** A child asking `contact_supervisor` with `reason: "need_decision"` holds a slot until it is answered. Briefs pre-authorize housekeeping so this happens only for a decision the child cannot finish without. Answer with `subagent_supervisor({ action: "reply", replyTo: <exact request id>, message })`. Steering cannot resolve an approval.

## Pi as an executor for another runtime's main

Some projects make a Pi session the executor while main runs in another runtime. Pi then receives plan pointers through the project's mailbox (for example `pi-intercom`). It posts completion through the project's handoff command, then continues independent work. A choice the user has not reserved goes to that main, not to `ask_user`. Pi's own children follow the same checkout and landing rules as Pi.

## Continue and recover

- **Retained children.** `action: "children.list"` lists this session's retained children; the list may be incomplete. Resume a known child with `action: "resume", id, message`. Inside a workflow, use `await runs.run(key, { resume, task })` with a new stable key. A resumed child keeps its model and tool contract.
- **After a reload.** `/reload` or a session resume stops a running async workflow. Rehydrate from the plan and the retained children before relaunching anything.
- **Failure.** `workflow.failureKind` names script, child, validation, or serialization failures. Freeze only the failed lane, keep the exact error and partial diff, and retry the same route.

## Primary sources

Installed `pi` docs (`docs/skills.md`) and `pi-subagents` docs (`docs/workflows.md`, `docs/tool-reference.md`).
