#!/usr/bin/env bash

set -euo pipefail

find_project_root() {
  local dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  while [[ "$dir" != "/" ]]; do
    if [[ -f "$dir/flake.nix" ]]; then
      echo "$dir"
      return 0
    fi
    dir="$(dirname "$dir")"
  done
  echo "❌ flake.nix를 찾을 수 없습니다!" >&2
  exit 1
}

PROJECT_ROOT="$(find_project_root)"
# 소스 베이스 경로
SOURCE_BASE="$PROJECT_ROOT/files/$USER_HOST"
# 타겟 베이스 경로
TARGET_BASE="$HOME"

# .manual-link 마커 파일이 있는 폴더들을 자동으로 수집
FOLDERS=()
while IFS= read -r -d '' marker_file; do
  # .manual-link 파일의 부모 디렉토리 경로를 SOURCE_BASE 기준 상대 경로로 변환
  folder_path="$(dirname "$marker_file")"
  relative_path="${folder_path#$SOURCE_BASE/}"
  FOLDERS+=("$relative_path")
done < <(find "$SOURCE_BASE" -name ".manual-link" -type f -print0)

if [[ ${#FOLDERS[@]} -eq 0 ]]; then
  echo "⚠️  .manual-link 마커 파일이 있는 폴더를 찾을 수 없습니다."
  exit 0
fi

echo "📂 발견된 수동 링크 폴더들:"
for folder in "${FOLDERS[@]}"; do
  echo "   - $folder"
done
echo ""

for folder in "${FOLDERS[@]}"; do
  source_path="$SOURCE_BASE/$folder"
  target_path="$TARGET_BASE/$folder"

  # 타겟 부모 디렉토리 생성
  target_parent="$(dirname "$target_path")"
  mkdir -p "$target_parent"

  # 기존 타겟이 있으면 삭제 (심볼릭 링크, 파일, 폴더 모두)
  if [[ -e "$target_path" || -L "$target_path" ]]; then
    echo "🗑️  기존 경로 삭제: $target_path"
    rm -rf "$target_path"
  fi

  # 심볼릭 링크 생성
  ln -s "$source_path" "$target_path"
  echo "✅ 링크 생성: $target_path -> $source_path"
done

echo ""
echo "🎉 모든 폴더 링크 완료!"
