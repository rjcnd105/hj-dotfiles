---
title: "feat: myOptions에 system 추가하고 $SYSTEM 환경변수 설정"
type: feat
status: completed
date: 2026-03-26
---

# feat: myOptions에 system 추가하고 $SYSTEM 환경변수 설정

## Overview

`myOptions`에 `system` 값(예: `aarch64-darwin`)을 추가하고, `$SYSTEM` 환경변수로 노출한다. `$USER_HOST`는 이미 `myOptions.hostName`으로 설정되어 있으므로 변경 불필요.

## Problem Frame

현재 `myOptions`에 시스템 아키텍처 정보(`aarch64-darwin`)가 포함되어 있지 않아, 하위 모듈에서 현재 시스템 타입을 알 수 없다. `hosts` 정의에 `system = "aarch64-darwin"`이 있지만 `myOptions`로 전달되지 않는다.

## Requirements Trace

- R1. `myOptions.system`으로 시스템 아키텍처(예: `aarch64-darwin`)에 접근 가능해야 한다
- R2. `$SYSTEM` 환경변수에 해당 값이 설정되어야 한다
- R3. `$USER_HOST`는 현재 동작 유지 (이미 `myOptions.hostName`으로 설정됨)

## Scope Boundaries

- `$USER_HOST` 관련 기존 코드 변경 없음 (이미 `homes/workspace/home-config.nix:40`에서 동작 중)
- 새로운 모듈이나 파일 생성 없음

## Context & Research

### Relevant Code and Patterns

- `flake.nix:78-85` — `myOptions` 정의. `inherit (config) email;` 패턴으로 hosts 속성을 가져옴
- `flake.nix:42-47` — `hosts` 정의에 `system = "aarch64-darwin"` 존재
- `systems/default.nix:12-15` — `environment.variables`에 `USER`, `HOME` 설정 패턴
- `homes/workspace/home-config.nix:40` — `USER_HOST = myOptions.hostName;` (기존 동작)

## Key Technical Decisions

- **`system`을 `myOptions`에 `inherit`로 추가**: `inherit (config) email;`을 `inherit (config) email system;`으로 확장. 기존 패턴과 일관성 유지.
- **`$SYSTEM`은 `environment.variables`(시스템 레벨)에 설정**: `USER`, `HOME`과 같은 레벨. 시스템 아키텍처는 시스템 속성이므로 home-manager가 아닌 시스템 레벨이 적합.

## Implementation Units

- [x] **Unit 1: myOptions에 system 추가 및 $SYSTEM 환경변수 설정**

  **Goal:** `myOptions`에 `system` 속성을 추가하고, `$SYSTEM` 환경변수로 노출

  **Requirements:** R1, R2

  **Dependencies:** 없음

  **Files:**
  - Modify: `flake.nix` (line 80: `inherit (config) email;` → `inherit (config) email system;`)
  - Modify: `systems/default.nix` (line 12-15: `environment.variables`에 `SYSTEM` 추가)

  **Approach:**
  - `flake.nix`에서 `inherit (config) email;`을 `inherit (config) email system;`으로 변경하여 `myOptions.system` 사용 가능하게 함
  - `systems/default.nix`의 `environment.variables`에 `SYSTEM = myOptions.system;` 추가

  **Patterns to follow:**
  - `inherit (config) email;` → `inherit (config) email system;` (기존 inherit 패턴)
  - `USER = myOptions.userName;` → `SYSTEM = myOptions.system;` (기존 환경변수 패턴)

  **Verification:**
  - `nix eval .#darwinConfigurations.workspace_hj.config.environment.variables.SYSTEM` → `"aarch64-darwin"`
  - `myOptions.system`이 하위 모듈에서 접근 가능

## Risks & Dependencies

- 위험 낮음. `myOptions`에 속성 추가는 기존 코드에 영향 없음 (추가만 하고 기존 속성 변경 없음)
