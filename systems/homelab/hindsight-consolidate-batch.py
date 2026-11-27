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


def load_api_key() -> str:
    cred_dir = os.environ.get("CREDENTIALS_DIRECTORY", "")
    cred_path = os.path.join(cred_dir, "hindsight-api-key") if cred_dir else ""
    if cred_path and os.path.isfile(cred_path):
        with open(cred_path, encoding="utf-8") as f:
            key = f.read().strip()
            if key:
                return key
    key = os.environ.get("HINDSIGHT_API_KEY", "").strip()
    if key:
        return key
    raise RuntimeError("hindsight-api-key credential not readable")


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
    for pending, bank_id, reason in eligible:
        elapsed = time.monotonic() - start_mono
        if elapsed >= MAX_RUNTIME_SECONDS:
            print(f"BUDGET reached ({elapsed:.0f}s >= {MAX_RUNTIME_SECONDS}s); deferring {bank_id} and remaining banks.")
            break

        encoded = urllib.parse.quote(bank_id, safe="")
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
                        print(
                            f"DONE {bank_id}: op={op_id} status={status} "
                            f"obs={stats.get('total_observations')} pending={rem_pending} "
                            f"pending_ops={rem_ops} at +{elapsed:.0f}s"
                        )
                        break
            except (urllib.error.URLError, TimeoutError, json.JSONDecodeError) as exc:
                print(f"WARN {bank_id}: poll error (will retry): {exc}", file=sys.stderr)

            if elapsed >= MAX_RUNTIME_SECONDS + 300:
                print(f"STOP waiting on {bank_id} after +{elapsed:.0f}s; server will finish current round.")
                break

    if failures:
        print(f"Finished with {len(failures)} failure(s): {'; '.join(failures)}", file=sys.stderr)
        return 1
    print(f"Finished cleanly in {time.monotonic() - start_mono:.0f}s.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
