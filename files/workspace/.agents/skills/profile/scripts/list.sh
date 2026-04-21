#!/usr/bin/env bash
# Usage: list.sh [profiles_dir]
# Scans ~/.claude/profiles/ for subdirectories containing PROFILE.md
# and prints each profile's name and title.

PROFILES_DIR="${1:-$HOME/.claude/profiles}"

found=0
for dir in "$PROFILES_DIR"/*/; do
  [ -d "$dir" ] || continue
  [ -f "$dir/PROFILE.md" ] || continue
  name=$(basename "$dir")
  title=$(grep -m1 '^# ' "$dir/PROFILE.md" | sed 's/^# //')
  echo "- $name — $title"
  found=1
done

if [ "$found" -eq 0 ]; then
  echo "사용 가능한 프로필이 없습니다. ~/.claude/profiles/<name>/PROFILE.md 형식으로 프로필을 생성하세요."
fi
