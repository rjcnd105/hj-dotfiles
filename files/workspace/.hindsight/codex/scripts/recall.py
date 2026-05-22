#!/usr/bin/env python3
"""Auto-recall hook for UserPromptSubmit.

Fires before each user prompt. Retrieves relevant memories from Hindsight
and injects them into the Codex context via hookSpecificOutput.additionalContext.

Flow:
  1. Read hook input from stdin (session_id, transcript_path, prompt/user_prompt)
  2. Resolve API URL
  3. Derive bank ID and ensure mission
  4. Compose multi-turn query if recallContextTurns > 1
  5. Truncate to recallMaxQueryChars
  6. Call Hindsight recall API
  7. Format memories and output hookSpecificOutput.additionalContext

Exit codes:
  0 — always (graceful degradation on any error)
"""

import io
import json
import os
import re
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from lib.bank import derive_bank_id, ensure_bank_mission
from lib.client import HindsightClient
from lib.config import debug_log, load_config
from lib.content import (
    compose_recall_query,
    format_current_time,
    format_memories,
    read_transcript,
    truncate_recall_query,
)
from lib.daemon import get_api_url
from lib.state import write_state

LAST_RECALL_STATE = "last_recall.json"

SIMPLE_RECALL_SKIP_PROMPTS = {
    "ok",
    "okay",
    "k",
    "yes",
    "y",
    "no",
    "n",
    "thanks",
    "thank you",
    "continue",
    "proceed",
    "응",
    "ㅇㅇ",
    "ㄱㄱ",
    "그래",
    "좋아",
    "네",
    "예",
    "아니",
    "고마워",
    "확인",
    "알겠어",
    "알겠습니다",
    "진행",
    "계속",
    "해줘",
    "그렇게 해",
    "그걸로",
    "맞아",
}

MEMORY_RECALL_TRIGGER_RE = re.compile(
    r"(hindsight|memory|memories|remember|recall|context|history|previous|before|"
    r"session|기억|메모리|회상|컨텍스트|맥락|히스토리|이전|전에|과거|세션)"
)

CODE_RECALL_TRIGGER_RE = re.compile(
    r"(`[^`]+`|/[A-Za-z0-9_.~/-]+|\b[A-Z]+-\d+\b|#[0-9]+|"
    r"\.(?:py|js|ts|tsx|jsx|json|toml|nix|md|rb|go|rs|ex|exs|yml|yaml)\b)"
)

ASCII_ANCHOR_RE = re.compile(r"\b[A-Za-z][A-Za-z0-9_.:/-]{2,}\b")

MEMORY_ONLY_TERMS = {
    "hindsight",
    "memory",
    "memories",
    "remember",
    "recall",
    "context",
    "history",
    "previous",
    "before",
    "session",
}

GENERIC_ANCHOR_TERMS = {
    "data",
    "related",
    "irrelevant",
    "relevant",
    "many",
    "after",
    "then",
    "thing",
    "things",
    "stuff",
    "issue",
    "problem",
}

KOREAN_TECH_ANCHOR_TERMS = (
    "홈랩",
    "배포",
    "커밋",
    "브랜치",
    "북마크",
    "워크트리",
    "설정",
    "훅",
    "스킬",
    "플러그인",
    "프로세스",
    "좀비",
    "쿨러",
    "팬",
    "메모리",
    "부하",
    "오류",
    "로그",
    "서비스",
    "런타임",
    "문서",
    "리뷰",
    "보안",
    "테스트",
    "마이그레이션",
    "뱅크",
    "토큰",
    "러너",
    "경계",
    "결정",
)

KOREAN_TECH_ANCHOR_RE = re.compile("|".join(re.escape(term) for term in KOREAN_TECH_ANCHOR_TERMS))

BROAD_FILTER_ANCHORS = {
    "codex",
    "hindsight",
    "homelab",
    "nix-dots",
}

