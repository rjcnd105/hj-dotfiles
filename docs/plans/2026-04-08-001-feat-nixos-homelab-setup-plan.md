---
title: NixOS 홈서버(homelab) flake 확장
type: feat
status: completed
date: 2026-04-08
---

# NixOS 홈서버(homelab) flake 확장

## Overview

기존 nix-darwin 전용 flake를 확장하여 SER9 Pro HX370 mini PC에 NixOS 홈서버를 설치한다. headless 서버로 Docker + llama.cpp를 운영하며, macOS와 home-manager 설정 및 dotfiles(`files/workspace/`)를 공유한다.

**Status note (2026-04-27):** Plan status was already `completed`; unchecked unit boxes were stale. Current repo contains `homelab_hj`, `systems/homelab/`, `homes/homelab/`, homelab secrets wiring, and `just build_hj-homelab`.

## Scope Boundaries

- GUI/데스크탑 환경 없음 (headless)
- 네트워크 서비스(Traefik, Cloudflare Tunnel)는 이 플랜에 포함하지 않음 — SSH 접근만
- disko는 포함하지 않음 — 수동 파티셔닝 후 나중에 추가
- impermanence 패턴은 포함하지 않음 — 안정화 후 고려
- ROCm GPU 가속은 포함하지 않음 — Vulkan 또는 CPU로 시작

## Relevant Code and Patterns

- `flake.nix:42-47` — hosts 맵, 현재 `workspace_hj`만 존재
- `flake.nix:56-65` — `getModulePaths` 6경로 탐색 (system/host/user 조합)
- `flake.nix:72-126` — `darwinConfigurations` 빌더 (모든 hosts를 darwin으로 빌드)
- `systems/default.nix` — darwin 전용 코드 혼재 (`/Users/`, `networking.computerName`, `system.primaryUser`, `NSGlobalDomain`)
- `systems/aarch64-darwin/default.nix` — darwin 전용 (`system.stateVersion = 6`, homebrew path)
- `systems/workspace/default.nix` — `homebrew`, `touchIdAuth`, `home-manager.sharedModules` 포함
- `homes/default.nix` — **이미 cross-platform** (`isDarwin` 분기로 home directory 처리)
- `homes/workspace/home-config.nix` — darwin 전용 변수 일부 (`VISUAL`, `OBSIDIAN`, `ZED_ALLOW_ROOT`)
- `homes/workspace/ssh-config.nix` — `UseKeychain yes` (macOS), `isDarwin` 가드 일부 존재
- `homes/file.nix` — `myOptions.hostName`으로 `files/${hostName}/` 참조
- `.sops.yaml` — `secrets/workspace/` 패턴만 존재
- `sharedHome/` — cli, development 모듈 (cross-platform)

## External References

- NixOS에 `services.llama-cpp` 네이티브 모듈 존재 — Docker 없이 선언적 설정 가능
- AMD HX370(Strix Point, gfx1150)은 Linux 6.10+ 필요 — nixos-unstable 사용으로 충족
- ROCm gfx1150 공식 미지원 (ROCm 6.5+ 예상) — `HSA_OVERRIDE_GFX_VERSION=11.0.0` 워크어라운드 또는 Vulkan 백엔드 권장
- `nixos-hardware` — `common/cpu/amd`, `common/gpu/amd` 모듈 활용 가능
- btrfs 권장 마운트 옵션: `compress=zstd,noatime`
- **comin** (GitOps): GitHub repo를 poll하여 변경 감지 시 자동 `nixos-rebuild switch`. push 기반 배포 대신 pull 기반 GitOps 모델
- 소스 repo: `https://github.com/rjcnd105/hj-dotfiles` (main 브랜치)

## Key Technical Decisions

- **hosts 맵 필터링**: `darwinConfigurations`와 `nixosConfigurations`가 같은 hosts 맵을 system 기준으로 필터링하여 사용. 코드 중복 최소화
- **`filesHost` 옵션 추가**: `myOptions`에 `filesHost` 필드를 추가하여 homelab이 `files/workspace/`를 참조할 수 있게 함. `file.nix`가 `hostName` 대신 `filesHost` 사용
- **`systems/default.nix` 리팩터링**: darwin 전용 코드를 `systems/aarch64-darwin/default.nix`로 이동. `systems/default.nix`는 cross-platform만 유지
- **`home-manager.sharedModules` 위치 이동**: `systems/workspace/default.nix`에서 `systems/default.nix`로 이동하여 모든 호스트가 sops-nix, catppuccin 공유
- **llama.cpp 네이티브**: Docker가 아닌 `services.llama-cpp` NixOS 모듈 사용 (선언적, 서비스 관리 통합)
- **comin으로 GitOps 배포**: `services.comin`이 `github.com/rjcnd105/hj-dotfiles` main 브랜치를 poll → 변경 감지 시 자동 `nixos-rebuild switch`. Mac에서 push만 하면 homelab이 스스로 반영
- **hardware-configuration.nix 플레이스홀더**: 설치 시 `nixos-generate-config`로 생성한 파일을 repo에 커밋

