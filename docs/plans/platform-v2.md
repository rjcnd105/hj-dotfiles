# Homelab Platform v2 마스터플랜

2026-08-28 확정. 세션 간 기준 문서. 진행 상태는 각 Phase 체크박스로 갱신한다.

## 확정된 결정

- GitHub 중심 유지. Forgejo/git 서버 도입 보류. k3s 미도입 (전환 트리거: 앱 3개+ 및 prod 본격 운영).
- 앱 DB는 호스트 공유 PostgreSQL(네이티브 `services.postgresql`)로 통합. 앱별 role/db 자동 프로비저닝.
- 배포 무결성 검증 단순화: release manifest는 유지(이미지 digest의 유일한 결정자)하되
  소스 해시 4종 대조는 전부 제거. 검증 = 앱명/target 패턴/이미지명/digest 문법/HTTPS origin.
- appctl은 Go 단일 바이너리로 재작성. argv ABI·metadata JSON·record 경로·sudo rule은 유지.
- sudo 운영권: hj에게 NOPASSWD 허용목록 (NixOS 선언, 비밀번호 저장 없음).
- 백업: restic → Cloudflare R2 (10GB 무료 티어 내). Immich 도입 시 미디어 전용 B2 repo 추가.
- 모니터링: Beszel — agent는 네이티브 모듈(호스트 지표는 컨테이너 불가), hub는 플랫폼
  서드파티 레인(pinned-digest). Cloudflare Access 게이트 필수.
- 앱 컨벤션: 컨테이너는 `PORT`(기본 3000) 리슨, 영속 데이터는 `/data` 단일 마운트,
  DB 필요 시 계약에 `needs.postgres = true` 한 줄.
- prod 채널: 구조에 자리만 (구현은 dev 단일).
- dev.deopjib.site 이관 다운타임 수 시간 허용.

## Phase 0 — 운영권 + 안전망

- [x] 0.1 `operator.nix`: hj NOPASSWD 허용목록 (systemctl/journalctl/podman/appctl/nix-collect-garbage/btrfs)
- [x] 0.2 comin `postDeploymentCommand` → Telegram 알림 (thermal-alert 배관 재사용)
- [x] 0.3 `nix.gc.automatic` + `nix.optimise.automatic`
- [x] 0.4 백업: 컨테이너 PG pg_dump 타이머 + restic→R2. **복원 리허설까지가 완료 기준.**
      (사용자 액션: R2 버킷 + API 토큰 생성 → sops 추가. 토큰 없이 restic 모듈을 먼저
      merge하지 말 것 — sops-install-secrets는 누락 키에서 switch를 죽인다.)

2026-08-28 완료. 검증: 첫 스냅샷 `3e36343d`(28KiB) 저장·retention 7d/4w 적용, R2에서
`restic dump`로 꺼내 동일 digest postgres 컨테이너에 복원 — 8테이블/약 937행으로 라이브
db(8테이블)와 일치. comin 훅은 성공 시 debug 로그만 남기므로 journal이 조용한 것이 정상
(실패 시에만 error 로그). 수동 리허설 편의를 위해 `restic-homelab` wrapper를 sudo
허용목록에 추가.

## Phase 1 — 플랫폼 v2: 계약·렌더러

- [x] 1.1 계약 v2 스키마 (컨벤션 반영, db 서비스 블록 삭제, `needs.postgres`)
- [x] 1.2 렌더러: PG 프로비저닝 모듈, admitApp helper, 다채널 자리
- [x] 1.3 flake.nix 픽스처 ~520줄 → `checks/` 분리 + 앱 파라미터화
- 검증: `nix eval` 생성물 스냅샷 비교, `just check`. 호스트 무변경(deopjib은 v1 경로 유지).

2026-08-28 완료. `contract.schemaVersion = 2`가 digest-only 검증(소스 해시 4종 금지)과
컨벤션(PORT=internalPort 주입, 기본 3000; `needs.postgres` → 공유 PG role/db + DATABASE_URL
합성)을 켠다. v2 앱 브리지는 `host.subnetId`로 10.90.N.0/24 고정, 게이트웨이 10.90.N.1이
호스트 PG 경로. `systems/homelab/postgres.nix`(postgresql_18, LoadCredential 비밀번호 동기화),
`admit-app.nix` 헬퍼, `checks/`(example v2 픽스처 nixosSystem eval 단정) 추가. 검증: 변경
전후 homelab toplevel drvPath 동일(2nb4pgd8…), flake check 전체 통과.

## Phase 2 — appctl v2 (Go)

- [x] `packages/homelab-appctl/`: deploy 트랜잭션 + retention(이미지 최근 3 id, 기록 최근 10개)
- [x] manifest v2 스키마 `{app, target, images{name,digest}}` + 앱 레포 generator 단순화
      (호스트 검증 + 가이드 완료 — v2는 jq 한 줄이면 manifest 생성, 전용 generator 불필요.
      deopjib 앱 레포 적용은 Phase 3 이관과 함께)