ANCHOR_ALIASES = {
    "배포": {"deploy", "deployment", "배포"},
    "커밋": {"commit", "커밋"},
    "브랜치": {"branch", "브랜치"},
    "북마크": {"bookmark", "북마크"},
    "워크트리": {"worktree", "워크트리"},
    "설정": {"config", "configuration", "settings", "설정"},
    "훅": {"hook", "hooks", "훅"},
    "스킬": {"skill", "skills", "스킬"},
    "플러그인": {"plugin", "plugins", "플러그인"},
    "프로세스": {"process", "processes", "프로세스"},
    "좀비": {"zombie", "좀비"},
    "쿨러": {"cooler", "fan", "팬", "쿨러"},
    "팬": {"fan", "팬", "쿨러"},
    "메모리": {"memory", "mem", "ram", "메모리"},
    "부하": {"load", "usage", "부하"},
    "오류": {"error", "failure", "오류"},
    "로그": {"log", "logs", "로그"},
    "서비스": {"service", "systemd", "서비스"},
    "런타임": {"runtime", "런타임"},
    "문서": {"doc", "docs", "document", "문서"},
    "리뷰": {"review", "리뷰"},
    "보안": {"security", "보안"},
    "테스트": {"test", "tests", "테스트"},
    "마이그레이션": {"migration", "migrations", "마이그레이션"},
    "뱅크": {"bank", "banks", "뱅크"},
    "토큰": {"token", "tokens", "토큰"},
    "러너": {"runner", "runners", "러너"},
    "경계": {"boundary", "boundaries", "경계"},
    "결정": {"decision", "decisions", "결정"},
    "cpu": {"cpu", "processor", "프로세서"},
    "memory": {"memory", "ram", "메모리"},
}


def has_concrete_recall_anchor(text):
    """Return True when the prompt has a concrete project/code anchor.

    Hindsight recall is expensive in attention budget. Vague anaphora like
    "that thing from before" or meta-comments about memory quality should not
    pull unrelated recent memories into the prompt.
    """
    return bool(extract_recall_anchors(text))


def extract_recall_anchors(text):
    anchors = set()
    if not isinstance(text, str):
        return anchors

    if CODE_RECALL_TRIGGER_RE.search(text):
        anchors.update(
            match.strip("`")
            for match in CODE_RECALL_TRIGGER_RE.findall(text)
        )

    lower = text.lower()
    for token in ASCII_ANCHOR_RE.findall(lower):
        if token in MEMORY_ONLY_TERMS or token in GENERIC_ANCHOR_TERMS:
            continue
        anchors.add(token)

    anchors.update(match.group(0) for match in KOREAN_TECH_ANCHOR_RE.finditer(text))
    if "메모리" in anchors and "hindsight" in lower:
        system_memory_terms = (
            "homelab",
            "cpu",
            "ram",
            "프로세스",
            "좀비",
            "쿨러",
            "팬",
            "부하",
            "홈랩",
        )
        if not any(term in lower or term in text for term in system_memory_terms):
            anchors.discard("메모리")
    return {anchor for anchor in anchors if anchor}


def anchor_terms(anchor):
    return ANCHOR_ALIASES.get(anchor, {anchor})


def result_matches_anchor(result, anchors):
    text = result.get("text", "") if isinstance(result, dict) else ""
    lower = text.lower()
    return any(
        term.lower() in lower
        for anchor in anchors
        for term in anchor_terms(anchor)
    )


def filter_results_by_anchor(results, prompt):
    anchors = extract_recall_anchors(prompt)
    specific_anchors = anchors - BROAD_FILTER_ANCHORS
    required_anchors = specific_anchors or anchors
    if not required_anchors:
        return results
    return [result for result in results if result_matches_anchor(result, required_anchors)]


def write_empty_recall_state(bank_id, reason, raw_result_count=0):
    write_state(
        LAST_RECALL_STATE,
        {
            "context": "",
            "saved_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
            "bank_id": bank_id,
            "result_count": 0,
            "raw_result_count": raw_result_count,
            "skipped": reason,
        },
    )


def recall_skip_reason(prompt, config):
    """Return a reason when a prompt should not spend recall tokens."""
    if not config.get("recallSkipShortPrompts", True):
        return None

    text = " ".join(prompt.strip().split())
    if not text:
        return "empty prompt"

    lower = text.lower()
    if lower in SIMPLE_RECALL_SKIP_PROMPTS:
        return "simple acknowledgement"

    has_anchor = has_concrete_recall_anchor(text)
    if config.get("recallRequireQueryAnchor", False) and not has_anchor:
        return "no concrete recall anchor"

    try:
        max_chars = int(config.get("recallSkipMaxChars", 40) or 0)
    except (TypeError, ValueError):
        max_chars = 40

    if max_chars <= 0 or len(text) > max_chars:
        return None

    if has_anchor or MEMORY_RECALL_TRIGGER_RE.search(lower) or CODE_RECALL_TRIGGER_RE.search(text):
        return None

    return f"short prompt ({len(text)} <= {max_chars} chars)"