## Implementation Units

- [x] **Unit 1: Flake 인프라 확장**

  **Goal:** hosts 맵에 homelab을 추가하고, darwin/nixos 설정을 분리된 output으로 빌드할 수 있게 한다

  **Dependencies:** None

  **Files:**
  - Modify: `flake.nix`

  **Approach:**
  - hosts 맵에 `homelab_hj = { system = "x86_64-linux"; email = "..."; filesHost = "workspace"; }` 추가
  - hosts를 system 기준으로 필터: `lib.filterAttrs (k: v: lib.hasSuffix "darwin" v.system)` / `"linux"`
  - `nixosConfigurations` output 추가 — `nixpkgs.lib.nixosSystem` 사용, `home-manager.nixosModules.home-manager` 모듈 포함
  - `myOptions`에 `filesHost` 추가 — `config.filesHost or hostName`으로 기본값 처리
  - `devShells.x86_64-linux` 추가

  **Patterns to follow:**
  - 기존 `darwinConfigurations` 빌더 구조를 미러링
  - `getModulePaths`는 변경 없이 그대로 재사용

  **Verification:**
  - `nix eval .#nixosConfigurations.homelab_hj` 가 에러 없이 평가됨
  - `nix eval .#darwinConfigurations.workspace_hj` 가 기존과 동일하게 동작

- [x] **Unit 2: systems/ 모듈 리팩터링 + NixOS 모듈 생성**

  **Goal:** `systems/default.nix`를 cross-platform으로 정리하고, NixOS 전용 시스템 모듈을 생성한다

  **Dependencies:** Unit 1

  **Files:**
  - Modify: `systems/default.nix`
  - Modify: `systems/aarch64-darwin/default.nix`
  - Modify: `systems/workspace/default.nix`
  - Create: `systems/x86_64-linux/default.nix`
  - Create: `systems/homelab/default.nix`
  - Create: `systems/homelab/hardware-configuration.nix` (placeholder)

  **Approach:**
  - `systems/default.nix` 리팩터링:
    - darwin 전용 코드(`/Users/` 경로, `networking.computerName`, `networking.localHostName`, `system.primaryUser`, `NSGlobalDomain`) → `systems/aarch64-darwin/default.nix`로 이동
    - 남기는 것: `environment.variables` (경로는 `isDarwin` 분기), `users.users` (경로 분기), `home-manager` 설정, `fonts.packages`
    - `home-manager.sharedModules` (sops-nix, catppuccin)를 `systems/workspace/default.nix`에서 여기로 이동
  - `systems/aarch64-darwin/default.nix` 확장:
    - 기존 내용 + `systems/default.nix`에서 이동한 darwin 전용 설정
  - `systems/workspace/default.nix` 정리:
    - `home-manager.sharedModules`와 `extraSpecialArgs`를 `systems/default.nix`로 이동한 후 제거
    - 나머지(homebrew, touchIdAuth 등)는 macOS 전용이므로 그대로 유지
  - `systems/x86_64-linux/default.nix` 생성:
    - NixOS 기본: `boot.loader.systemd-boot`, `networking.firewall`, `services.openssh`, `time.timeZone`, `i18n`, `nix.settings`
    - `system.stateVersion` 설정
  - `systems/homelab/default.nix` 생성:
    - Docker: `virtualisation.docker.enable`
    - llama.cpp: `services.llama-cpp.enable` (CPU 모드로 시작)
    - comin: `services.comin` — `github.com/rjcnd105/hj-dotfiles` main 브랜치 poll, flake 경로 `.#nixosConfigurations.homelab_hj`
    - `networking.hostName = "homelab"`
    - 기본 사용자 설정, sudo, fish shell
  - `systems/homelab/hardware-configuration.nix` placeholder:
    - 설치 시 `nixos-generate-config`로 생성된 내용으로 교체할 파일. 빈 모듈 `{ }` 또는 주석으로 안내

  **Patterns to follow:**
  - `systems/aarch64-darwin/default.nix`의 간결한 스타일
  - `getModulePaths`의 경로 규칙에 맞춰 배치

  **Verification:**
  - `nix build .#darwinConfigurations.workspace_hj.system` 가 기존과 동일하게 빌드됨
  - `nix eval .#nixosConfigurations.homelab_hj.config.networking.hostName` 이 `"homelab"` 반환

