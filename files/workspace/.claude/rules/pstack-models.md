# pstack model configuration. One line per role. Delete a line to fall back to the skill default.
# `inherit-parent` or `auto` as a value: omit the subagent `model`. In Claude Code the subagent then runs on `CLAUDE_CODE_SUBAGENT_MODEL` from settings.json (Claude Opus 5.5), not on the parent chat model. Alias entries in a panel list still count toward its fan-out.
# `inherit-parent (<effort>)`: the level is the role's starting point, not a fixed value. Omit `model` and, before each spawn, set `effort` on Claude Code's `Agent` from the job's difficulty and fit. Use this ladder in place of the step adjustments in `poteto-mode`:
#   low: simple search and lookup.
#   medium: routine implementation, edits, and bounded checks.
#   high: implementation or debugging that crosses several files or has an unclear cause; judgment, synthesis, design, and adversarial review.
#   xhigh: only the hardest or subtlest work, after `high` fell short.
# budget: medium (high)
feature, refactoring: inherit-parent (medium)
bug-fix: inherit-parent (high)
perf-issue: inherit-parent (medium)
hillclimb: inherit-parent (medium)
judgment and prose: inherit-parent (high)
hardest tasks: inherit-parent (high)
how explorer: inherit-parent (low)
how explainer: inherit-parent (high)
why investigators: inherit-parent (medium)
why synthesizer: inherit-parent (high)
reflect tooling: inherit-parent (medium)
reflect judgment, divergent, synthesizer: inherit-parent (high)
arena runners: inherit-parent (high), inherit-parent (high)
arena cross-judge pool: inherit-parent (high)
swarm workers: inherit-parent (high)
architect runners: inherit-parent (high), inherit-parent (high)
interrogate reviewers: inherit-parent (high), inherit-parent (high)
