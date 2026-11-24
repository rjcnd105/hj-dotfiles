# Claude Code Harness Rules

- For execution subagents, `CLAUDE_CODE_SUBAGENT_MODEL` in settings controls the
  default model; omit `model` on `Agent` unless the request names a specific
  model.
- Claude Code holds a `SendMessage` to a running subagent until that turn ends,
  across any number of tool rounds. `success` only means it reached the inbox,
  and a report can predate the directive. Send later units after the report.
- When one delegated turn must stay long and needs a clean stop, chain a signal
  check to every step in the brief, such as
  `[ -e "$STOP" ] && echo STOP_FOUND || <step>`.
