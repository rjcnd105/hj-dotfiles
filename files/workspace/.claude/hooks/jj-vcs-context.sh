#!/usr/bin/env bash
# Inject jj-preference context if project has .jj
set -eu

dir="${CLAUDE_PROJECT_DIR:-$PWD}"
[ -d "$dir/.jj" ] || exit 0

cat <<'EOF'
{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"VCS: Project uses jj (Jujutsu). Prefer jj over git: jj st, jj commit, jj describe, jj log, jj diff, jj new, jj bookmark. Use git only for ops jj cannot do. In colocated repos (.jj + .git), trigger git index sync via jj st (auto-snapshot) instead of git add."}}
EOF
