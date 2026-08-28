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

- [ ] 0.1 `operator.nix`: hj NOPASSWD 허용목록 (systemctl/journalctl/podman/appctl/nix-collect-garbage/btrfs)
- [ ] 0.2 comin `postDeploymentCommand` → Telegram 알림 (thermal-alert 배관 재사용)
- [ ] 0.3 `nix.gc.automatic` + `nix.optimise.automatic`
- [ ] 0.4 백업: 컨테이너 PG pg_dump 타이머 + restic→R2. **복원 리허설까지가 완료 기준.**
      (사용자 액션: R2 버킷 + API 토큰 생성 → sops 추가. 토큰 없이 restic 모듈을 먼저
      merge하지 말 것 — sops-install-secrets는 누락 키에서 switch를 죽인다.)

## Phase 1 — 플랫폼 v2: 계약·렌더러

- [ ] 1.1 계약 v2 스키마 (컨벤션 반영, db 서비스 블록 삭제, `needs.postgres`)
- [ ] 1.2 렌더러: PG 프로비저닝 모듈, admitApp helper, 다채널 자리
- [ ] 1.3 flake.nix 픽스처 ~520줄 → `checks/` 분리 + 앱 파라미터화
- 검증: `nix eval` 생성물 스냅샷 비교, `just check`. 호스트 무변경(deopjib은 v1 경로 유지).

## Phase 2 — appctl v2 (Go)

- [ ] `packages/homelab-appctl/`: deploy 트랜잭션 + retention(이미지 최근 K digest, 기록 최근 N개)
- [ ] manifest v2 스키마 `{app, target, images{name,digest}}` + 앱 레포 generator 단순화
- [ ] Go 단위 테스트 + 축소 E2E 스텁 1개
- 검증: dry-run 출력 계약 테스트 → dev 실배포 1회.

## Phase 3 — deopjib v2 이관 (다운타임 윈도우)

1. 공유 PG role/db 생성 → 컨테이너 PG pg_dump → 복원 → 검증 쿼리
2. 계약 v2 전환 + admission 갱신 + input 범프 → comin 활성화
3. smoke + 실사용 확인 → 구 db 컨테이너 중지. **구 볼륨은 2주 보존 후 삭제 (롤백 창구).**
4. 백업 대상을 호스트 PG dump로 전환, 복원 리허설 재실행
- 앱 레포 선행 작업: backend/web PORT 3000 대응.

## Phase 4 — 모니터링

- [ ] beszel-agent 네이티브 + podman 소켓 (컨테이너별 지표)
- [ ] beszel hub — 플랫폼 서드파티 레인, Caddy + cloudflared + Cloudflare Access
- [ ] llama-server UI/`/slots` 라우트
- 비목표: GPU 지표 (gfx1150 iGPU는 rocm-smi 미지원).

## Phase 5 — 문서·네이밍

- [ ] 가이드 재작성: placeholder `example-app`으로 (실레포 `my-app`과 충돌 해소), 자격증명 표, 컨벤션 문서화
- [ ] `deopjibRuntime` input 이름 정리, grep-invariants check 삭제

## 원칙

- Phase = 독립 PR. merge → comin 알림 수신 → sudo로 라이브 검증 후 다음 진행.
- 불확실한 결정은 진행 전에 사용자에게 질문.
- 최대 리스크는 Phase 3 (데이터 이관) — 백업이 반드시 선행.