def main():
    if os.name == "nt":
        if hasattr(sys.stdout, "buffer"):
            sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
        if hasattr(sys.stderr, "buffer"):
            sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding="utf-8", errors="replace")

    config = load_config()

    if not config.get("autoRecall"):
        debug_log(config, "Auto-recall disabled, exiting")
        return

    # Read hook input from stdin
    try:
        hook_input = json.load(sys.stdin)
    except (json.JSONDecodeError, EOFError):
        print("[Hindsight] Failed to read hook input", file=sys.stderr)
        return

    debug_log(config, f"Hook input keys: {list(hook_input.keys())}")

    # Extract user query — accept both "prompt" and "user_prompt" defensively
    prompt = (hook_input.get("prompt") or hook_input.get("user_prompt") or "").strip()
    if not prompt:
        debug_log(config, "Prompt empty for recall, skipping")
        return

    skip_reason = recall_skip_reason(prompt, config)
    if skip_reason:
        debug_log(config, f"Skipping recall: {skip_reason}")
        write_empty_recall_state(derive_bank_id(hook_input, config), skip_reason)
        return

    def _dbg(*a):
        debug_log(config, *a)

    try:
        api_url = get_api_url(config, debug_fn=_dbg, allow_daemon_start=False)
    except RuntimeError as e:
        print(f"[Hindsight] {e}", file=sys.stderr)
        return

    api_token = config.get("hindsightApiToken")
    try:
        client = HindsightClient(api_url, api_token)
    except ValueError as e:
        print(f"[Hindsight] Invalid API URL: {e}", file=sys.stderr)
        return

    bank_id = derive_bank_id(hook_input, config)
    ensure_bank_mission(client, bank_id, config, debug_fn=_dbg)

    # Multi-turn query composition
    recall_context_turns = config.get("recallContextTurns", 1)
    recall_max_query_chars = config.get("recallMaxQueryChars", 800)
    recall_roles = config.get("recallRoles", ["user", "assistant"])

    if recall_context_turns > 1:
        transcript_path = hook_input.get("transcript_path", "")
        messages = read_transcript(transcript_path)
        debug_log(config, f"Multi-turn context: {recall_context_turns} turns, {len(messages)} messages")
        query = compose_recall_query(prompt, messages, recall_context_turns, recall_roles)
    else:
        query = prompt

    query = truncate_recall_query(query, prompt, recall_max_query_chars)
    if len(query) > recall_max_query_chars:
        query = query[:recall_max_query_chars]
    query = query.encode("utf-8", errors="ignore").decode("utf-8")

    current_time = format_current_time()
    preamble = config.get("recallPromptPreamble", "")
    recall_timeout = config.get("recallTimeout", 10)

    debug_log(config, f"Recalling from bank '{bank_id}', query length: {len(query)}, timeout: {recall_timeout}s")
    try:
        response = client.recall(
            bank_id=bank_id,
            query=query,
            max_tokens=config.get("recallMaxTokens", 1024),
            budget=config.get("recallBudget", "mid"),
            types=config.get("recallTypes"),
            timeout=recall_timeout,
        )
    except Exception as e:
        print(f"[Hindsight] Recall failed: {e}", file=sys.stderr)
        return

    results = response.get("results", [])
    if not results:
        debug_log(config, "No memories found")
        write_empty_recall_state(bank_id, "no memories found")
        return

    raw_result_count = len(results)
    if config.get("recallFilterResultsByAnchor", False):
        results = filter_results_by_anchor(results, prompt)
        if not results:
            debug_log(config, f"No memories matched prompt anchors from {raw_result_count} raw results")
            write_empty_recall_state(bank_id, "no memory matched prompt anchors", raw_result_count)
            return

    if not results:
        return

    debug_log(config, f"Injecting {len(results)} memories")

    memories_formatted = format_memories(results)

    context_message = (
        f"<hindsight_memories>\n"
        f"{preamble}\n"
        f"Current time - {current_time}\n\n"
        f"{memories_formatted}\n"
        f"</hindsight_memories>"
    )

    write_state(
        LAST_RECALL_STATE,
        {
            "context": context_message,
            "saved_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
            "bank_id": bank_id,
            "result_count": len(results),
            "raw_result_count": raw_result_count,
        },
    )

    # Output JSON for Codex hook system
    output = {
        "hookSpecificOutput": {
            "hookEventName": "UserPromptSubmit",
            "additionalContext": context_message,
        }
    }
    json.dump(output, sys.stdout)


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        print(f"[Hindsight] Unexpected error in recall: {e}", file=sys.stderr)
        try:
            from lib.config import load_config

            sys.exit(2 if load_config().get("debug") else 0)
        except Exception:
            sys.exit(0)
