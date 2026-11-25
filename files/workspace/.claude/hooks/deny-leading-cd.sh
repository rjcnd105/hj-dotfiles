#!/bin/sh
# PreToolUse(Bash) 훅. `cd <dir> && ...`처럼 cd로 시작하는 복합 명령을 막고 고쳐 쓸 방법을 돌려준다.
# Claude Code auto 모드 분류기가 이런 명령을 자주 막아서(2026-11-25 집계: 차단 35건 중 12건),
# 분류기까지 가기 전에 바로 되돌려 보내는 편이 빠르다. cd만 단독으로 쓴 명령은 그대로 둔다.
set -f

input=$(cat)
case "$input" in *'"cd '*) ;; *) exit 0 ;; esac

cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty')
printf '%s' "$cmd" | grep -Eq '^[[:space:]]*cd[[:space:]]+[^;&|]*(&&|;|\|\|)' || exit 0

jq -cn --arg r 'cd로 시작하는 복합 명령은 자동 승인 판정에서 막히기 쉽습니다. cd 없이 절대 경로나 git -C, npm --prefix 같은 옵션으로 고쳐 다시 실행하세요. 폴더 이동이 꼭 필요하면 cd만 먼저 따로 실행하세요.' \
  '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
