---
title: NixOS kswapd livelock — zero swap + 동시 컨테이너 기동
date: 2026-04-16
category: runtime-errors
module: homelab
problem_type: runtime_error
component: tooling
symptoms:
  - SSH 접속 불가 (banner exchange timeout), ping은 정상
  - 시스템 15분 이상 무응답 후 자연 복구
  - dmesg에 OOM kill 로그 없음
  - load average 33.15 (CPU 8코어 대비 4배 초과)
root_cause: config_error
resolution_type: config_change
severity: critical
tags:
  - nixos
  - kswapd
  - livelock
  - zero-swap
  - docker
  - tei
  - oom
  - zram
  - earlyoom
---

# NixOS kswapd livelock -- zero swap + 동시 컨테이너 기동

## Problem

NixOS homelab(16GB RAM)에 Docker 컨테이너 4개(hindsight API, TimescaleDB, TEI embed, TEI rerank)를 동시 기동했을 때 시스템이 완전히 멈춤. SSH 접속 불가, Cloudflare Tunnel도 불통. 15분 이상 지속 후 자연 복구됨.

## Symptoms

- SSH 접속 시도 시 `banner exchange timeout` — sshd 프로세스가 응답 못함
- `ping`은 정상 응답 (커널 softirq는 살아있음, userspace만 멈춤)
- dmesg에 OOM kill 기록 없음 — OOM killer가 발동하지 않았다는 의미
- load average 33.15 (8코어 시스템에서 정상의 4배)
- `swapDevices = [ ]` 설정 — swap이 0

## What Didn't Work

- SSH 재접속 시도: 세션 자체가 열리지 않아 원격 진단 불가
- Cloudflare Tunnel 경유 접근: 터널 프로세스도 userspace라 동일하게 멈춤
- 단순 부하 과다 가설: OOM kill이 없었으므로 메모리 부족이 아닌 다른 메커니즘

## Solution

3가지 NixOS 설정 변경으로 해결:

### 1. zram swap 추가 (`systems/homelab/default.nix`)

```nix
zramSwap = {
  enable = true;
  algorithm = "zstd";
  memoryPercent = 25;
};
```

### 2. earlyoom 활성화 + systemd-oomd 비활성화

```nix
services.earlyoom = {
  enable = true;
  freeMemThreshold = 5;
  freeMemKillThreshold = 3;
  freeSwapThreshold = 10;
  freeSwapKillThreshold = 5;
  enableNotifications = true;
};
systemd.oomd.enable = false;  # earlyoom과 중복 방지
```

### 3. TEI 컨테이너 순차 시작 (`systems/homelab/hindsight-stack.nix`)

```nix
# TEI reranker는 embed 완전 시작 후에 기동 (동시 모델 로딩 방지)
systemd.services.docker-tei-rerank.after = [
  "init-hindsight-network.service"
  "docker-tei-embed.service"
];
```

긴급 복구는 comin GitOps를 활용: hindsight-stack.nix import를 주석 처리한 커밋을 push → comin이 60초 poll로 감지 → 자동 rebuild로 컨테이너 제거 → 시스템 복구.

## Why This Works

**근본 원인: kswapd livelock**

swap이 0인 상태에서 메모리가 부족하면 커널의 kswapd가 페이지를 회수하려 하지만, 회수 가능한 clean page가 없으면(Docker overlay I/O + btrfs CoW가 dirty page를 계속 생성) kswapd가 무한 루프에 빠진다. 이때:

1. kswapd가 CPU를 독점하며 page reclaim을 반복 시도
2. 모든 userspace 프로세스가 page allocation에서 block
3. ping은 응답 (커널 softirq 경로), SSH는 불응 (sshd = userspace)
4. OOM killer는 swap이 없으면 발동 기준이 달라져서 발동하지 않을 수 있음

**왜 OOM kill 대신 livelock:**
- swap = 0이면 커널은 anonymous page를 내보낼 곳이 없어 clean file page만 회수 가능
- Docker + btrfs가 dirty file page를 빠르게 생성 → 회수 속도 < 생성 속도 → livelock

**해결 원리:**
- zram swap: anonymous page 내보낼 곳 확보 → kswapd가 정상 회수 가능
- earlyoom: livelock 전에 가장 큰 프로세스를 SIGTERM → 즉시 메모리 확보
- 순차 시작: TEI 두 개의 ONNX 모델 로딩(각 3-4GB)이 동시에 발생하는 peak 방지

## Prevention

- **NixOS 서버에서 `swapDevices = [ ]`은 위험**: 물리 swap이 없으면 반드시 zram을 켜야 함. zram은 미사용 시 RAM 소비 0이므로 항상 켜두는 것이 안전
- **earlyoom vs systemd-oomd**: NixOS 24.05+에서는 둘 다 기본 활성될 수 있음. earlyoom이 컨테이너 워크로드에서 더 안정적 (PSI 이벤트 의존 없이 `/proc/meminfo` 직접 폴링)
- **무거운 컨테이너 동시 기동 금지**: systemd `after` 의존성으로 순차 시작 강제
- **comin GitOps = 원격 복구 채널**: SSH 불통이어도 GitHub push → comin poll → rebuild로 설정 변경 가능 (단, comin 프로세스도 livelock에 빠지면 불가)

## Related Issues

- hardware-configuration.nix의 `swapDevices = [ ]` 가 근본 원인 제공
- AMD HX 370 iGPU UMA가 32GB 중 ~16GB를 점유하여 실질 가용 RAM 16GB
- comin bare repo 깨짐: `jj sign`으로 SHA 재작성 후 force push → `/var/lib/comin/repository` refs 무효화 → 별도 해결 필요
