---
title: "refactor: homelab에서 mise 제거 후 Nix 패키지 전환"
type: refactor
status: completed
date: 2026-04-13
---

# refactor: homelab에서 mise 제거 후 Nix 패키지 전환

## Overview

homelab(NixOS)에서 mise를 비활성화하고, 필요한 개발 도구를 Nix 패키지로 설치한다. NixOS는 FHS를 따르지 않아 mise가 다운로드한 동적 링크 바이너리 실행과 소스 빌드 모두 실패하므로, Nix 패키지 관리로 전환하여 호환성 문제를 근본적으로 해결한다.

**Status note (2026-04-27):** Implemented in `sharedHome/cli/shell/mise.nix` (`programs.mise.enable = lib.mkDefault false`) and `homes/homelab/default.nix` (`erlang`, `elixir`, `python3`, `nodejs_24`, `rustc`, `cargo`, `gleam`, `zig`, `bun`, `usage`). Home Manager no longer owns mise shell integration; existing workspace mise config remains a dotfile, not an HM-managed program.

## Problem Frame

mise는 macOS(workspace)에서는 잘 동작하지만, NixOS(homelab)에서는 3가지 구조적 문제가 있다:

1. **동적 링킹 실패** — 사전 빌드 바이너리(bun, rustup-init, node)가 `/lib64/ld-linux-x86-64.so.2`를 찾지 못함
2. **빌드 의존성 부재** — 소스 빌드 도구(erlang, python)가 gcc/make를 찾지 못함
3. **config 공유 구조** — `filesHost = "workspace"` 설정으로 macOS용 mise config.toml이 homelab에 그대로 적용됨

## Requirements Trace

- R1. homelab에서 mise를 비활성화한다 (programs.mise.enable = false)
- R2. 필요한 개발 도구를 Nix 패키지로 설치한다: erlang, elixir, python, node, rust, gleam, zig, bun, usage
- R3. workspace의 mise 설정에는 영향을 주지 않는다
- R4. 이미 Nix로 설치된 도구(jj, just)는 변경하지 않는다

## Scope Boundaries

- mise config.toml(`files/workspace/.config/mise/config.toml`) 자체는 수정하지 않음 — workspace에서 계속 사용
- homelab에 심링크된 mise config.toml 파일은 mise가 비활성화되면 무해하므로 별도 처리 불필요
- mise config.toml의 env/tasks 섹션(HINDSIGHT, CLAUDE_CODE 등)은 homelab에서 별도 관리 필요시 후속 작업

## Context & Research

### Relevant Code and Patterns

- `sharedHome/cli/shell/mise.nix` — `programs.mise.enable = true` 무조건 활성화
- `homes/homelab/default.nix` — homelab 전용 home-manager 설정. `home.packages`에 추가하는 패턴 존재
- `homes/workspace/ssh-config.nix:39` — `lib.mkIf pkgs.stdenv.isDarwin` 조건부 설정 패턴 존재
- `sharedHome/cli/packages.nix` — shared home.packages 패턴 (just, difftastic 등)

### External References (Context7 + nixpkgs 검증)

- **Nix 모듈 시스템**: `lib.mkDefault`는 priority 1000으로 설정하여 다른 모듈이 같은 옵션을 일반 값으로 설정하면 자동으로 양보. `lib.mkIf`는 조건부 configuration block 활성화에 사용
- **home-manager programs.mise**: `enable`, `enableFishIntegration`, `enableZshIntegration` 옵션 제공
- **nixpkgs 패키지 검증 완료**: `bun`, `gleam`, `usage`, `erlang`, `elixir`, `python3`, `nodejs_24`, `rustc`, `cargo`, `zig` — 모두 nixpkgs에 존재 확인

### Institutional Learnings

- `filesHost = "workspace"` (flake.nix:48)로 homelab이 workspace의 dotfiles를 공유
- `myOptions.hostName`으로 호스트별 조건 분기 가능

## Key Technical Decisions

- **mise 비활성화 방식**: `mise.nix`에서 `lib.mkIf pkgs.stdenv.isDarwin`으로 darwin에서만 활성화. NixOS FHS 비호환이 근본 원인이므로 플랫폼 기반 조건이 호스트명 하드코딩보다 견고
- **Rust 설치 방식**: `pkgs.rustc` + `pkgs.cargo` 고정 버전. NixOS 호환 보장, 버전 관리 불필요
- **패키지 위치**: `homes/homelab/default.nix`의 `home.packages`에 추가. 별도 파일 불필요한 수준의 변경량

