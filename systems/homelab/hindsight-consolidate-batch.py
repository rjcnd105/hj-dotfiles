#!/usr/bin/env python3
"""Nightly hybrid Hindsight consolidation runner.

Runs sequentially against local Hindsight API (1 bank at a time) for banks with:
  - pending_consolidation >= MIN_PENDING_DAILY (default 8, one full LLM batch), OR
  - pending_consolidation > 0 and last_consolidated_at is older than MAX_AGE_DAYS (default 3) or unset.

Stops queuing new banks once MAX_RUNTIME_SECONDS (default 75 min) elapses so runs
always finish before the 04:30 restic backup.
"""

from __future__ import annotations

import datetime as dt
import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

API_URL = os.environ.get("API_URL", "http://127.0.0.1:18093").rstrip("/")
MIN_PENDING_DAILY = int(os.environ.get("MIN_PENDING_DAILY", "8"))
MAX_AGE_DAYS = float(os.environ.get("MAX_AGE_DAYS", "3"))
MAX_RUNTIME_SECONDS = int(os.environ.get("MAX_RUNTIME_SECONDS", "4500"))
POLL_INTERVAL_SECONDS = int(os.environ.get("POLL_INTERVAL_SECONDS", "15"))


def read_credential(name: str) -> str | None:
    cred_dir = os.environ.get("CREDENTIALS_DIRECTORY", "")
    cred_path = os.path.join(cred_dir, name) if cred_dir else ""
    if cred_path and os.path.isfile(cred_path):
        with open(cred_path, encoding="utf-8") as f:
            val = f.read().strip()
            if val:
                return val
    return None


def load_api_key() -> str:
    key = read_credential("hindsight-api-key") or os.environ.get("HINDSIGHT_API_KEY", "").strip()
    if key:
        return key
    raise RuntimeError("hindsight-api-key credential not readable")


