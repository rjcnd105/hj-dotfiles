#!/usr/bin/env bash
# Inject the VCS switch with the smallest prompt-visible surface.
set -eu

cd "${CLAUDE_PROJECT_DIR:-$PWD}"

if command -v vcs-kind >/dev/null 2>&1; then
  vcs_kind="$(vcs-kind)"
elif command -v jj >/dev/null 2>&1 && jj root >/dev/null 2>&1; then
  vcs_kind="jj"
else
  vcs_kind="git"
fi

case "$vcs_kind" in
  jj | git) ;;
  *) vcs_kind="git" ;;
esac

printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"VCS_KIND=%s"}}\n' "$vcs_kind"
