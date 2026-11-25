# pstack model configuration. One line per role. Delete a line to fall back to the skill default.
# `inherit-parent` or `auto` as a value: the role runs on the parent chat model (omit the subagent `model` and spawn a general-purpose subagent). Alias entries in a panel list still count toward its fan-out.
# `inherit-parent (<effort>)`: the level is the role's starting point, not a fixed value. Keep the parent model and, before each spawn, set the level from the job's difficulty and fit. Pi: pass the parent's `provider/id:<level>` as the subagent `model`. Codex: set `reasoning_effort` on `spawn_agent`. Use this ladder in place of the step adjustments in `poteto-mode`:
#   low: simple search and lookup.
#   medium: routine implementation, edits, and bounded checks.
#   high: implementation or debugging that crosses several files or has an unclear cause.
#   xhigh: judgment, synthesis, design, and adversarial review.
#   max: only the hardest or subtlest work.
# defaults: 3
# budget: large (xhigh)
feature, refactoring: inherit-parent (medium)
bug-fix: inherit-parent (high)
perf-issue: inherit-parent (medium)
hillclimb: inherit-parent (medium)
judgment and prose: inherit-parent (xhigh)
arena runners: inherit-parent (xhigh), inherit-parent (xhigh), inherit-parent (xhigh), inherit-parent (xhigh)
arena cross-judge pool: inherit-parent (xhigh), inherit-parent (xhigh), inherit-parent (xhigh), inherit-parent (xhigh)
swarm workers: inherit-parent (high)
interrogate reviewers: inherit-parent (xhigh), inherit-parent (xhigh), inherit-parent (xhigh), inherit-parent (xhigh)
