---
date: 2026-03-26
topic: nix-zed-lsp
focus: Nix 파일의 Zed 에디터 자동완성/에러표시/옵션 완성 개선
---

# Ideation: Nix Zed LSP DX 개선

## Codebase Context

- **프로젝트:** nix-dots — Nix flake 기반 dotfiles (nix-darwin + home-manager, aarch64-darwin)
- **현재 상태:** nil이 활성 LSP, nixd는 `!nixd`로 비활성. nil은 `formatting.command`만 설정되어 degraded mode
- **핵심 문제:** nil은 구조적으로 flake 입력 해석/옵션 경로 완성 불가. nixd v2.x는 `.nixd.json` 폐기, workspace/configuration만 읽음
- **인프라 현황:** direnv + nix-direnv 활성화 상태이나 `.envrc`/devShell 없어 파이프라인 비활성
- **도구 현황:** nil 개발 정체 (10개월 릴리스 갭) vs nixd 활발 (v2.9.0, 2026-02)

## Ranked Ideas

### 1. nixd 전환 + Zed LSP settings로 옵션 평가 설정
**Description:** nil→nixd 전환. Zed `lsp.nixd.settings`에 nixpkgs/nix-darwin/home-manager 옵션 평가 표현식 설정.
**Rationale:** nixd가 유일하게 옵션 경로 자동완성과 타입 기반 에러를 제공하는 LSP. 근본 원인 해결.
**Downsides:** 메모리/CPU 사용량 증가. 평가 표현식이 hostname/경로에 의존적.
**Confidence:** 90%
**Complexity:** Low
**Status:** Explored (적용됨)

### 2. devShell + .envrc로 direnv 파이프라인 완성
**Description:** flake.nix에 devShells 출력 추가 + 프로젝트 루트 `.envrc` 생성. Zed의 `load_direnv: "shell_hook"`이 실제로 동작하게 함.
**Rationale:** 이미 구축된 3단계 파이프라인(nix-direnv -> direnv -> Zed)의 마지막 퍼즐.
**Downsides:** flake.nix 수정 필요. 초기 devShell 빌드 시간.
**Confidence:** 85%
**Complexity:** Low
**Status:** Explored (적용됨)

### 3. statix + deadnix 린터 통합
**Description:** statix(안티패턴 감지) + deadnix(미사용 바인딩 감지)를 개발 도구에 추가. devShell 포함 또는 Zed 태스크로 등록.
**Rationale:** LSP가 잡지 못하는 코드 품질 문제 보완. 둘 다 Rust 기반으로 빠름.
**Downsides:** Zed가 외부 린터를 LSP 진단으로 직접 통합 불가. 태스크/pre-commit으로 실행 필요.
**Confidence:** 80%
**Complexity:** Low
**Status:** Unexplored (추후 개선사항)

### 4. Nix 언어 QoL 설정 강화
**Description:** Zed Nix 언어 블록에 format_on_save, show_edit_predictions, formatter 설정 추가. Elixir 수준으로 확장.
**Rationale:** LSP와 독립적인 즉시 개선. Elixir(7개 옵션) 대비 Nix(1개)가 극도로 빈약.
**Downsides:** 거의 없음.
**Confidence:** 95%
**Complexity:** Low
**Status:** Explored (적용됨)

### 5. Dual LSP: nil 진단 + nixd 완성
**Description:** nil + nixd 동시 실행. nil은 빠른 구문 진단, nixd는 옵션 완성.
**Rationale:** 커뮤니티 권장 패턴. TypeScript에서 tsgo+vtsls 듀얼 LSP 이미 사용 중.
**Downsides:** 중복 진단, 리소스 증가, Zed에서 LSP별 기능 선택적 비활성화 제한.
**Confidence:** 65%
**Complexity:** Medium
**Status:** Unexplored

### 6. Zed nix 확장 개선 기여
**Description:** PR #49 머지 지원 (runnable flake tasks) + label_for_completion 구현.
**Rationale:** 확장이 "Call for maintainers" 상태. PR #49 머지 시 flake 빌드/개발 원클릭 실행 가능.
**Downsides:** 오픈소스 기여 시간 불확실. upstream tree-sitter-nix 포크 의존.
**Confidence:** 55%
**Complexity:** High
**Status:** Unexplored

### 7. Zed 태스크로 flake 평가 피드백 루프
**Description:** nix flake check / nix eval / darwin-rebuild build를 Zed 태스크로 등록.
**Rationale:** LSP가 못 잡는 평가 에러(무한 재귀, 모듈 인자 누락 등) 즉시 확인.
**Downsides:** 평가 수 초~수십 초 소요. 기존 터미널 워크플로와 중복 가능.
**Confidence:** 70%
**Complexity:** Low
**Status:** Unexplored

## Rejection Summary

| # | Idea | Reason Rejected |
|---|------|-----------------|
| 1 | nil flake 설정 강화 (autoEvalInputs) | nil은 구조적으로 옵션/속성 완성 불가. 천장이 너무 낮음 |
| 2 | 사전 계산된 옵션 인덱스 | 과잉 설계. nixd가 이미 실시간 평가 제공 |
| 3 | Nix 스니펫 추가 | LSP 완성이 동작하면 불필요. 반창고 수준 |
| 4 | 디렉토리별 .nixd.json | nixd가 중첩 설정 미지원 |
| 5 | Nix로 .nixd.json 생성 | 정적 설정에 대한 과도한 추상화 |
| 6 | nixd 래퍼 파생물 | 단일 머신 dotfiles에 조기 추상화 |
| 7 | Home-manager 모듈로 Zed LSP 관리 | 과잉 엔지니어링 |
| 8 | LSP 포기, AI로 대체 | AI는 즉각적 속성 완성과 인라인 에러를 대체 못함 |
| 9 | 빌드 시 nixd 스키마 생성 | nixd가 시작 시 직접 평가. 불필요한 복잡성 |
| 10 | Flake 출력으로 옵션 문서 노출 | 문서화에 유용하나 에디터 경험 직접 개선 아님 |
| 11 | .nixd.json 생성 (모든 변형) | nixd v2.x에서 폐기. workspace/configuration만 유효 |
| 12 | 프로젝트-로컬 .zed/settings.json | .nixd.json 폐기로 중요도 하락 |
| 13 | MCP 컨텍스트 서버 구축 | 높은 공수 대비 핵심 문제 직접 해결 아님 |
| 14 | nix-doc REPL 통합 | LSP 경험과 직접 관련 없음 |

## Session Log
- 2026-03-26: Initial ideation — 40 raw ideas generated (5 agents x 8), deduped to 20, 7 survived
- 2026-03-26: Refinement — Zed 확장 생태계 + nixd 대안/신규 도구 리서치 추가. .nixd.json 폐기 확인. 7 survivors maintained
- 2026-03-26: Implementation — ideas #1, #2, #4 적용 시작. #3은 추후 개선사항으로 기록
