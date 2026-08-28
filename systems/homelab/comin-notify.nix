{
  config,
  lib,
  pkgs,
  ...
}:
let
  # comin이 배포 시도 후 COMIN_* 환경변수와 함께 실행한다 (comin 서비스 = root).
  # 토큰이 argv/store에 남지 않도록 curl 설정은 stdin, 본문 값은 파일로만 전달한다
  # (thermal-alert와 같은 원칙).
  notify = pkgs.writeShellApplication {
    name = "comin-telegram-notify";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.curl
    ];
    text = ''
      token_file=${config.sops.secrets.TELEGRAM_BOT_TOKEN.path}
      chat_id_file=${config.sops.secrets.TELEGRAM_CHAT_ID.path}
      # 알림 실패가 comin 배포 기록을 실패로 만들면 안 된다.
      [ -r "$token_file" ] && [ -r "$chat_id_file" ] || exit 0

      status="''${COMIN_STATUS:-unknown}"
      sha="''${COMIN_GIT_SHA:-unknown}"
      first_line="''${COMIN_GIT_MSG:-}"
      first_line="''${first_line%%$'\n'*}"

      if [ "$status" = "done" ]; then
        text="✅ homelab activated ''${sha:0:8}: $first_line"
      else
        text="❌ homelab deploy $status ''${sha:0:8}: $first_line"
        if [ -n "''${COMIN_ERROR_MSG:-}" ]; then
          text=$(printf '%s\n%s' "$text" "''${COMIN_ERROR_MSG:0:500}")
        fi
      fi

      umask 077
      workdir=$(mktemp -d)
      trap 'rm -rf "$workdir"' EXIT
      printf '%s' "$text" > "$workdir/text"
      tr -d '\n' < "$chat_id_file" > "$workdir/chat"

      printf 'url = "https://api.telegram.org/bot%s/sendMessage"\n' \
        "$(cat "$token_file")" |
        curl -fsS --config - \
          --connect-timeout 5 --max-time 15 --retry 2 \
          --data-urlencode "chat_id@$workdir/chat" \
          --data-urlencode "text@$workdir/text" \
          -o /dev/null || {
        echo "comin-telegram-notify: send failed" >&2
        exit 0
      }
    '';
  };
in
{
  services.comin.postDeploymentCommand = lib.getExe notify;
}
