---
title: "last30days Reddit 검색 타임아웃: requests 미설치로 인한 urllib 폴백 및 타임아웃 캐스케이드"
category: developer-experience
date: 2026-03-27
problem_type: developer_experience
component: tooling
root_cause: missing_tooling
resolution_type: environment_setup
severity: medium
tags: [last30days, reddit, python, requests, timeout, urllib, mise, scrape-creators, sops-nix]
module: last30days-skill
---

## Problem

`/last30days` 스킬의 Reddit 검색이 "Found 0 threads"를 반환. ScrapeCreators API로 56개 게시물을 찾았으나 댓글 보강(enrichment) 단계에서 타임아웃이 발생해 모든 결과가 폐기됨.

## Symptoms

- 스크립트 출력: `✓ Reddit Found 0 threads`
- `LAST30DAYS_DEBUG=1`로 확인 시:
  - `[Reddit] After dedup: 56 unique posts` — 검색 자체는 성공
  - `requests library not installed, falling back to urllib`
  - `HTTP Error 500: Internal Server Error` (댓글 enrichment 중)
  - `Reddit search timed out after 60s` → 결과 전부 폐기
- `.env` 파일 퍼미션 755 경고 — sops-nix 심링크의 false positive

## What Didn't Work

- **퍼미션 조사**: `.env`가 755로 표시되어 문제로 보였으나, sops-nix 심링크 특성상 심링크 자체는 항상 755. 타겟 파일(`~/.config/sops-nix/secrets/rendered/last30days.env`)은 600으로 정상.
- **API 키 확인**: 모든 키가 올바르게 설정됨. API 자체는 정상 동작 — 문제는 검색 이후 enrichment 단계에서 발생.

## Solution

```bash
uv pip install --system requests
```

`--system` 플래그 필수: `uv`는 기본적으로 venv에만 설치하지만, last30days는 mise 관리 시스템 Python(3.14.3)으로 실행됨.

검증:

```bash
python3 -c "import requests; print('requests', requests.__version__, '✓')"
# requests 2.33.0 ✓
```

## Why This Works

`search_and_enrich()` 함수가 Reddit 검색 + 댓글 보강을 하나의 `concurrent.futures` Future로 실행하는 구조:

1. Reddit 검색 완료 (56개 발견) → ~20초
2. 댓글 보강 시작 (상위 3개 게시물, 각 30초 타임아웃)
3. `urllib`은 요청마다 새 TCP 연결 생성 (연결 풀링 없음)
4. ScrapeCreators API가 일부 요청에서 HTTP 500 반환 → 재시도로 시간 소모
5. 60초(`--quick`) 타임아웃 초과 → `TimeoutError` → `reddit_items`가 `[]`로 유지

`requests` 설치 후 `urllib3` 기반 연결 풀링으로 TCP 연결을 재사용하면서 enrichment가 타임아웃 내에 완료됨.

## Prevention

- **Python CLI 도구 트러블슈팅 시 `requests` 설치 여부 확인**: `urllib` 폴백은 silent하게 발생하므로 `LAST30DAYS_DEBUG=1`로 확인.
- **타임아웃 구조 이해**: 검색 + enrichment가 단일 future로 묶여 있어, enrichment 지연이 이미 성공한 검색 결과까지 폐기시킴.
- **sops-nix 심링크 퍼미션**: 심링크는 항상 755 표시. 실제 퍼미션은 `ls -la $(readlink -f <file>)`로 타겟 확인.
- **`--quick` 대신 기본 모드 사용**: Reddit 타임아웃이 60초→90초로 늘어나 enrichment 여유 확보.
