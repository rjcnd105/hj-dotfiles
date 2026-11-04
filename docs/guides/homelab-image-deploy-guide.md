# Homelab App Deploy Guide (Contract v2)

대상: 자기 앱을 이 homelab에 배포하려는 앱 저장소의 에이전트/운영자.
이 문서만 보고 계약 작성 → 릴리스 발행 → 배포까지 그대로 따라갈 수 있어야 한다.
(구 계약 v1은 [부록 A](#부록-a--계약-v1-레거시) 참고. 지금 v1을 쓰는 앱은 없다.)

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

GHCR 패키지는 Public이어야 한다. 호스트는 레지스트리 인증 없이 pull한다
(`host.registryAuth` 미설정, `homelab.registryAuths` 없음). private 저장소에서 처음
push한 패키지는 private로 생기고 공개 여부를 바꾸는 API가 없으므로, 첫 push 뒤
`https://github.com/users/OWNER/packages/container/<package>/settings` →
Change visibility → Public으로 바꾼다. 이미지에는 공개 사이트가 이미 서빙하는
산출물만 넣는다.

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
4. 공개 hostname의 DNS를 만든다. 호스트는 Cloudflared ingress만 렌더링하고 DNS
   레코드는 만들지 않는다. 기존 레코드에서 tunnel 대상을 읽어 같은 형식으로 추가한다:

   ```sh
   cf dns records list -z deopjib.cc --content-contains cfargotunnel.com   # 대상 확인
   cf dns records create -z deopjib.cc --body '{"type":"CNAME","name":"<host>.deopjib.cc","content":"<tunnel-id>.cfargotunnel.com","proxied":true,"ttl":1}'
   ```

5. 브랜치에서 `Nix` workflow(또는 `nix flake check --all-systems --no-build`) 통과를
   확인하고 `main`을 그 커밋으로 fast-forward한다 → comin이 활성화. `main`은 앱
   업데이트 커밋으로 자주 움직이므로 push 직전에 최신 `main` 위로 rebase하고
   `nix eval .#nixosConfigurations.homelab_hj.config.system.build.toplevel.drvPath`로
   다시 평가한다. 활성화 중 cloudflared가 재시작해 전체 hostname이 잠깐 530(1033)을
   반환한다.

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

이 workflow를 직접 부르는 경우는 앱의 prod promotion workflow와 첫 배포뿐이다. dev release는 공통 action 한 스텝으로 배포를 요청한다:

```yaml
- uses: rjcnd105/hj-dotfiles/.github/actions/homelab-deploy@main
  with:
    token: ${{ secrets.HOMELAB_DEPLOY_DISPATCH_TOKEN }}
    app: example
    channel: dev
    target: ${{ env.TARGET }}
    contract-paths: >-
      devops/runtime-contract.nix
      devops/homelab-admission.nix
```

action은 `flake.lock`에 잠긴 앱 revision과 현재 커밋의 `contract-paths` blob을
비교한다. 그대로면 `Deploy Homelab App`을 바로 호출한다. 바뀌었으면
`Admit Homelab App`을 호출한다. 이 workflow는 `homelab-prod` 승인을 기다린 뒤 해당
앱 input만 올리고, `Nix` 검사를 통과하면 `main`을 fast-forward하고, 요청한 채널의
배포를 호출한다. 배포 job은 호스트가 dispatch 시점의 `main`을 활성화하고 모델
다운로드를 끝낼 때까지 기다린다. 다운로드가 실패해 재시도를 기다리는 순간에는 대기를
통과할 수 있다.

승인이 필요한 이유는 계약이 secret 이름, 이미지, route를 정하고 root가 이를 적용하기
때문이다. dev와 prod가 같은 input을 쓰므로 승인하면 prod의 env, 모델, 컨테이너
재시작도 prod 승격 전에 함께 적용된다. env template이 바뀌면 sops 재시작으로 다른 앱과
cloudflared도 함께 재시작된다. 실행 요약의 compare 링크에서 계약 파일을 보고 승인한다.

앱 레포의 dispatch secret은 새 PAT를 만들지 않고 계정 단위 `gh` CLI 토큰으로
등록한다(deopjib과 같은 방식):

```sh
gh auth token | gh secret set HOMELAB_DEPLOY_DISPATCH_TOKEN -R OWNER/example-app
```

첫 배포는 admission 활성화 뒤 직접 dispatch한다:
`gh workflow run deploy-homelab-app.yml -R rjcnd105/hj-dotfiles -f app=<key> -f channel=<channel> -f target=<release-id>`.
그 전까지 릴리스 서비스 unit은 `<channel>-current` 태그가 없어 `ExecCondition`으로
시작을 건너뛴다(실패가 아니므로 switch를 깨지 않는다).

deploy 트랜잭션 (실패 시 자동 태그 복원):

1. 앱/채널 락 → 같은 target이 최신 성공 기록과 metadata까지 동일하면 no-op
2. manifest 다운로드(HTTPS만; GitHub private release는 호스트 토큰으로 REST API 해석) → 검증
3. 각 `name@digest` pull → 로컬 채널 태그 이동
4. 선언된 migration oneshot 1회
5. 릴리스 서비스 전체를 systemd 트랜잭션 1회로 restart (pinned 인프라는 건드리지 않음)
6. Caddy-loopback smoke → 기록(`/var/lib/homelab-appctl/<app>/<channel>/`)
7. retention: 배포 기록 최근 10개, 릴리스 이미지 name별 태그 없는 최근 3개 id 유지.
   채널끼리 이미지 이름을 공유하므로 태그가 남은 id(다른 채널의 `-current`)는 지우지 않는다

pull/tag/migration 실패는 이전 태그로 복원된다. restart/smoke 실패는 정상이었던
target을 다시 deploy하는 것이 롤백이다(별도 rollback 부명령 없음 — 릴리스 권한을
둘로 만들지 않기 위해). 이미지 롤백은 DB 마이그레이션을 자동으로 되돌리지 않는다.

## 에이전트 운영 절차

배포, 릴리스 추적, 실패 복구는 이 절차를 따른다. 호스트 레포가 없는 앱 레포에서는
이렇게 읽는다:

```sh
gh api repos/rjcnd105/hj-dotfiles/contents/docs/guides/homelab-image-deploy-guide.md -H 'Accept: application/vnd.github.raw+json'
```

1. **요청한다.** 앱 CI를 실행하는 것이 곧 배포 요청이다. 트리거, paths 필터, 채널은 그
   앱의 CI 파일이 정한다. `flake.lock`은 workflow가 올린다. `homelab-deploy` action을 쓰는
   스텝이 끝나면 완료다.
2. **찾는다.** 그 스텝의 요약에 경로와 추적 명령이 있다. 실행 제목은
   `Deploy <app>/<channel> <target>` 또는 `Admit <app> <target>`이다. 제목이 일치하는
   실행을 찾으면 완료다.

   ```sh
   gh run list -R rjcnd105/hj-dotfiles --workflow deploy-homelab-app.yml --json displayTitle,status,conclusion,url
   gh run list -R rjcnd105/hj-dotfiles --workflow admit-homelab-app.yml --json displayTitle,status,conclusion,url
   ```

3. **승인을 넘긴다.** `homelab-prod` 승인은 사람의 몫이다. 상태가 `waiting`이면 실행 URL과
   target을 사람에게 전하고, 승인되거나 실행이 끝날 때까지 기다린다. 상태가 `pending`이면 같은 앱의
   앞선 실행이 막고 있다. 목록에서 `waiting`인 실행의 URL을 전한다. 앞선 실행이 끝나면 내 실행도
   다시 승인이 필요하다.
4. **확인한다.** `Admit`은 성공할 때 `Deploy` 실행을 새로 만든다. `Deploy <app>/<channel> <target>`이
   `success`이면 완료다. appctl이 smoke까지 통과했거나, 같은 target의 성공 기록이 있어 no-op으로 끝난 결과다. `Admit`이 실패로 끝나면 `Deploy`는
   생기지 않으니 아래 표를 본다.
5. **prod로 올린다.** prod는 앱 레포의 승격 workflow로 요청하고 3번과 같이 승인을 넘긴다.

호스트 명령(`comin status`, `homelab-appctl logs`)은 ssh가 필요하다. ssh가 없으면 오류 문구와
실행 URL을 사람에게 보고한다.

오류 문구는 `gh run view <id> -R rjcnd105/hj-dotfiles`의 `ANNOTATIONS`와 `--log-failed` 출력에서 읽는다.
다음 표에서 문구를 찾아 조치한다:

| 오류 문구 | 의미 | 다음 조치 |
|---|---|---|
| `missing HOMELAB_DEPLOY_DISPATCH_TOKEN` | 배포가 요청되지 않았다. `was published`면 릴리스는 발행됐고, `refusing to publish`면 발행 전에 멈췄다 | 섹션 5로 secret을 등록하고 앱 CI 재실행 |
| `is not a flake input` 또는 `is not a flake = false root input` | 호스트에 앱이 없다 | 섹션 4의 첫 승인을 사람에게 요청 |
| `contract path ... is not a file` | `contract-paths`가 틀렸거나 토큰에 앱 레포 읽기 권한이 없다 | 앱 CI의 경로와 토큰 권한 확인 |
| `HTTP 401` 또는 `HTTP 403` | dispatch 토큰이 만료됐거나 권한이 부족하다 | 사람에게 보고 |
| `The deployment was rejected` | `Admit` 또는 `Deploy`의 승인이 거부됐다 | `gh api repos/rjcnd105/hj-dotfiles/actions/runs/<id>/approvals`로 확인하고 사람에게 확인 |
| `Admit` 또는 `Deploy`가 `cancelled` | 같은 앱의 더 새 요청에 밀렸다 | 더 새 실행에 대해 3번부터 |
| `The runner has received a shutdown signal` 또는 `lost communication` | 호스트 활성화나 재부팅이 runner를 멈췄다 | runner가 돌아온 뒤 실패한 job 재실행 |
| `is not on` | 기본 브랜치에 없는 커밋이다 | 병합 뒤 다시 릴리스 |
| `refusing to move ... (behind)` | 더 새 커밋이 이미 채택됐다 | 조치 없음. 더 새 target을 배포 |
| `refusing to move ... (diverged)` | 앱 기본 브랜치가 잠긴 커밋을 잃었다 | 사람에게 보고 |
| `Nix` check 실패 | 계약이 호스트 검사에 어긋난다. 서비스, 이미지, secret 추가는 호스트 수정도 필요하다 | 로그를 보고 수정. 앱 수정은 새 릴리스, 호스트 수정은 전체 재실행 또는 새 릴리스. 실패한 job 재실행은 같은 revision을 다시 검사하므로 일시적 실패에만 쓴다 |
| `main moved during the checks; dispatched` | 새 Admit이 만들어졌다 | 새 실행에 대해 3번부터 |
| `main moved during the checks; the queued` | 대기 중인 더 새 Admit이 대신한다 | 그 실행에 대해 3번부터 |
| `main rejected` | 브랜치 보호가 거부했다. 서명 누락 가능성이 크다 | 사람에게 보고 |
| `host did not finish activating` | 괄호 안 값이 원인이다. `compare`가 `behind` 또는 `diverged`면 comin 미완료나 실패, `unknown`이면 GitHub API 또는 revision 조회 실패, `switch lock held`면 활성화 중, `model loader active`면 모델 다운로드 중이다. `Admit` 경로로 왔으면 `main`에는 lock이 남아 있다 | `comin status` 확인. 성공했고 다운로드가 끝났으면 실패한 job 재실행, 그 외에는 사람에게 보고. 이 상태에서는 모든 배포가 같은 대기에 막히므로 긴급 복구는 ssh 가능한 사람이 `sudo -n homelab-appctl deploy <app> <channel> --target <정상 target>`을 실행한다 |
| `timed out waiting for deploy lock` | 같은 앱/채널의 다른 배포가 진행 중이다 | 그 배포가 끝난 뒤 실패한 job 재실행 |
| `appctl` 또는 smoke 실패 | 배포가 실패했다 | `homelab-appctl logs <app> <channel>` 확인. 복구는 정상 target 재배포 |
| 표에 없는 `Process completed with exit code 1` | 위 원인에 해당하지 않는 실패다 | `--log-failed`를 읽고 오류 문구와 실행 URL을 사람에게 보고 |

## 새 앱 체크리스트

앱 레포:
- [ ] `devops/runtime-contract.nix` (schemaVersion 2, PORT/`/data`/needs.postgres 컨벤션)
- [ ] `devops/homelab-admission.nix` (secret 이름 매핑만)
- [ ] CI: 이미지 push → digest로 release manifest v2 발행
- [ ] 컨테이너가 env `PORT`에서 리슨하는지 확인
- [ ] 첫 push 뒤 GHCR 패키지 Public 전환
- [ ] `gh auth token`으로 `HOMELAB_DEPLOY_DISPATCH_TOKEN` 등록
- [ ] CI 마지막 스텝을 `rjcnd105/hj-dotfiles/.github/actions/homelab-deploy@main`으로 (섹션 5)
- [ ] `AGENTS.md`에 포인터 추가: 배포, 런타임 계약, 실패 복구는 이 가이드의 `에이전트 운영 절차`를 따른다

nix-dots:
- [ ] flake input + `admit-app.nix` 승인 (subnetId, PG secret)
- [ ] sops secrets 추가 (문자열만)
- [ ] `cf`로 hostname CNAME(tunnel, proxied) 추가
- [ ] CI 통과 → 최신 `main` 위로 rebase·eval → fast-forward → comin 활성화 확인
- [ ] 첫 배포는 `--dry-run` 먼저, 이후 실배포 + smoke
- [ ] 데이터가 있으면 백업 대상 편입과 복원 리허설까지 끝내고 prod 승인

## 부록 A — 계약 v1 (레거시)

지금 이 형식을 쓰는 앱은 없다. `manifest.go`와 `app-containers.nix`에 남은 v1 분기를 읽을 때만 필요하다. 차이점:

- `schemaVersion` 없음(=1). release manifest는 `schemaVersion: 1`이며
  `sourceRev`와 `deploymentContract`의 소스 해시 4종
  (runtime/admission/schema/generator)이 admission 메타데이터와 일치해야 한다.
- 승인 시 `builtins.hashFile`로 4종 해시를 계산해 붙인다.
- db를 계약 안의 `pinned-digest` 서비스로 직접 운영한다.
- 런타임 의도가 바뀌면: 앱 계약 merge → nix-dots input 범프 merge → comin 활성화
  → 그 다음에야 새 해시의 release가 배포된다.

v1 관련 상세가 필요하면 git 히스토리의 이 파일 이전 버전을 참고.