def send_telegram(text: str) -> None:
    token = read_credential("telegram-bot-token")
    chat_id = read_credential("telegram-chat-id")
    if not token or not chat_id:
        print("WARN: telegram credentials unreadable; skipping completion notification", file=sys.stderr)
        return

    payload = urllib.parse.urlencode({"chat_id": chat_id, "text": text[:4000]}).encode("utf-8")
    req = urllib.request.Request(
        f"https://api.telegram.org/bot{token}/sendMessage",
        data=payload,
        headers={"Content-Type": "application/x-www-form-urlencoded"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            if resp.status >= 400:
                print(f"WARN: telegram send returned HTTP {resp.status}", file=sys.stderr)
    except urllib.error.HTTPError as exc:
        print(f"WARN: telegram send failed (HTTP {exc.code})", file=sys.stderr)
    except (urllib.error.URLError, TimeoutError, OSError) as exc:
        # Avoid printing exc details that may include the request URL containing the bot token.
        print(f"WARN: telegram send failed ({type(exc).__name__})", file=sys.stderr)


def format_duration(seconds: float) -> str:
    total = int(round(seconds))
    mins, secs = divmod(total, 60)
    return f"{mins}m {secs}s" if mins else f"{secs}s"


def request_json(api_key: str, method: str, path: str, body: dict | None = None, timeout: int = 30) -> dict:
    data = json.dumps(body).encode("utf-8") if body is not None else None
    headers = {"Authorization": f"Bearer {api_key}"}
    if data is not None:
        headers["Content-Type"] = "application/json"
    req = urllib.request.Request(f"{API_URL}{path}", data=data, headers=headers, method=method)
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        raw = resp.read().decode("utf-8")
        return json.loads(raw) if raw.strip() else {}


def parse_iso_utc(value: str | None) -> dt.datetime | None:
    if not value:
        return None
    normalized = value.replace("Z", "+00:00")
    parsed = dt.datetime.fromisoformat(normalized)
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=dt.timezone.utc)
    return parsed.astimezone(dt.timezone.utc)


def main() -> int:
    dry_run = "--dry-run" in sys.argv[1:]
    api_key = load_api_key()
    start_mono = time.monotonic()
    now_utc = dt.datetime.now(dt.timezone.utc)

    health = request_json(api_key, "GET", "/health", timeout=10)
    if health.get("status") != "healthy":
        print(f"ERROR: Hindsight unhealthy: {health}", file=sys.stderr)
        return 1

    banks_resp = request_json(api_key, "GET", "/v1/default/banks")
    banks = banks_resp.get("banks", [])

    eligible: list[tuple[int, str, str]] = []
    for entry in banks:
        bank_id = entry.get("bank_id") if isinstance(entry, dict) else str(entry)
        encoded = urllib.parse.quote(bank_id, safe="")
        stats = request_json(api_key, "GET", f"/v1/default/banks/{encoded}/stats")
        pending = int(stats.get("pending_consolidation") or 0)
        pending_ops = int(stats.get("pending_operations") or 0)
        last_at = parse_iso_utc(stats.get("last_consolidated_at"))
        age_days = (now_utc - last_at).total_seconds() / 86400.0 if last_at else None

        if pending <= 0:
            continue
        if pending_ops > 0:
            print(f"SKIP {bank_id}: pending={pending} (pending_operations={pending_ops} already active)")
            continue

        if pending >= MIN_PENDING_DAILY:
            reason = f"pending={pending}>={MIN_PENDING_DAILY}"
            eligible.append((pending, bank_id, reason))
        elif age_days is None:
            reason = f"pending={pending}, never_consolidated"
            eligible.append((pending, bank_id, reason))
        elif age_days >= MAX_AGE_DAYS:
            reason = f"pending={pending}, age={age_days:.1f}d>={MAX_AGE_DAYS:g}d"
            eligible.append((pending, bank_id, reason))
        else:
            print(f"DEFER {bank_id}: pending={pending}<{MIN_PENDING_DAILY}, age={age_days:.1f}d<{MAX_AGE_DAYS:g}d")

    eligible.sort(key=lambda item: (item[0], item[1]))
    print(f"Found {len(eligible)} eligible bank(s) out of {len(banks)} total (dry_run={dry_run}).")
    for pending, bank_id, reason in eligible:
        print(f"  QUEUE {bank_id}: {reason}")

    if dry_run or not eligible:
        return 0

    failures: list[str] = []
    completed_lines: list[str] = []
    deferred_banks = 0
    for idx, (pending, bank_id, reason) in enumerate(eligible):
        elapsed = time.monotonic() - start_mono
        if elapsed >= MAX_RUNTIME_SECONDS:
            deferred_banks = len(eligible) - idx
            print(f"BUDGET reached ({elapsed:.0f}s >= {MAX_RUNTIME_SECONDS}s); deferring {bank_id} and remaining banks.")
            break

        encoded = urllib.parse.quote(bank_id, safe="")
        short_bank = bank_id.removeprefix("coding-agent::")
        print(f"START {bank_id} ({reason}) at +{elapsed:.0f}s")
        try:
            resp = request_json(api_key, "POST", f"/v1/default/banks/{encoded}/consolidate", {})
            op_id = resp.get("operation_id")
            if not op_id:
                print(f"WARN {bank_id}: no operation_id returned ({resp})")
                continue
        except (urllib.error.URLError, TimeoutError, json.JSONDecodeError) as exc:
            msg = f"{bank_id}: trigger failed: {exc}"
            print(f"ERROR {msg}", file=sys.stderr)
            failures.append(msg)
            continue

        while True:
            time.sleep(POLL_INTERVAL_SECONDS)
            elapsed = time.monotonic() - start_mono
            try:
                op = request_json(api_key, "GET", f"/v1/default/banks/{encoded}/operations/{op_id}")
                status = op.get("status")
                if status == "failed":
                    msg = f"{bank_id}: op={op_id} failed: {op.get('error_message')}"
                    print(f"ERROR {msg}", file=sys.stderr)
                    failures.append(msg)
                    break
                if op.get("next_retry_at"):
                    msg = (
                        f"{bank_id}: op={op_id} retry-deferred until {op.get('next_retry_at')}: "
                        f"{op.get('error_message')}"
                    )
                    print(f"ERROR {msg}", file=sys.stderr)
                    failures.append(msg)
                    break
                if status in ("completed", "cancelled"):
                    stats = request_json(api_key, "GET", f"/v1/default/banks/{encoded}/stats")
                    rem_pending = int(stats.get("pending_consolidation") or 0)
                    rem_ops = int(stats.get("pending_operations") or 0)
                    # Multi-round banks (>100 facts) auto-requeue the next round. Wait until
                    # the active chain drains or the nightly soft time budget is reached.
                    if rem_ops == 0 or elapsed >= MAX_RUNTIME_SECONDS:
                        obs_count = stats.get("total_observations")
                        print(
                            f"DONE {bank_id}: op={op_id} status={status} "
                            f"obs={obs_count} pending={rem_pending} "
                            f"pending_ops={rem_ops} at +{elapsed:.0f}s"
                        )
                        completed_lines.append(f"- {short_bank}: obs={obs_count}, pending={rem_pending}")
                        break
            except (urllib.error.URLError, TimeoutError, json.JSONDecodeError) as exc:
                print(f"WARN {bank_id}: poll error (will retry): {exc}", file=sys.stderr)

            if elapsed >= MAX_RUNTIME_SECONDS + 300:
                print(f"STOP waiting on {bank_id} after +{elapsed:.0f}s; server will finish current round.")
                completed_lines.append(f"- {short_bank}: 시간 상한 도달 (서버 백그라운드 마무리 중)")
                break

    if failures:
        print(f"Finished with {len(failures)} failure(s): {'; '.join(failures)}", file=sys.stderr)
        return 1

    total_elapsed = time.monotonic() - start_mono
    print(f"Finished cleanly in {total_elapsed:.0f}s.")
    if completed_lines:
        lines = [
            f"✅ homelab hindsight-consolidate 완료 ({format_duration(total_elapsed)})",
            f"처리 {len(completed_lines)}개 bank:",
            *completed_lines,
        ]
        if deferred_banks > 0:
            lines.append(f"남은 대기 bank: {deferred_banks}개 (다음 새벽 이어서 진행)")
        send_telegram("\n".join(lines))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
