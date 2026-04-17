---
title: Docker 컨테이너에서 호스트 서비스 접근 — user-defined bridge 회피, host network 전환
date: 2026-04-17
category: integration-issues
module: homelab
problem_type: integration_issue
component: tooling
symptoms:
  - "openai.APITimeoutError: Request timed out (컨테이너 startup 중)"
  - 대상 서비스(prefix-proxy, llama-swap)의 systemd journal이 empty — 요청이 도달한 흔적 없음
  - docker-hindsight restart 루프, NRestarts 지속 증가
root_cause: config_error
resolution_type: config_change
severity: high
related_components:
  - docker
  - networking
tags:
  - docker
  - nixos
  - bridge-network
  - host-network
  - systemd
  - homelab
  - container-host-communication
---

# Docker 컨테이너에서 호스트 서비스 접근 — user-defined bridge 회피, host network 전환

## Problem

homelab에서 Hindsight(Docker 컨테이너)가 호스트 systemd 서비스(`llama-swap:8090`, `embed-prefix-proxy:8091`)를 호출해야 하는 구조로 개편. 컨테이너가 Docker user-defined bridge(`--network=hindsight`)에 붙어있는 상태에서 여러 조합을 시도했으나 embedding 요청이 호스트 서비스에 도달하지 못해 startup마다 60초 timeout → 앱 종료 → systemd restart 루프.

## Symptoms

- Python 앱이 `openai.APITimeoutError: Request timed out`으로 startup 실패 후 exit code 3
- 목적지 서비스(prefix-proxy, llama-swap)의 `journalctl` 출력이 텅 비어있음 — **요청이 네트워크 레벨에서 도달조차 못함**
- `systemctl show docker-hindsight -p NRestarts`가 계속 증가 (세션 중 9회 이상)
- 호스트에서 같은 서비스 `/health`는 `127.0.0.1`, `192.168.0.5` 양쪽 모두 정상 응답 — 서비스 자체는 문제 없음

## What Didn't Work

아래 순서로 접근 좁혀갔으나 전부 실패:

1. **호스트 서비스를 `127.0.0.1`에 바인딩 + 컨테이너에 `--add-host=host.docker.internal:host-gateway`**
   컨테이너 내부에선 loopback 주소가 자기 netns 루프백이라 호스트 `127.0.0.1`에 닿지 못함. `host.docker.internal` alias는 선언됐으나 호스트 loopback이 이미 컨테이너 밖에서 접근 불가.

2. **호스트 서비스를 `0.0.0.0`에 바인딩 (모든 인터페이스) + host-gateway 유지**
   패킷 경로상 이론은 성립하나 Docker의 user-defined bridge iptables 규칙이 컨테이너 → 호스트 자기 IP로의 패킷을 FORWARD/MASQUERADE 체인에서 일관되게 허용하지 않음. 버전/환경별로 silent drop.

3. **Hindsight env의 `base_url`을 호스트 LAN IP(`192.168.0.5`)로 직접 지정 + `host.docker.internal` 의존 제거**
   컨테이너에서 LAN IP로 나가는 패킷이 bridge gateway → 호스트 iptables INPUT chain으로 가야 하지만, 호스트 자기 IP로 회귀하는 경로가 커널 loopback routing과 섞여 drop. timeout 여전.

공통 진단 단서: 시도마다 "timeout"이지만 **대상 서비스의 systemd journal에 요청 기록 0건**. timeout이 "응답 느림"이 아니라 "요청 미도달"임을 드러냄 — 네트워크 경로 문제.

## Solution

**Hindsight 컨테이너를 host network 모드로 전환 + hindsight-db만 bridge 유지 + publish.**

```nix
# systems/homelab/hindsight-stack.nix
virtualisation.oci-containers.containers = {
  hindsight-db = {
    image = images.db;
    # bridge 그대로 두되 127.0.0.1에 publish — host에서 localhost:5432로 접근
    ports = [ "127.0.0.1:5432:5432" ];
    # --network flag 제거 → Docker 기본 bridge
  };

  hindsight = {
    image = images.hindsight;
    environment = {
      # host network 모드 → 컨테이너 내부의 127.0.0.1 == 호스트 127.0.0.1
      HINDSIGHT_API_EMBEDDINGS_OPENAI_BASE_URL = "http://127.0.0.1:8091/v1";
      HINDSIGHT_API_RERANKER_COHERE_BASE_URL = "http://127.0.0.1:8090";
      HINDSIGHT_API_HOST = "0.0.0.0";  # 호스트 0.0.0.0:8888 listen
      HINDSIGHT_API_PORT = "8888";
      # ...
    };
    extraOptions = [ "--network=host" ];
  };
};
```

DB URL도 대응해 `sops.templates."services.env"`에서 호스트명 교체:

```nix
# systems/homelab/sops.nix
HINDSIGHT_API_DATABASE_URL=postgresql://hindsight:${config.sops.placeholder.HINDSIGHT_DB_PASSWORD}@127.0.0.1:5432/hindsight
```

