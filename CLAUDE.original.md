# nix-dots

Nix flake 기반 macOS dotfiles (nix-darwin + home-manager).

## Build & Verify

- `just build_hj-workspace` — 빌드만 수행 (검증용, 자율 실행 OK)
- `just darwin-switch` — 빌드 + 시스템 적용. **macOS 서비스를 재시작하므로 사용자 확인 후 실행할 것**
- `nixfmt <file>` — Nix 파일 포맷팅
- `darwin-rebuild`를 직접 호출하지 말 것 — justfile이 `createEnv.sh`로 `env.nix`를 생성해야 빌드가 동작함
- `env.nix`는 자동생성 파일 — 절대 수정하지 말 것

## Architecture

### Naming Convention

hosts 맵(flake.nix:42-47)의 key는 `{host}_{user}` 형태:

| 식별자 | 값 | 용도 |
|--------|-----|------|
| flake key | `workspace_hj` | flake 참조 (`--flake .#workspace_hj`) |
| hostName (`$USER_HOST`) | `workspace` | 디렉토리명 (`systems/workspace/`, `files/workspace/`) |
| userName (`$USER`) | `hj` | 사용자 디렉토리 |

### Module Resolution

`getModulePaths`(flake.nix:56-65)가 6개 경로를 시도하고, 존재하는 것만 로드한다:

```
{prefix}/default.nix
{prefix}/{system}/default.nix
{prefix}/{system}/{host}/default.nix
{prefix}/{system}/{host}/{user}/default.nix
{prefix}/{host}/default.nix                ← system-skip shortcut
{prefix}/{host}/{user}/default.nix         ← system-skip shortcut
```

prefix는 `systems`와 `homes` 두 가지로 호출됨 (flake.nix:87-88).

### Module Layers

- `systems/` — nix-darwin 시스템 설정. `getModulePaths "systems"`로 로드
- `homes/` — home-manager 사용자 설정. `getModulePaths "homes"`로 로드
- `sharedHome/` — 모든 호스트가 import하는 공유 home-manager 모듈. **변경 시 전체 호스트에 영향**
- `files/workspace/` — 정적 dotfiles. `homes/file.nix`가 `~/`로 재귀 심링크. `.manual-link` 파일이 있는 디렉토리는 통째로 링크됨

호스트별 경로: `systems/workspace/`, `homes/workspace/`, `files/workspace/`, `secrets/workspace/`

### myOptions

모든 모듈에 `specialArgs`로 전달되는 컨텍스트 객체 (flake.nix:78-85):

`key`, `email`, `system`, `hostName`, `userName`, `paths`, `absoluteProjectPath`

모듈 작성 시 `myOptions`는 항상 포함. 나머지 인자(`config`, `lib`, `inputs`, `pkgs` 등)는 기존 유사 모듈의 시그니처를 참조할 것.

## Secrets

sops-nix + age 암호화. `.sops.yaml`에 creation_rules 정의.
- 비밀 편집: `sops secrets/workspace/secrets.yaml`
- **평문 비밀을 절대 커밋하지 말 것**

## Plans

이 프로젝트의 plan은 `docs/plans/`에 저장한다.
