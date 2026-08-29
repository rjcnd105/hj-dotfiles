# Homelab App Deploy Guide (Contract v2)

대상: 자기 앱을 이 homelab에 배포하려는 앱 저장소의 에이전트/운영자.
이 문서만 보고 계약 작성 → 릴리스 발행 → 배포까지 그대로 따라갈 수 있어야 한다.
(deopjib이 아직 사용 중인 구 계약 v1은 [부록 A](#부록-a--계약-v1-레거시) 참고.)

## 큰 그림

```text
앱 레포 (당신)
  devops/runtime-contract.nix   ← 런타임 의도 (순수 Nix 데이터)
  devops/homelab-admission.nix  ← 호스트 바인딩 제안
  release manifest (v2)         ← 릴리스마다: 이미지 name + digest
                |
                v
nix-dots (호스트)
  admit-app.nix로 계약을 pin·승인 → Quadlet/Caddy/Cloudflared/sops/PG 렌더링
                |
                v
homelab-appctl deploy <app> <channel> --target <release-id>
  검증 → digest pull → 로컬 태그 이동 → migrate → 단일 restart → smoke → 기록
```

책임 경계:

| 관심사 | 권한 |
|---|---|
| 앱 버전·릴리스 target·이미지 빌드/발행 | 앱 저장소 |
| 런타임 서비스·routes·migrations 의도 | 앱 소유 `devops/runtime-contract.nix` |
| 승인·pin·secrets·네트워크·스토리지·PG | `nix-dots` |
| 실제 배포 트랜잭션·기록 | `homelab-appctl` (Go, `packages/homelab-appctl/`) |

## 플랫폼 컨벤션 (v2)

- **PORT**: 컨테이너는 env `PORT`에서 리슨한다. 호스트가 `PORT`(기본 3000,
  `internalPort`와 동일 값)를 주입한다. 다른 포트가 필요하면 `internalPort`만 바꾼다.
- **/data**: 영속 데이터는 단일 볼륨을 `/data`에 마운트한다.
- **PostgreSQL**: 계약에 `needs.postgres = true` 한 줄이면 호스트 공유 PG에
  role/db(`<name>_<channel>`)가 프로비저닝되고, 모든 서비스 env에 `DATABASE_URL`이
  주입된다. 계약은 `DATABASE_URL`을 직접 선언하면 안 된다(거부됨).
  앱 컨테이너는 db 서비스를 계약에 넣지 않는다.
- 공개 포트는 없다. 서비스는 loopback으로만 노출되고 Caddy + Cloudflared가 ingress다.

## 1. 앱 레포: runtime-contract.nix

`devops/runtime-contract.nix` — 순수 Nix 데이터 함수. nixpkgs import, secret 읽기,
I/O 금지. 전체 스키마를 담은 시작점:

```nix
{ channel, domain }:
let
  imageTag = "${channel}-current";
in
{
  schemaVersion = 2;
  name = "example"; # ^[a-z0-9][a-z0-9-]*$; "br-<name>-<channel>"이 15자 이하여야 함
  inherit channel;

  needs.postgres = true; # DB가 필요 없으면 생략

  images.app = "ghcr.io/OWNER/example-app:${imageTag}";

  services.app = {
    image = "app"; # images의 키
    # internalPort = 3000;      # 기본 3000. env PORT로 주입됨
    healthPath = "/health"; # 없으면 null
    updatePolicy = "manual"; # 릴리스 조율 배포 대상
    volumeMounts = [
      {
        volume = "data";
        mountPath = "/data";
      }
    ];
    # env = { ... };            # 정적 env
    # requiredSecretEnv = [ "MY_SECRET" ];  # sops secret 이름은 호스트 admission의 secretMap이 결정
    # dependsOn = [ "other-service" ];
    # readiness = { command = [ ... ]; interval = "1s"; retries = 30; timeout = "5s"; };
  };

  routes = [
    {
      host = domain;
      path = "/";
      service = "app";
    }
  ];

  # 수동 마이그레이션이 있으면:
  # migrations = { mode = "manual"; service = "app"; command = [ "/app/bin/migrate" ]; };

  release = {
    manifestUrl = "https://github.com/OWNER/example-app/releases/download/{target}/release.json";
    channels.${channel} = {
      tag = imageTag;
      targetPattern = "^example-v.*$"; # ^…$ 앵커 필수
      smokePaths = [ "/health" ];
      # migrate = "manual";  # migrations.mode = manual일 때
    };
  };

  volumes.data.notes = "persistent app data, mounted at /data";
}
```

핵심 규칙:

- `updatePolicy = "manual"` 서비스의 이미지는 `:<channel>-current` 태그로 끝나야
  한다. 이 태그는 로컬 활성화 포인터일 뿐, 배포되는 바이트는 항상 manifest의
  digest가 결정한다.
- `pinned-digest` 서비스(외부 인프라 이미지)는 `@sha256:<64hex>`로 끝나야 한다.
- v2에서 소스 해시 4종은 존재하지 않는다. 검증은 앱명/target 패턴/이미지명/digest
  문법/HTTPS origin으로 끝난다.

## 2. 앱 레포: homelab-admission.nix

`devops/homelab-admission.nix` — 호스트 바인딩 제안:

```nix
let
  runtimeContract = ./runtime-contract.nix;
in
{
  key = "example";
  app = {
    enable = true;
    contract = import runtimeContract {
      channel = "dev";
      domain = "dev.example.test";
    };
    host = {
      domain = "dev.example.test";
      loopbackPortBase = 18300; # 호스트에서 비어 있는 대역 (nix-dots가 확인)
      secretMap.MY_SECRET = "EXAMPLE_DEV_MY_SECRET"; # 계약 env 이름 → sops secret 이름
      volumes.data = { };
    };
  };
}
```

secret **값**은 절대 앱 레포에 두지 않는다. 이름만 매핑하면 호스트가 sops로
`/run/secrets/...`에 렌더링한다.

## 3. 앱 레포: release manifest v2

릴리스(GitHub Release 권장)마다 `release.json` 자산을 발행한다. 스키마 전체:

```json
{
  "schemaVersion": 2,
  "app": "example",
  "target": "example-v1.2.3",
  "images": {
    "app": {
      "name": "ghcr.io/OWNER/example-app",
      "digest": "sha256:<64 lowercase hex>"
    }
  }
}
```

- `images`의 키는 계약 `images`의 키와 같아야 하고, `name`은 태그를 뗀 이미지
  이름과 같아야 한다. `digest`는 레지스트리에 push된 정확한 digest다.
- 별도 generator 스크립트가 필요 없다. CI에서 이미지 push 후 얻은 digest로 jq 한
  번이면 된다:

```sh
digest=$(docker buildx imagetools inspect "ghcr.io/OWNER/example-app:${TAG}" --format '{{json .Manifest}}' | jq -r .digest)
jq -n --arg app example --arg target "example-v${VERSION}" --arg name ghcr.io/OWNER/example-app --arg digest "$digest" \
  '{schemaVersion: 2, app: $app, target: $target, images: {app: {name: $name, digest: $digest}}}' > release.json
gh release upload "example-v${VERSION}" release.json
```

`target`은 계약의 `targetPattern`과 일치해야 한다. 추가 필드(version, sourceRev
등)는 자유롭게 넣어도 무시된다.

## 4. nix-dots: 승인 (호스트 쪽 1회 작업)

`nix-dots` 쪽 PR 한 번 (앱 레포는 여기까지 관여하지 않는다):

1. `flake.nix` inputs에 앱 레포 추가 (`flake = false`).
2. `systems/homelab/app-admissions.nix`에서 헬퍼로 승인:

```nix
homelab.apps = import ./admit-app.nix {
  admission = import "${inputs.myApp}/devops/homelab-admission.nix";
  releaseManifestOrigins = [ "https://github.com/OWNER/example-app" ];
  host = {
    subnetId = 8; # 10.90.<id>.0/24 — 앱별 유일
    postgresPasswordSecret = "EXAMPLE_DEV_PG_PASSWORD"; # needs.postgres일 때
  };
};
```

3. sops(`secrets/homelab/services.yaml`)에 secretMap의 secret들과 PG 비밀번호를
   추가한다 (모두 문자열로).
4. `nix flake check --all-systems --no-build` 통과 확인 후 merge → comin이 활성화.

호스트가 렌더링하는 것: Quadlet 네트워크(고정 서브넷)/볼륨/컨테이너, sops env
템플릿, 공유 PG role/db + `DATABASE_URL`, Caddy 라우트, Cloudflared ingress,
`/etc/homelab-apps/<app>/<channel>.json` 메타데이터, 마이그레이션 oneshot 유닛.

## 5. 배포 실행

수동 (homelab에서, 또는 ssh):

```sh
homelab-appctl list
homelab-appctl deploy example dev --target example-v1.2.3 --dry-run
sudo -n homelab-appctl deploy example dev --target example-v1.2.3
homelab-appctl status example dev
homelab-appctl smoke example dev
homelab-appctl logs example dev
```

CI (앱 레포 → 호스트 레포 dispatch): `hj-dotfiles`의 `Deploy Homelab App`
workflow를 `workflow_dispatch`로 호출한다. 입력: `app`, `channel`, `target`.
self-hosted runner가 위의 `sudo -n homelab-appctl deploy`를 실행한다.

deploy 트랜잭션 (실패 시 자동 태그 복원):

1. 앱/채널 락 → 같은 target이 최신 성공 기록과 metadata까지 동일하면 no-op
2. manifest 다운로드(HTTPS만; GitHub private release는 호스트 토큰으로 REST API 해석) → 검증
3. 각 `name@digest` pull → 로컬 채널 태그 이동
4. 선언된 migration oneshot 1회
5. 릴리스 서비스 전체를 systemd 트랜잭션 1회로 restart (pinned 인프라는 건드리지 않음)
6. Caddy-loopback smoke → 기록(`/var/lib/homelab-appctl/<app>/<channel>/`)
7. retention: 배포 기록 최근 10개, 릴리스 이미지 name별 최근 3개 id 유지

pull/tag/migration 실패는 이전 태그로 복원된다. restart/smoke 실패는 정상이었던
target을 다시 deploy하는 것이 롤백이다(별도 rollback 부명령 없음 — 릴리스 권한을
둘로 만들지 않기 위해). 이미지 롤백은 DB 마이그레이션을 자동으로 되돌리지 않는다.

## 새 앱 체크리스트

앱 레포:
- [ ] `devops/runtime-contract.nix` (schemaVersion 2, PORT/`/data`/needs.postgres 컨벤션)
- [ ] `devops/homelab-admission.nix` (secret 이름 매핑만)
- [ ] CI: 이미지 push → digest로 release manifest v2 발행
- [ ] 컨테이너가 env `PORT`에서 리슨하는지 확인

nix-dots:
- [ ] flake input + `admit-app.nix` 승인 (subnetId, PG secret)
- [ ] sops secrets 추가 (문자열만)
- [ ] `nix flake check` → merge → comin 활성화 확인
- [ ] 첫 배포는 `--dry-run` 먼저, 이후 실배포 + smoke
- [ ] 데이터가 있으면 백업 대상 편입과 복원 리허설까지 끝내고 prod 승인

## 부록 A — 계약 v1 (레거시)

deopjib이 이관(Phase 3) 전까지 사용하는 구 형식. 차이점:

- `schemaVersion` 없음(=1). release manifest는 `schemaVersion: 1`이며
  `sourceRev`와 `deploymentContract`의 소스 해시 4종
  (runtime/admission/schema/generator)이 admission 메타데이터와 일치해야 한다.
- 승인 시 `builtins.hashFile`로 4종 해시를 계산해 붙인다
  (`systems/homelab/app-admissions.nix`의 deopjib 항목 참고).
- db를 계약 안의 `pinned-digest` 서비스로 직접 운영한다.
- 런타임 의도가 바뀌면: 앱 계약 merge → nix-dots input 범프 merge → comin 활성화
  → 그 다음에야 새 해시의 release가 배포된다.

v1 관련 상세가 필요하면 git 히스토리의 이 파일 이전 버전을 참고.
