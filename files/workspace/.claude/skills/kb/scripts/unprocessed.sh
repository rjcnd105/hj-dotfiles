#!/usr/bin/env bash
# List unprocessed Clippings (in Clippings/ but not in kb/.sources).
#
# Usage:
#   unprocessed.sh            # first 20 files
#   unprocessed.sh --all      # all files
#   unprocessed.sh -n 50      # first 50 files
#
# Exit codes:
#   0  success (even if 0 unprocessed)
#   2  vault or Clippings dir missing
#
# Token efficiency: reads .sources and Clippings/ listing in shell, emits diff only.
# Assumes Clipping filenames contain no newlines (realistic for Obsidian Web Clipper).

set -euo pipefail

VAULT="${KB_VAULT:-/Users/hj/Library/Mobile Documents/iCloud~md~obsidian/Documents/Brain}"
CLIPPINGS="$VAULT/Clippings"
SOURCES="$VAULT/kb/.sources"

LIMIT=20
if [[ "${1:-}" == "--all" ]]; then
  LIMIT=0
elif [[ "${1:-}" == "-n" && -n "${2:-}" ]]; then
  LIMIT="$2"
fi

if [[ ! -d "$CLIPPINGS" ]]; then
  echo "error: Clippings dir missing: $CLIPPINGS" >&2
  exit 2
fi

# List Clippings/*.md basenames via shell glob.
shopt -s nullglob
clip_files=("$CLIPPINGS"/*.md)
shopt -u nullglob

clip_list=$(
  for f in "${clip_files[@]}"; do
    echo "${f##*/}"
  done | sort
)

# Load ingested Clipping basenames from .sources (strip "Clippings/" prefix).
if [[ -f "$SOURCES" ]]; then
  src_list=$(grep -E '^Clippings/' "$SOURCES" \
    | sed 's|^Clippings/||' \
    | sort -u)
else
  src_list=""
fi

# Diff: in clip_list but not in src_list.
diff_out=$(comm -23 <(echo "$clip_list") <(echo "$src_list"))

if [[ $LIMIT -gt 0 ]]; then
  echo "$diff_out" | head -n "$LIMIT"
  total=$(echo "$diff_out" | grep -cv '^$' 2>/dev/null || echo 0)
  if [[ $total -gt $LIMIT ]]; then
    echo "... ($((total - LIMIT)) more; rerun with --all)"
  fi
else
  echo "$diff_out"
fi
