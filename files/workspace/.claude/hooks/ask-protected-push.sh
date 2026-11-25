#!/bin/sh
# PreToolUse(Bash) 훅. ~/work/gm 저장소에서 보호 브랜치로 push 할 때만 확인을 요청한다.
# 그 밖의 명령은 아무것도 출력하지 않고 끝내서 기존 권한 판단(allow 규칙, auto 분류기)에 맡긴다.
# 판단이 애매하면 묻는 쪽으로 기운다. 잘못 물어도 한 번 승인하면 되지만, 놓치면 되돌릴 수 없다.
set -f

input=$(cat)
case "$input" in *push*) ;; *) exit 0 ;; esac

cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty')
cwd=$(printf '%s' "$input" | jq -r '.cwd // empty')
[ -d "$cwd" ] || cwd=$PWD

protected='main|dev|master|stg-frontend'
sp='[[:space:]]'
# push 앞에 올 수 있는 전역 옵션: -C <dir>, -c <k=v>, -R <dir>, --flag[=value]
opt="($sp+(-[CcR]$sp+[^[:space:]]+|--?[[:alnum:]-]+(=[^[:space:]]+)?))*"

# `git push …`, `git -C x push …`, `jj git push …` 조각을 뽑는다. 커밋 메시지 속 "push" 는 걸리지 않는다.
segments=$(printf '%s\n' "$cmd" |
  grep -oE "(^|[^[:alnum:]_./-])(git|jj)$opt$sp+(git$sp+)?push(${sp}[^;&|]*)?")
[ -n "$segments" ] || exit 0

ask() {
  jq -cn --arg r "$1" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"ask",permissionDecisionReason:$r}}'
  exit 0
}

while IFS= read -r seg; do
  [ -n "$seg" ] || continue
  args=${seg#*push}

  # 이 push 가 실행될 폴더: -C/-R 값, 없으면 앞서 나온 마지막 cd, 그것도 없으면 세션 cwd
  dir=$(printf '%s' "$seg" | sed -nE "s/.*$sp-[CR]$sp+([^[:space:]]+).*/\1/p")
  if [ -z "$dir" ]; then
    before=${cmd%%"$seg"*}
    dir=$(printf '%s\n' "$before" |
      grep -oE "(^|[;&|({[:space:]])cd$sp+[^;&|[:space:]]+" | tail -1 | sed -E "s/.*cd$sp+//")
  fi
  dir=$(printf '%s' "$dir" | tr -d "\"'")
  case "$dir" in
    '~'*) dir="$HOME${dir#\~}" ;;
    '$HOME'*) dir="$HOME${dir#\$HOME}" ;;
  esac
  case "$dir" in
    '') dir=$cwd ;;
    /*) ;;
    *) dir="$cwd/$dir" ;;
  esac
  # 변수로 적은 경로처럼 풀 수 없는 폴더면 cwd 로 보고, 범위 판단에 명령 전체를 함께 본다.
  hint=
  [ -d "$dir" ] || { dir=$cwd; hint=$cmd; }

  # 범위: ~/work/gm 아래 저장소. 다른 곳에 만든 worktree 도 원본 .git 위치로 잡는다.
  common=$(git -C "$dir" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)
  case "$dir/ $common/ $hint" in */work/gm/*) ;; *) continue ;; esac

  if printf '%s' "$args" |
    grep -Eq "(^|[[:space:]:+'\"]|refs/heads/)($protected)(\$|[[:space:]:'\"])"; then
    ask "보호 브랜치($protected)를 가리키는 push 입니다."
  fi
  if printf '%s' "$args" | grep -Eq -- "(^|$sp)--(all|mirror|tracked|deleted)($sp|\$)"; then
    ask "여러 브랜치를 한꺼번에 보내는 push 라 보호 브랜치($protected)가 포함될 수 있습니다."
  fi

  case "$seg" in
    jj* | ?jj*)
      # bookmark 를 고르지 않은 jj git push 는 무엇이 나갈지 명령만으로 알 수 없다.
      printf '%s' "$args" | grep -Eq -- "(^|$sp)(-b|--bookmark|-c|--change|--named)($sp|=|\$)" ||
        ask "보낼 bookmark 를 지정하지 않은 jj git push 입니다. 보호 브랜치($protected)가 포함될 수 있습니다."
      continue
      ;;
  esac

  # 대상 브랜치를 적지 않았거나 HEAD 로 적은 git push 는 현재 브랜치와 upstream 을 본다.
  positional=$(printf '%s\n' $args | grep -vE '^(-|[0-9]*[<>])' | grep -c .)
  if [ "$positional" -lt 2 ] || printf '%s\n' $args | grep -Eq '^(HEAD|@)(:|$)'; then
    branch=$(git -C "$dir" branch --show-current 2>/dev/null)
    upstream=$(git -C "$dir" rev-parse --abbrev-ref '@{u}' 2>/dev/null)
    if printf '%s\n%s\n' "$branch" "${upstream#*/}" | grep -Eqx "$protected"; then
      ask "현재 브랜치(${branch:-?}, upstream ${upstream:-없음})가 보호 브랜치($protected)입니다."
    fi
  fi
done <<EOF
$segments
EOF

exit 0
