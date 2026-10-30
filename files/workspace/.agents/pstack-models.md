# pstack model configuration. One line per role. Delete a line to fall back to the skill default.
# `inherit-parent` or `auto` as a value: the role runs on the parent chat model (omit the subagent `model`). Alias entries in a panel list still count toward its fan-out.
# `inherit-parent (<effort>)`: the level is the role's starting point, not a fixed value. Keep the parent model and, before each spawn, set the level from the job's difficulty and fit. Pi: pass the parent's `provider/id:<level>` as the subagent `model`. Codex: set `reasoning_effort` on `spawn_agent`. Use this ladder in place of the step adjustments in `poteto-mode`:
#   low: simple search and lookup.
#   medium: routine implementation, edits, and bounded checks.
#   high: implementation or debugging that crosses several files or has an unclear cause.
#   xhigh: judgment, synthesis, design, and adversarial review.
#   max: only the hardest or subtlest work.
# budget: large (xhigh)
feature, refactoring: inherit-parent (medium)
bug-fix: inherit-parent (high)
perf-issue: inherit-parent (medium)
hillclimb: inherit-parent (medium)
judgment and prose: inherit-parent (xhigh)
hardest tasks: inherit-parent (xhigh)
how explorer: inherit-parent (low)
how explainer: inherit-parent (xhigh)
why investigators: inherit-parent (medium)
why synthesizer: inherit-parent (xhigh)
reflect tooling: inherit-parent (medium)
reflect judgment, divergent, synthesizer: inherit-parent (xhigh)
arena runners: inherit-parent (xhigh), inherit-parent (xhigh), inherit-parent (xhigh), inherit-parent (xhigh)
arena cross-judge pool: inherit-parent (xhigh), inherit-parent (xhigh), inherit-parent (xhigh), inherit-parent (xhigh)
swarm workers: inherit-parent (high)
architect runners: inherit-parent (xhigh), inherit-parent (xhigh), inherit-parent (xhigh), inherit-parent (xhigh)
interrogate reviewers: inherit-parent (xhigh), inherit-parent (xhigh), inherit-parent (xhigh), inherit-parent (xhigh)