## Implementation Units

- [x] **Unit 1: mise를 homelab에서 비활성화**

**Goal:** sharedHome의 mise 설정을 오버라이드 가능하게 변경하고, homelab에서 비활성화

**Requirements:** R1, R3

**Dependencies:** None

**Files:**
- Modify: `sharedHome/cli/shell/mise.nix`
- Modify: `homes/homelab/default.nix`

**Approach:**
- `mise.nix`에서 전체 `programs.mise` 블록을 `lib.mkIf pkgs.stdenv.isDarwin`으로 감싸서 darwin에서만 활성화
- `mise.nix`에 `lib`, `pkgs` 인자 추가
- homelab에서 별도 override 불필요 — 플랫폼 조건이 자동 처리

**Patterns to follow:**
- `homes/workspace/ssh-config.nix`의 `lib.mkIf` 조건부 패턴
- Nix 모듈 시스템의 `mkDefault` / override 관용 패턴

**Test scenarios:**
- Happy path: `just build_hj-workspace` 성공 — workspace의 mise 설정 유지 확인
- Happy path: homelab 빌드 시 mise 관련 Fish 초기화 코드가 생성되지 않음 확인

**Verification:**
- workspace 빌드가 기존과 동일하게 성공
- homelab 빌드에서 mise 관련 설정이 포함되지 않음

- [x] **Unit 2: 개발 도구를 Nix 패키지로 설치**

**Goal:** homelab에 필요한 개발 런타임과 도구를 Nix 패키지로 추가

**Requirements:** R2, R4

**Dependencies:** Unit 1

**Files:**
- Modify: `homes/homelab/default.nix`

**Approach:**
- `home.packages`에 다음 패키지 추가:
  - `pkgs.erlang`, `pkgs.elixir` (beam 런타임)
  - `pkgs.python3` (Python 3)
  - `pkgs.nodejs_24` (Node.js 24)
  - `pkgs.rustc`, `pkgs.cargo` (Rust 툴체인)
  - `pkgs.gleam` (Gleam 컴파일러)
  - `pkgs.zig` (Zig 컴파일러)
  - `pkgs.bun` (Bun 런타임)
  - `pkgs.usage` (CLI spec 도구 — nixpkgs 존재 확인 완료)
- jj(`sharedHome/cli/jj.nix`)와 just(`sharedHome/cli/packages.nix`)는 이미 설치되어 있으므로 변경 불필요

**Patterns to follow:**
- `homes/homelab/default.nix`의 기존 `home.packages` 패턴 (`pkgs.claude-code`)
- `sharedHome/cli/packages.nix`의 패키지 나열 스타일

**Test scenarios:**
- Happy path: homelab 빌드 성공, 모든 패키지가 profile에 포함됨
- Edge case: `pkgs.nodejs_24` 평가 실패 시 `pkgs.nodejs` 폴백

**Verification:**
- homelab 빌드 성공
- 설치된 패키지에서 erlang, elixir, python3, node, rustc, cargo, gleam, zig, bun 바이너리 확인 가능

## System-Wide Impact

- **Interaction graph:** sharedHome/cli/shell/mise.nix의 `mkDefault` 변경이 workspace에 영향 없음 확인 필요 (workspace에서 별도 override가 없으므로 기본값 true 유지)
- **Unchanged invariants:** workspace의 mise 설정, Fish shell 통합, mise config.toml 모두 기존과 동일하게 동작

## Risks & Dependencies

| Risk | Mitigation |
|------|------------|
| `pkgs.nodejs_24`가 nixpkgs 채널에 따라 없을 수 있음 | `pkgs.nodejs`로 폴백. 모든 패키지의 nixpkgs 존재는 로컬에서 검증 완료 |
| nixpkgs의 erlang/elixir 버전이 mise의 latest와 다를 수 있음 | nixpkgs 고정 버전 사용은 의도된 trade-off. 특정 버전 필요시 overlay 추가 |
| homelab에서 mise config.toml이 여전히 심링크됨 | mise가 비활성화되면 이 파일은 참조되지 않으므로 무해 |
