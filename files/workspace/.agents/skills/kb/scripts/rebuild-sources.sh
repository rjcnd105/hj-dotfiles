#!/usr/bin/env bash
# Rebuild kb/.sources by aggregating kb-sources entries from kb/ page frontmatter.
#
# Skips meta files: SCHEMA.md, INDEX.md, LOG.md, ROADMAP.md (they may contain
# example YAML that would pollute the aggregate).
#
# Usage:
#   rebuild-sources.sh
#
# Output: writes kb/.sources (one path per line, sorted, deduplicated).

set -euo pipefail

VAULT="${KB_VAULT:-/Users/hj/Library/Mobile Documents/iCloud~md~obsidian/Documents/Brain}"
KB="$VAULT/kb"
OUT="$KB/.sources"

if [[ ! -d "$KB" ]]; then
  echo "error: kb dir missing: $KB" >&2
  exit 2
fi

# Find kb page markdown files, excluding meta files.
tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT

find "$KB" -maxdepth 1 -type f -name '*.md' \
  ! -name 'SCHEMA.md' \
  ! -name 'INDEX.md' \
  ! -name 'LOG.md' \
  ! -name 'ROADMAP.md' \
  -print0 \
  | xargs -0 grep -h -E "^[[:space:]]*-[[:space:]]+['\"](Clippings/|session:)" 2>/dev/null \
  | sed -E -e "s/^[[:space:]]*-[[:space:]]+\"([^\"]+)\".*/\1/" \
           -e "s/^[[:space:]]*-[[:space:]]+'([^']+)'.*/\1/" \
  | sort -u > "$tmp"

mv "$tmp" "$OUT"
trap - EXIT

count=$(wc -l < "$OUT" | tr -d ' ')
echo "wrote $OUT ($count entries)"