- [x] Go 단위 테스트 + 축소 E2E 스텁 1개 (buildGoModule checkPhase에서 실행)
- 검증: dry-run 출력 계약 테스트 → dev 실배포 1회.

2026-08-28 구현 완료. Go(stdlib 전용) 재작성: argv ABI·metadata JSON·record 경로·sudo
rule·dry-run 출력 계약 유지, v1(해시)·v2(digest-only) manifest 겸용 검증. 실제 deopjib
metadata로 dry-run 수락/변조 4종 거부 로컬 실측. bash 전용 check
2종(deploy-invariants grep, release-transaction)은 go test로 대체(Phase 5의
grep-invariants 삭제 항목 선반영). 배포 가이드를 v2 self-service 문서로 전면 개정
(앱 레포가 가이드만 보고 배포 가능해야 한다는 요구 반영). dev 실배포 검증 완료:
Go appctl 2.0.0 라이브에서 v0.16.2 → v0.17.0 왕복 실배포 2회, 풀 트랜잭션
(manifest 다운로드/검증 → digest pull → 태그 activate → migrate → 단일 restart →
smoke → record → 이미지 retention prune, 사용 중 이미지 보호 동작 확인) 및
동일 target no-op 판정 정상.

## Phase 3 — deopjib v2 이관 (다운타임 윈도우)

- [x] 1. 공유 PG role/db 생성 → 컨테이너 PG pg_dump → 복원 → 검증 쿼리
- [x] 2. 계약 v2 전환 + admission 갱신 + input 범프 → comin 활성화
- [x] 3. smoke + 실사용 확인 → 구 db 컨테이너 중지. **구 볼륨(deopjib-dev-db-data)은
      2026-09-11까지 보존 후 삭제 (롤백 창구).**
- [x] 4. 백업 대상을 호스트 PG dump로 전환, 복원 리허설 재실행
- [x] 앱 레포 선행 작업: backend/web PORT 3000 대응 (my-app#70).

2026-08-28 완료. 앱: runtime.exs PORT 우선, web nginx envsubst 템플릿, manifest v2를
CI에서 jq로 생성(전용 generator 삭제). 호스트(nix-dots#92): admit-app 전환(subnetId 10),
렌더러에 공유 PG systemd 의존성 배선, backup을 호스트 pg_dump(deopjib_dev)로 교체.
컷오버 실측: 덤프→switch→복원(행 수 8/8 일치)→v0.18.0 v2 실배포(마이그레이션·smoke
통과)→R2 복원 리허설 재실행(라이브와 일치). 발견·수정: homelab-postgres-credentials가
postgresql-setup(ensureUsers) 이전에 실행되어 ALTER ROLE이 조용히 실패 — after 순서
추가 + psql ON_ERROR_STOP=1. 구 sops 키 DEOPJIB_DEV_DATABASE_URL은 미사용(Phase 5
정리 대상).

## Phase 4 — 모니터링

- [x] beszel-agent 네이티브 + podman 소켓 (컨테이너별 지표)
- [x] beszel hub — **nixpkgs 네이티브**(계획서의 pinned-digest 컨테이너 대신; 사용자 확정),
      Caddy + cloudflared + Cloudflare Access
- [ ] llama-server UI/`/slots` 라우트
- 비목표: GPU 지표 (gfx1150 iGPU는 rocm-smi 미지원).

2026-08-28. `systems/homelab/beszel.nix`: hub(loopback 18091) + agent(loopback 45876,
`DOCKER_HOST=/run/docker.sock`), 노출은 `beszel.deopjib.site` → cloudflared → Caddy
vhost(18090) → hub. Cloudflare Access 앱/이메일 정책은 CF API로 생성
(`CLOUDFLARE_ACCESS_APPS_TOKEN`, workspace sops). 실측 결함 2건:

1. 패키지 실행 파일은 `bin/beszel-hub`(≠`bin/beszel`) — `203/EXEC` 재시작 루프.
   `homelab-unit-executables-exist` check 추가로 이 클래스를 CI에서 차단.
2. 새 sops secret과 소비 서비스를 같은 switch에 넣어 `243/CREDENTIALS`로 switch 실패
   (status 4). secret은 소비 서비스보다 **한 배포 먼저** 올려야 한다.

## Phase 5 — 문서·네이밍

- [ ] 가이드 재작성: placeholder `example-app`으로 (실레포 `my-app`과 충돌 해소), 자격증명 표, 컨벤션 문서화
- [ ] `deopjibRuntime` input 이름 정리, grep-invariants check 삭제

## 원칙

- Phase = 독립 PR. merge → comin 알림 수신 → sudo로 라이브 검증 후 다음 진행.
- 불확실한 결정은 진행 전에 사용자에게 질문.
- 최대 리스크는 Phase 3 (데이터 이관) — 백업이 반드시 선행.
