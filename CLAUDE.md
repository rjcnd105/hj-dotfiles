# nix-dots

Nix flake macOS dotfiles (nix-darwin + home-manager).

## Build & Verify

- `just build_hj-workspace` — 빌드만 (검증용, 자율실행 OK)
- `just darwin-switch` — 빌드+적용. **macOS 서비스 재시작 → 사용자 확인 필수**
- `nixfmt <file>` — Nix 포맷팅
- `darwin-rebuild` 직접 호출 금지 — justfile이 `createEnv.sh`로 `env.nix` 생성해야 빌드 동작
- `env.nix` 자동생성 — 수정 금지

## Architecture

### Naming Convention

hosts 맵(flake.nix:42-47) key = `{host}_{user}`:

| 식별자 | 값 | 용도 |
|--------|-----|------|
| flake key | `workspace_hj` | flake 참조 (`--flake .#workspace_hj`) |
| hostName (`$USER_HOST`) | `workspace` | 디렉토리명 (`systems/workspace/`, `files/workspace/`) |
| userName (`$USER`) | `hj` | 사용자 디렉토리 |

### Module Resolution

`getModulePaths`(flake.nix:56-65) 6경로 시도, 존재만 로드:

```
{prefix}/default.nix
{prefix}/{system}/default.nix
{prefix}/{system}/{host}/default.nix
{prefix}/{system}/{host}/{user}/default.nix
{prefix}/{host}/default.nix                ← system-skip shortcut
{prefix}/{host}/{user}/default.nix         ← system-skip shortcut
```

prefix = `systems`, `homes` (flake.nix:87-88).

### Module Layers

- `systems/` — nix-darwin 시스템설정. `getModulePaths "systems"` 로드
- `homes/` — home-manager 사용자설정. `getModulePaths "homes"` 로드
- `sharedHome/` — 전 호스트 공유 home-manager 모듈. **변경 → 전체 호스트 영향**
- `files/workspace/` — 정적 dotfiles. `homes/file.nix`가 `~/`로 재귀 심링크. `.manual-link` 있는 디렉토리 통째 링크

호스트별: `systems/workspace/`, `homes/workspace/`, `files/workspace/`, `secrets/workspace/`

### myOptions

전 모듈 `specialArgs` 전달 컨텍스트 객체 (flake.nix:78-85):

`key`, `email`, `system`, `hostName`, `userName`, `paths`, `absoluteProjectPath`

모듈 작성 시 `myOptions` 필수. 나머지(`config`, `lib`, `inputs`, `pkgs` 등) 기존 모듈 시그니처 참조.

## Secrets

sops-nix + age 암호화. `.sops.yaml` creation_rules 정의.
- 편집: `sops secrets/workspace/secrets.yaml`
- **평문 비밀 커밋 절대 금지**

## Plans

plan → `docs/plans/` 저장.