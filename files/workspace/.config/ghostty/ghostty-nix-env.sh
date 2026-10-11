#!/bin/sh
# export PATH="/etc/profiles/per-user/$USER/bin:/run/current-system/sw/bin:/nix/var/nix/profiles/default/bin:$PATH"
fish="/etc/profiles/per-user/$USER/bin/fish"

# 로그인 직후 Ghostty가 먼저 뜨면 암호화된 Nix Store 볼륨이 아직 마운트 전이라 fish가 없다.
# 최대 60초 기다리고, 끝내 없으면 macOS 로그인 셸로 연다.
i=0
while [ ! -x "$fish" ] && [ "$i" -lt 600 ]; do
  [ "$i" -eq 0 ] && printf 'Nix Store 마운트를 기다리는 중...\n'
  sleep 0.1
  i=$((i + 1))
done

if [ -x "$fish" ]; then
  exec "$fish" --features no-query-term --login
fi
printf '%s 를 찾지 못해 /bin/zsh로 엽니다.\n' "$fish" >&2
exec /bin/zsh -l
