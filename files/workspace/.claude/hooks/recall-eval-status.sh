#!/usr/bin/env bash
# SessionStart hook: surface unacknowledged recall-eval alerts into context.
# Silent when no state, no jq, or no active alerts.
set -u

state="$HOME/.local/state/recall-eval/alert-state.json"
[ -f "$state" ] || exit 0
command -v jq >/dev/null 2>&1 || exit 0

active=$(jq -r '
  if .entries then
    [.entries | to_entries[] | select(.value.acknowledged_at == null)] | length
  else 0 end
' "$state" 2>/dev/null)

[ -z "$active" ] && exit 0
[ "$active" = "0" ] && exit 0

detail=$(jq -r '
  .entries | to_entries
    | map(select(.value.acknowledged_at == null))
    | map("- [\(.value.level)] \(.key) since \(.value.first_fired_at), last=\(.value.last_value)")
    | join("\n")
' "$state" 2>/dev/null)

jq -n \
  --argjson count "$active" \
  --arg detail "$detail" \
  '{
     hookSpecificOutput: {
       hookEventName: "SessionStart",
       additionalContext: (
         "recall-eval: \($count) unacknowledged alert(s) on homelab hindsight:\n"
         + $detail
         + "\n\n`just recall-eval-pull-state` for latest state; `just recall-eval-ack` to clear after remediation."
       )
     }
   }'
