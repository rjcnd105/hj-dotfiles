#!/bin/sh
set -f

input=$(cat)
case "$input" in *push*) ;; *) exit 0 ;; esac

ask_static() {
  printf '%s\n' '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"push 명령을 안전하게 검증할 수 없어 확인이 필요합니다(jq 오류 또는 미설치)."}}'
  exit 0
}

ask() {
  jq -cn --arg r "$1" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"ask",permissionDecisionReason:$r}}' || ask_static
  exit 0
}

command -v jq >/dev/null 2>&1 || ask_static
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty') || ask_static
cwd=$(printf '%s' "$input" | jq -r '.cwd // empty') || ask_static
[ -d "$cwd" ] || cwd=$PWD

protected='main|dev|master|stg-frontend'
sp='[[:space:]]'
opt="($sp+(-[CcR]$sp+[^[:space:]]+|--?[[:alnum:]-]+(=[^[:space:]]+)?))*"

segments=$(printf '%s\n' "$cmd" |
  grep -oE "(^|[^[:alnum:]_./-])(git|jj)$opt$sp+(git$sp+)?push(${sp}[^;&|]*)?")
[ -n "$segments" ] || exit 0

is_protected_ref() {
  ref=$(printf '%s' "$1" | sed -E "s/^[\"']+//; s/[\"']+\$//; s/^\+//; s#^refs/heads/##")
  printf '%s' "$ref" | grep -Eqx "$protected"
}

check_refspec_safe() {
  spec=$(printf '%s' "$1" | sed -E "s/^[\"']+//; s/[\"']+\$//")
  case "$spec" in
    *:*)
      src=${spec%%:*}
      dst=${spec#*:}
      ;;
    *)
      src=$spec
      dst=$spec
      ;;
  esac
  src_clean=$(printf '%s' "$src" | sed -E 's/^\+//; s#^refs/heads/##')
  dst_clean=$(printf '%s' "$dst" | sed -E 's/^\+//; s#^refs/heads/##')

  if [ -z "$dst_clean" ]; then
    ask "대상 ref가 비어 있는 push($spec)입니다. 확인이 필요합니다."
  fi
  if is_protected_ref "$src_clean" || is_protected_ref "$dst_clean"; then
    ask "보호 브랜치($protected)를 가리키는 push($spec)입니다."
  fi
  case "$src_clean" in
    HEAD | @ | HEAD~* | HEAD^* | @~* | @^*)
      return 1
      ;;
  esac
  case "$dst_clean" in
    HEAD | @)
      return 1
      ;;
  esac
  case "$spec" in
    *'*'* | *'$'* | *'`'*)
      ask "동적이거나 와일드카드가 포함된 push refspec($spec)입니다."
      ;;
  esac
  return 0
}

check_current_branch_safe() {
  target_dir=$1
  branch=$(git -C "$target_dir" branch --show-current 2>/dev/null)
  upstream=$(git -C "$target_dir" rev-parse --abbrev-ref '@{u}' 2>/dev/null)
  if [ -z "$branch" ]; then
    ask "현재 브랜치를 확인할 수 없어 보호 브랜치($protected) 여부를 보장할 수 없습니다."
  fi
  if is_protected_ref "$branch"; then
    ask "현재 브랜치($branch)가 보호 브랜치($protected)입니다."
  fi
  if [ -n "$upstream" ] && is_protected_ref "${upstream#*/}"; then
    ask "현재 upstream($upstream)이 보호 브랜치($protected)입니다."
  fi
}

while IFS= read -r seg; do
  [ -n "$seg" ] || continue
  args=${seg#*push}

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

  unresolved_dir_cmd_fallback=
  [ -d "$dir" ] || { dir=$cwd; unresolved_dir_cmd_fallback=$cmd; }

  common=$(git -C "$dir" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)
  case "$dir/ $common/ $unresolved_dir_cmd_fallback" in */work/gm/*) ;; *) continue ;; esac

  if printf '%s' "$args" | grep -Eq -- "(^|$sp)(--all|--mirror|--tracked|--deleted|--tags)($sp|\$)"; then
    ask "여러 브랜치/태그를 한꺼번에 보내는 push라 보호 브랜치($protected)가 포함될 수 있습니다."
  fi

  case "$seg" in
    jj* | ?jj*)
      if ! printf '%s' "$args" | grep -Eq -- "(^|$sp)(-b|--bookmark|-c|--change|--named)($sp|=|\$)"; then
        ask "보낼 bookmark를 지정하지 않은 jj git push입니다. 보호 브랜치($protected)가 포함될 수 있습니다."
      fi
      if printf '%s' "$args" |
        grep -Eq "(^|[[:space:]:=+'\"]|refs/heads/)($protected)(\$|[[:space:]:'\"])"; then
        ask "보호 브랜치($protected)를 가리키는 jj git push입니다."
      fi
      continue
      ;;
  esac

  pos_count=0
  skip_next=0
  need_branch_check=0
  for tok in $args; do
    if [ "$skip_next" -eq 1 ]; then
      skip_next=0
      continue
    fi
    case "$tok" in
      -o | --push-option | --repo | --receive-pack | --exec)
        skip_next=1
        continue
        ;;
      -*)
        continue
        ;;
      [0-9]*'<'* | [0-9]*'>'* | '<'* | '>'*)
        continue
        ;;
    esac
    pos_count=$((pos_count + 1))
    if [ "$pos_count" -ge 2 ]; then
      if ! check_refspec_safe "$tok"; then
        need_branch_check=1
      fi
    fi
  done

  if [ "$pos_count" -lt 2 ] || [ "$need_branch_check" -eq 1 ]; then
    check_current_branch_safe "$dir"
  fi
done <<EOF
$segments
EOF

exit 0
