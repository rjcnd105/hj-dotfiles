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
# 링크할 폴더 배열 (프로젝트 루트 기준 상대 경로)
FOLDERS=(
  ".config/opencode/agent"
  ".config/opencode/plugin"
  ".config/opencode/skill"
)

# 소스 베이스 경로
SOURCE_BASE="$PROJECT_ROOT/files/workspace"
# 타겟 베이스 경로
TARGET_BASE="$HOME"

for folder in "${FOLDERS[@]}"; do
  source_path="$SOURCE_BASE/$folder"
  target_path="$TARGET_BASE/$folder"

  # 소스 폴더 존재 확인
  if [[ ! -d "$source_path" ]]; then
    echo "⚠️  소스 폴더가 존재하지 않습니다: $source_path"
    continue
  fi

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