- [x] **Unit 3: homes/ 공유 및 cross-platform 호환**

  **Goal:** homelab이 기존 workspace의 home-manager 설정과 dotfiles를 공유하되, darwin 전용 코드가 NixOS에서 에러를 일으키지 않게 한다

  **Dependencies:** Unit 1

  **Files:**
  - Modify: `homes/file.nix`
  - Modify: `homes/workspace/home-config.nix`
  - Modify: `homes/workspace/ssh-config.nix`
  - Create: `homes/homelab/default.nix`

  **Approach:**
  - `homes/file.nix`:
    - `myOptions.hostName` → `myOptions.filesHost`로 변경 (files 경로 결정에 사용)
  - `homes/workspace/home-config.nix`:
    - darwin 전용 변수를 `lib.mkIf pkgs.stdenv.isDarwin`으로 감쌈: `VISUAL`, `OBSIDIAN`, `ZED_ALLOW_ROOT`, `HM_CURRENT`
    - 또는 headless에서 불필요한 것만 제거/가드
  - `homes/workspace/ssh-config.nix`:
    - `UseKeychain yes`를 `isDarwin` 가드로 감쌈 (현재 activation만 가드되어 있고 extraConfig는 안 되어 있음)
  - `homes/homelab/default.nix`:
    - `homes/workspace/default.nix`와 동일한 imports 구조로 작성
    - 동일 모듈 참조: `../file.nix`, `./home-config.nix` 대신 `../workspace/home-config.nix` 등

  **Patterns to follow:**
  - `homes/default.nix`의 `isDarwin` 분기 패턴
  - `ssh-config.nix`의 기존 `lib.mkIf pkgs.stdenv.isDarwin` 패턴

  **Verification:**
  - darwin 빌드가 깨지지 않음
  - NixOS 빌드 시 darwin 전용 옵션이 평가되지 않음
  - `files/workspace/`의 dotfiles가 homelab에서도 심링크됨

- [x] **Unit 4: Secrets + 빌드 설정**

  **Goal:** homelab에서 기존 sops-nix secrets를 복호화할 수 있게 하고, 빌드/배포 명령을 justfile에 추가한다

  **Dependencies:** Unit 2, Unit 3

  **Files:**
  - Modify: `.sops.yaml`
  - Modify: `justfile`
  - Create: `secrets/homelab/secrets.yaml` (sops 암호화)

  **Approach:**
  - `.sops.yaml`:
    - homelab age public key를 keys 섹션에 추가 (설치 후 homelab에서 `ssh-to-age`로 생성)
    - `secrets/homelab/` 패턴 creation rule 추가
  - `justfile`:
    - `build_hj-homelab`: `nix build .#nixosConfigurations.homelab_hj.config.system.build.toplevel` (Mac에서 eval 체크용)
    - comin이 배포를 담당하므로 `nixos-rebuild --target-host` 레시피는 불필요 — push만 하면 자동 반영
  - `secrets/homelab/secrets.yaml`:
    - workspace secrets와 동일한 키 구조. homelab age key + hj age key로 암호화
    - 실제 생성은 homelab 설치 후 age key가 생긴 뒤 수행

  **Patterns to follow:**
  - `.sops.yaml`의 기존 creation_rules 패턴
  - `justfile`의 기존 build/switch 레시피 패턴

  **Verification:**
  - `sops secrets/homelab/secrets.yaml`로 편집 가능
  - `just build_hj-homelab`으로 빌드 성공

## Risks

- **hardware-configuration.nix**: 실제 하드웨어에서 생성해야 하므로, Unit 2의 placeholder로는 빌드만 되고 부팅은 안 됨. 설치 시 교체 필수
- **AMD HX370 커널 호환성**: nixos-unstable의 커널이 6.10+ 이어야 함. 만약 WiFi/네트워크 문제가 있으면 유선 연결 필요
- **ROCm 미지원**: llama.cpp GPU 가속은 현재 불가. CPU 또는 Vulkan 백엔드로 시작해야 함

