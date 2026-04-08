---
title: nix-darwin 전용 flake를 NixOS 지원으로 확장하기
date: 2026-04-08
category: best-practices
module: nix-flake
problem_type: best_practice
component: tooling
severity: medium
applies_when:
  - 기존 nix-darwin flake에 NixOS 호스트를 추가할 때
  - macOS와 NixOS 간 home-manager 설정을 공유하고 싶을 때
  - 단일 flake에서 multi-system (darwin + linux) 구성이 필요할 때
tags:
  - nix
  - nixos
  - nix-darwin
  - flake
  - multi-system
  - home-manager
  - cross-platform
---

# nix-darwin 전용 flake를 NixOS 지원으로 확장하기

## Context

nix-darwin으로 macOS dotfiles를 관리하던 flake에 NixOS 홈서버를 추가해야 했다. 핵심 과제: systems/ 모듈에 darwin 전용 코드가 혼재되어 있어 NixOS에서 평가 에러가 발생하고, home-manager 설정과 dotfiles를 두 플랫폼에서 공유해야 했다.

## Guidance

### 1. hosts 맵을 system 기준으로 필터링

모든 호스트를 하나의 `hosts` 맵에 정의하고, `darwinConfigurations`/`nixosConfigurations`에서 system 문자열로 필터:

```nix
darwinHosts = lib.filterAttrs (_: v: lib.hasSuffix "darwin" v.system) hosts;
linuxHosts = lib.filterAttrs (_: v: lib.hasSuffix "linux" v.system) hosts;
```

공통 로직(키 파싱, myOptions 생성)은 `parseHostKey` 헬퍼로 추출하여 두 빌더에서 재사용.

### 2. systems/default.nix는 cross-platform만 유지

darwin 전용 코드(`/Users/` 경로, `networking.computerName`, `system.primaryUser`, `NSGlobalDomain`)를 `systems/aarch64-darwin/default.nix`로 이동. `systems/default.nix`에는 양 플랫폼에서 안전한 설정만 남긴다.

`home-manager.sharedModules`를 호스트별 모듈(workspace)에서 `systems/default.nix`로 승격시키면 모든 호스트가 sops-nix, catppuccin 등을 공유한다.

### 3. darwin 전용 home-manager 코드에 가드 추가

`isDarwin`/`optionalAttrs`/`optionalString` 패턴으로 macOS 전용 설정을 감싼다:

```nix
# sessionVariables에서 darwin 전용 분리
home.sessionVariables = {
  # 공유 변수
  EDITOR = pkgs.helix + "/bin/hx";
} // lib.optionalAttrs pkgs.stdenv.isDarwin {
  VISUAL = "/usr/local/bin/zed";
  OBSIDIAN = "$HOME/Library/Mobile Documents/...";
};

# SSH extraConfig에서 macOS 전용 분리
extraConfig = lib.optionalString pkgs.stdenv.isDarwin ''
  UseKeychain yes
'';
```

### 4. filesHost 패턴으로 dotfiles 공유

호스트명이 다르지만 같은 dotfiles 디렉토리를 참조해야 할 때, `myOptions`에 `filesHost` 필드를 추가:

```nix
# hosts 맵에서
homelab_hj = {
  system = "x86_64-linux";
  filesHost = "workspace";  # files/workspace/ 참조
};

# myOptions에서
filesHost = config.filesHost or hostName;  # 미설정 시 hostName 폴백

# file.nix에서
initalBasePath = myOptions.absoluteProjectPath + "/files/${myOptions.filesHost}";
```

### 5. getModulePaths 활용

기존 `getModulePaths`의 6경로 탐색이 multi-system을 자연스럽게 지원한다:
- `systems/default.nix` → 전 호스트 공유
- `systems/aarch64-darwin/default.nix` → macOS 전용
- `systems/x86_64-linux/default.nix` → NixOS 전용
- `systems/workspace/default.nix` → workspace 호스트 전용
- `systems/homelab/default.nix` → homelab 호스트 전용

새 파일을 만들기만 하면 자동으로 로드된다.

## Why This Matters

darwin 전용 코드를 분리하지 않으면 NixOS 평가 시 `networking.computerName`, `system.primaryUser` 등 darwin 전용 옵션에서 에러가 발생한다. `filesHost` 패턴이 없으면 호스트별로 dotfiles를 복사해야 하고, home-manager 설정을 공유하지 않으면 두 호스트의 설정이 점점 발산한다.

## When to Apply

- nix-darwin flake에 NixOS 호스트를 처음 추가할 때
- 기존 home-manager 모듈에 darwin 전용 코드가 포함되어 있을 때
- 여러 호스트가 같은 dotfiles 디렉토리를 참조해야 할 때

## Examples

이 프로젝트의 실제 구현:
- `flake.nix` — `darwinHosts`/`linuxHosts` 필터링, `parseHostKey` 헬퍼
- `systems/default.nix` — cross-platform 공유 설정 + `home-manager.sharedModules`
- `systems/aarch64-darwin/default.nix` — darwin 전용 (`/Users/`, `system.primaryUser` 등)
- `systems/x86_64-linux/default.nix` — NixOS 기본 (systemd-boot, SSH, firewall)
- `homes/homelab/default.nix` — workspace 모듈 직접 import으로 설정 공유
- `homes/file.nix` — `myOptions.filesHost`로 dotfiles 경로 결정

## Related

- `docs/plans/2026-04-08-001-feat-nixos-homelab-setup-plan.md` — 구현 플랜
- `docs/guides/homelab-install-guide.md` — 21단계 설치 가이드