부수 정리: user-defined `hindsight` bridge network + `init-hindsight-network.service` + `docker-hindsight.ExecStartPre`의 stale endpoint cleanup 전부 제거. bridge 자체가 사라지니 stale endpoint 클래스 문제 소멸.

배포 후 검증:
- `docker-hindsight`: `NRestarts=0`, `SubState=running`, `/health` → `{"status":"healthy","database":"connected"}`
- Embedding: dim=1024, L2 norm=1.0 (Harrier 스펙 일치)
- Reranker 스코어 분산: 0.979 / 0.034 / 9e-05 (의미론적 랭킹 정상)

## Why This Works

host network 모드는 컨테이너의 netns 분리를 포기 — **컨테이너가 호스트의 네트워크 스택을 그대로 공유**. 결과:

- `127.0.0.1`은 호스트 loopback과 동일. 호스트 `0.0.0.0`에 listen하는 프로세스는 즉시 가시
- bridge → 호스트 사이의 iptables FORWARD/MASQUERADE 체인을 **전혀 거치지 않음**. 환경별 불안정성 0
- Linux kernel의 loopback routing이 자기 IP 회귀를 처리할 필요 없음 — 그냥 loopback

트레이드오프:
- 컨테이너 간 네트워크 격리 상실. 하지만 homelab은 싱글 호스트 RAG, 격리 이득 적음
- 포트 충돌 위험. `:8888`이 호스트에서 직접 들림 — 다른 서비스와 겹치지 않게 관리. firewall 규칙도 호스트 단위로 일원화됨
- hindsight-db와의 내부 이름 해석(`hindsight-db:5432`) 불가 → publish + 127.0.0.1로 전환

## Prevention

1. **Docker 네트워크 모드 선택 기준**
   - **컨테이너 간 통신이 주 workload**: user-defined bridge 유지 (DB 클러스터, multi-service app). 내부 DNS 이름 해석이 가치
   - **컨테이너 ↔ 호스트 서비스 통신이 주 workload**: 처음부터 host network 모드 검토. bridge + `host.docker.internal` 조합은 환경별 불안정

2. **외부 노출 방어는 시스템 레벨 안전장치로**
   host network 모드라도 `HINDSIGHT_API_HOST=0.0.0.0`이 호스트 `0.0.0.0:8888`에 직접 listen. 보호는 `networking.firewall.enable = true`의 기본 거부 정책(allowed 목록에 명시되지 않은 포트 차단)으로 확보. Cloudflare Tunnel은 필요한 포트만 선택적으로 라우팅. (auto memory [claude]: `feedback_no_excessive_limits` — 앱에 과도한 제한 걸지 말고 시스템 레벨로 방어)

3. **디버깅 시 "timeout"을 재해석**
   destination 서비스의 로그가 **empty**한데 client는 timeout → 응답 느림 아니고 **요청 미도달**. 네트워크 경로 문제 의심:
   - `docker exec <container> getent hosts <name>` / `curl --max-time 3` 로 컨테이너 내부에서 직접 해상·접속 테스트
   - 호스트의 `ss -tlnp` + 대상 서비스 journal을 동시에 보고 LISTEN과 accept 분리

4. **systemd oneshot+RemainAfterExit 변경 시 `restartTriggers` 필수**
   부수 발견: NixOS `switch-to-configuration`은 `Type=oneshot` + `RemainAfterExit=true` 유닛을 **기본적으로 재실행 대상에서 제외** (이미 "완료된 work"로 간주). script 내용을 바꿔도 이전 실행 상태가 유지됨. 해결:

   ```nix
   let scriptVar = '' ... ''; in
   {
     systemd.services.foo = {
       script = scriptVar;
       restartTriggers = [ scriptVar ];  # 내용 hash 변경 시 강제 재실행
     };
   }
   ```

5. **소비자 측 자체 방어선 (선택)**
   네트워크 endpoint/리소스 충돌은 소비자(docker-hindsight 같은 서비스) 자체에서도 방어 가능:

   ```nix
   systemd.services.docker-hindsight.serviceConfig.ExecStartPre = lib.mkAfter [
     "-${pkgs.docker}/bin/docker network disconnect -f hindsight hindsight"
   ];
   ```
   `-` prefix로 실패 허용. 상류 초기화 유닛이 놓쳐도 자기 restart마다 정리.

## Related Issues

- Plan: `docs/plans/2026-04-17-001-feat-homelab-llamaswap-embedding-reranker-plan.md`
- 관련 커밋: `4e7ca687`(초기) → `bd8aaf7f` → `820b04eb` → `fe5852ca` → `2edd5518` → **`5d2d8f6a`(최종 host network)**
- Docker 문서: user-defined bridge 에서 `host.docker.internal:host-gateway` 동작은 Docker 버전/bridge 종류에 따라 상이 (공식 가이드 범위 외)
- Downstream fix: [`../performance-issues/hindsight-reranker-vulkan-acceleration-2026-04-19.md`](../performance-issues/hindsight-reranker-vulkan-acceleration-2026-04-19.md) — 본 doc의 host network 전환으로 확보된 `127.0.0.1:8090` endpoint가 이후 Vulkan iGPU 가속으로 CPU-only BLAS → Radeon 890M GPU로 upgrade됨
