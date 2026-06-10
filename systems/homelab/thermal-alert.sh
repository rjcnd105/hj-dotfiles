set -eu

credential_dir="${CREDENTIALS_DIRECTORY:?missing systemd credentials directory}"
telegram_bot_token="$(cat "$credential_dir/telegram-bot-token")"
telegram_chat_id="$(cat "$credential_dir/telegram-chat-id")"

# These defaults are production values. The environment overrides exist so the
# flake smoke test can exercise the same script without touching /sys, /proc, or
# Telegram.
threshold_millic="${THERMAL_ALERT_THRESHOLD_MILLIC:-85000}"
cooldown_seconds="${THERMAL_ALERT_COOLDOWN_SECONDS:-1800}"
state_dir="${STATE_DIRECTORY:-/var/lib/homelab-thermal-alert}"
runtime_dir="${RUNTIME_DIRECTORY:-$state_dir}"
last_alert_file="$state_dir/last-alert-epoch"
hwmon_root="${HWMON_ROOT:-/sys/class/hwmon}"
proc_root="${PROC_ROOT:-/proc}"
curl_bin="${CURL_BIN:-curl}"
ps_bin="${PS_BIN:-ps}"

max_temp=-1
max_name=""
max_label=""

# The fan incident tracked the AMD CPU package temperature at k10temp/Tctl.
# /sys/class/thermal on this host only exposes ACPI/Wi-Fi zones, so use hwmon
# directly and ignore unrelated sensors such as NVMe and amdgpu.
for input in "$hwmon_root"/hwmon*/temp*_input; do
  [ -e "$input" ] || continue

  hwmon_dir="$(dirname "$input")"
  name="$(cat "$hwmon_dir/name" 2>/dev/null || true)"
  label_file="${input%_input}_label"
  label="$(cat "$label_file" 2>/dev/null || echo temp)"
  value="$(cat "$input" 2>/dev/null || true)"

  case "$value" in
    "" | *[!0-9]*) continue ;;
  esac

  if [ "$name" = "k10temp" ] && { [ "$label" = "Tctl" ] || [ "$label" = "Tdie" ] || [ "$label" = "temp" ]; }; then
    if [ "$value" -gt "$max_temp" ]; then
      max_temp="$value"
      max_name="$name"
      max_label="$label"
    fi
  fi
done

if [ "$max_temp" -lt 0 ]; then
  # Failing the unit makes a sensor/driver regression visible in systemd instead
  # of silently disabling thermal alerting.
  echo "homelab thermal alert: no k10temp CPU sensor found" >&2
  exit 1
fi

temp_c=$((max_temp / 1000))
temp_dec=$(((max_temp % 1000) / 100))

if [ "$max_temp" -lt "$threshold_millic" ]; then
  exit 0
fi

if [ -n "${NOW_EPOCH:-}" ]; then
  now="$NOW_EPOCH"
else
  now="$(date +%s)"
fi

last_alert=0
if [ -r "$last_alert_file" ]; then
  last_alert="$(cat "$last_alert_file" 2>/dev/null || echo 0)"
fi

# Invalid or partially written cooldown state should not block future alerts.
case "$last_alert" in
  "" | *[!0-9]*) last_alert=0 ;;
esac

if [ $((now - last_alert)) -lt "$cooldown_seconds" ]; then
  exit 0
fi

hostname="$(cat "$proc_root/sys/kernel/hostname")"
load="$(awk '{print $1" "$2" "$3}' "$proc_root/loadavg")"
top_cpu="$("$ps_bin" -eo pcpu=,comm= --sort=-pcpu | awk 'NR==1 {printf "%s%% %s", $1, $2}')"

message="homelab CPU temperature alert
host: $hostname
sensor: $max_name/$max_label
temperature: $temp_c.$temp_dec C
threshold: $((threshold_millic / 1000)) C
loadavg: $load
top_cpu: $top_cpu"

# Feed Telegram data through files/stdin rather than argv. The bot token never
# appears in process arguments, and the transient chat/message files live under
# systemd's 0700 RuntimeDirectory.
umask 077
request_dir="$runtime_dir/request.$$"
mkdir -p "$request_dir"
trap 'rm -rf "$request_dir"' EXIT
chat_id_file="$request_dir/chat-id"
message_file="$request_dir/message"
response_file="$request_dir/response"

printf '%s' "$telegram_chat_id" > "$chat_id_file"
printf '%s' "$message" > "$message_file"

if http_code="$(
  printf 'url = "https://api.telegram.org/bot%s/sendMessage"\n' "$telegram_bot_token" |
    "$curl_bin" -sS \
      --config - \
      --max-time 10 \
      --retry 2 \
      --data-urlencode "chat_id@$chat_id_file" \
      --data-urlencode "text@$message_file" \
      --output "$response_file" \
      --write-out '%{http_code}'
)"; then
  :
else
  curl_status=$?
  echo "homelab thermal alert: Telegram send failed, curl exited with status $curl_status (HTTP ${http_code:-000})" >&2
  exit 1
fi

case "$http_code" in
  2*) ;;
  *)
    echo "homelab thermal alert: Telegram send failed with HTTP $http_code" >&2
    if [ -s "$response_file" ]; then
      head -c 500 "$response_file" >&2
      echo >&2
    fi
    exit 1
    ;;
esac

last_alert_tmp="$state_dir/last-alert-epoch.$$"
# Atomic rename avoids leaving a truncated cooldown file if the service is
# interrupted during the write.
printf '%s\n' "$now" > "$last_alert_tmp"
mv -f "$last_alert_tmp" "$last_alert_file"
