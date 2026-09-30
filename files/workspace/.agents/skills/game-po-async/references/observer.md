# Intermittent whole-portfolio observer

Use at genuine phase/completion opportunities in active game-po-async, or on explicit user request. This is a bounded read-only episode within the existing parent-owned orchestration, not another skill, scheduler, timer, team or approval gate. Main and independent game development continue while it runs.

## Eligibility and singleton lease

1. Main checks recent actual portfolio activity and an eligible opportunity, not every message/tool call. Automatic draws require at least 30 minutes since the last observer finish (or known no prior episode). Skip brief tasks, critical integration/provider recovery, exhausted budgets, absent compliant runtime routing/read-only contract, or unknown observer ownership. Suppression for this task/cooldown also means skip.
2. Inspect the existing plan/lane board/native mission state and exact native status before dispatch, including continuation sessions. Keep one observer lease: owner/session, run identity, observed time window, cost cap, last finish, next eligibility, and any suppression/revisit condition. An active or unknown prior observer means skip, never a duplicate. Reconcile native completion before releasing its lease; if run identity cannot be recovered, preserve unknown ownership and skip.
3. Count the observer under normal global concurrency/depth/spawn limits. Keep the last dependency-ready production slot for production; spare capacity alone does not require an observer.
4. Once eligible, draw once per distinct phase/completion opportunity: probability 10%. Record the draw/opportunity; a miss means continue normal work, not retry immediately or start polling. An explicit user request replaces random selection, while retaining lease, capacity, authority, safety, routing and budget checks. Acquire the parent-owned lease before native dispatch; if dispatch fails, retain exact failure/partial evidence and reconcile the lease rather than blindly retrying.

**Done:** either skip with a compact reason, or one known owner holds the sole bounded observer lease. Use the selected runtime adapter; Pi routing never overrides Codex/Claude policy. No bridge/settings/profile edits follow from an unavailable observer.

## Whole-portfolio packet and bounds

Supply a compact packet covering **main and every active, recently completed or blocked lane**: approved goal/constraints; main decisions/pending decisions; lane owners/cwd/ref/status and outputs; dependencies/approval gates; short event/time/cost summary. Include work-to-review-to-integration transitions, waiting/duplicate dispatch, evidence freshness, and main/orchestration/observer overhead. Randomness selects episodes, never a single worker to sample.

Use already recorded overall events/status for a recent 2–5 minute work window and label it **snapshot/lookback observation**, not continuous live monitoring. Supplied observation brief plus portfolio packet must total at most 8 KB. Compress the whole table rather than dropping main or lanes; if the full scope cannot be represented, skip or report insufficient evidence. Avoid hours of raw transcripts or broad generic audits.

Fresh compatible read-only role; no writes or self-fanout. Cost cap: at most 90 seconds execution, early finish allowed, and at most three targeted evidence reads. Use only verified native budget/stop controls; if the bounds cannot be enforced, skip automatic dispatch. If native event delivery supplies additional snapshots, accept at most two within the same episode/bounds. Do not sleep/poll or keep a model alive merely to fill time.

**Done:** complete bounded findings or an honest evidence limit, not a requirement to discover waste.

## Findings, decision and self-limiting

Return zero to two concrete findings. Each states precise evidence/time/lane (including main where relevant), effect on goal/cost, smallest reversible correction, verification and uncertainty. `no actionable issue` and `insufficient evidence` are valid; do not invent problems, force findings or propose broad redesign. Return native final evidence as supported by the adapter; main owns durable notes.

Main reviews promptly and records accept/revise/defer plus one next check. Only main authorizes an evidence-backed local correction within delegated scope, when expected benefit exceeds correction cost; user-reserved canon/asset gates stay reserved. Observer suggestions/verdicts never block unrelated work or substitute for review/integration approval.

Record actual duration/tools/tokens when available, marking unavailable metrics unknown rather than guessing. Keep one compact accepted/rejected learning note in the existing authority, not a new database or fixed META edit. Recheck a correction via a cheap existing focused check or a later eligible episode; no observer-of-observer, extra grader or recursive review pipeline.

If observer/correction overhead exceeds recoverable waste, delays production, or repeated episodes yield no actionable evidence, main suppresses future automatic draws for this task/cooldown and resumes normal work. Mode off stops draws and team dispatch; reconcile the exact active observer with bounded handoff or native stop/checkpoint/retirement, preserving partial outputs.

## Declarative decision examples

These are plan checks, not a live scheduler or throughput evidence. Other eligibility gates are satisfied unless stated.

| Situation | Decision |
| --- | --- |
| Random miss at an eligible completion | Skip episode; continue production; no immediate redraw. |
| Existing active observer lease | Skip new observer; current episode retains whole-portfolio scope. |
| Unknown lease after session continuation | Skip; reconcile exact owner/run before any dispatch. |
| Only the last dependency-ready production slot is free | Skip observer; dispatch ready production instead. |
| Eligible hit, known free lease, spare slot and complete 3-minute packet | One fresh read-only observer over main plus all lanes; 8 KB/90 seconds/three reads/two extra snapshots caps. |
| Episode returns no actionable issue | Record brief outcome/actual cost; no forced finding or corrective pipeline. |
| Evidence shows main duplicated a ready lane's scout, with a cheap local remedy | Main compares benefit/cost, decides and records one authorized correction/next check; reserved gates and other lanes continue. |
| Observer overhead exceeds recoverable waste | Suppress future task/cooldown draws; resume normal work, no observer-of-observer. |