## Testing Strategy

Mac(aarch64-darwin)에서 x86_64-linux 풀 빌드는 불가하므로, 단계별 검증:

**Mac에서 (코드 작성 후):**
- evaluation 체크: `nix eval .#nixosConfigurations.homelab_hj.config.networking.hostName`
- flake 문법 검증: `nix flake check`
- darwin 회귀 테스트: `just build_hj-workspace` (리팩터링으로 기존 빌드가 안 깨지는지)

**SER9 Pro에서 (USB 부팅 후):**
- 풀 시스템 빌드: `nix build /path/to/flake#nixosConfigurations.homelab_hj.config.system.build.toplevel`
- 설치 후 설정 변경 시: `nixos-rebuild build-vm --flake .#homelab_hj` 으로 VM 테스트

## Installation Guide (Post-plan)

플랜의 Unit 1-4 완료 후 실제 설치 순서.

### 1. USB 부팅 + 네트워크

NixOS minimal USB로 SER9 Pro 부팅. 유선 연결 권장 (HX370 WiFi 드라이버 호환성 불확실).

```bash
# 네트워크 확인
ip a
ping -c 3 nixos.org
```

### 2. 파티셔닝

```bash
# 디스크 확인 (NVMe SSD = /dev/nvme0n1 일반적)
lsblk

# GPT 파티션 테이블 생성 + 파티션 분할
parted /dev/nvme0n1 -- mklabel gpt
parted /dev/nvme0n1 -- mkpart ESP fat32 1MB 512MB
parted /dev/nvme0n1 -- set 1 esp on
parted /dev/nvme0n1 -- mkpart primary 512MB 100%

# 포맷
mkfs.fat -F 32 -n BOOT /dev/nvme0n1p1
mkfs.btrfs -L nixos /dev/nvme0n1p2
```

### 3. btrfs 서브볼륨 생성

```bash
mount /dev/nvme0n1p2 /mnt

btrfs subvolume create /mnt/@        # 루트 파일시스템
btrfs subvolume create /mnt/@home    # 사용자 데이터 (백업 대상)
btrfs subvolume create /mnt/@nix     # Nix store (백업 불필요, 재빌드 가능)
btrfs subvolume create /mnt/@log     # 로그 분리

umount /mnt
```

### 4. 마운트

```bash
mount -o subvol=@,compress=zstd,noatime /dev/nvme0n1p2 /mnt

mkdir -p /mnt/{home,nix,var/log,boot}

mount -o subvol=@home,compress=zstd,noatime /dev/nvme0n1p2 /mnt/home
mount -o subvol=@nix,compress=zstd,noatime  /dev/nvme0n1p2 /mnt/nix
mount -o subvol=@log,compress=zstd,noatime  /dev/nvme0n1p2 /mnt/var/log
mount /dev/nvme0n1p1 /mnt/boot
```

### 5. NixOS 설정 생성

```bash
nixos-generate-config --root /mnt
# 생성 파일: /mnt/etc/nixos/hardware-configuration.nix
```

생성된 `hardware-configuration.nix`를 repo의 `systems/homelab/hardware-configuration.nix`로 복사 (USB로 옮기거나 임시 git push).

### 6. 설치

```bash
# GitHub에서 flake repo clone
git clone https://github.com/rjcnd105/hj-dotfiles /mnt/etc/nixos

# 설치
nixos-install --flake /mnt/etc/nixos#homelab_hj
# root 비밀번호 설정 프롬프트가 나옴
```

### 7. 재부팅 + 초기 확인

```bash
reboot
# SSH로 접속: ssh hj@<homelab-ip>
# 확인:
systemctl status docker
systemctl status llama-cpp
systemctl status comin    # GitOps 자동 배포 동작 확인
journalctl -u comin -f    # comin 로그 실시간 확인
```

이후 Mac에서 flake 변경 → `git push` → comin이 자동 감지 → `nixos-rebuild switch` 자동 실행.

### 8. Secrets 설정

```bash
# homelab에서 age key 생성
nix-shell -p ssh-to-age --run 'cat ~/.ssh/id_ed25519.pub | ssh-to-age'
# 출력된 age public key를 Mac의 .sops.yaml에 추가
# secrets/homelab/secrets.yaml 생성 후 sops로 암호화
```
