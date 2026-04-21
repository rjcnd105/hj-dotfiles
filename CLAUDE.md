# nix-dots

Nix flake macOS dotfiles (nix-darwin + home-manager).

## Build & Verify

- `just build_hj-workspace` — 빌드만 (검증용, 자율실행 OK)
- `just darwin-switch` — 빌드+적용. **macOS 서비스 재시작 → 사용자 확인 필수**
- `nixfmt <file>` — Nix 포맷팅
- `darwin-rebuild` 직접 호출 금지 — justfile 사용

## Architecture

### Naming Convention

hosts 맵(flake.nix) key = `{host}_{user}`:

| 식별자 | 값 | 용도 |
|--------|-----|------|
| flake key | `workspace_hj` | flake 참조 (`--flake .#workspace_hj`) |
| hostName (`$USER_HOST`) | `workspace` | 디렉토리명 (`systems/workspace/`, `files/workspace/`) |
| userName (`$USER`) | `hj` | 사용자 디렉토리 |

### Module Resolution

`getModulePaths`(flake.nix) 6경로 시도, 존재만 로드:

```
{prefix}/default.nix
{prefix}/{system}/default.nix
{prefix}/{system}/{host}/default.nix
{prefix}/{system}/{host}/{user}/default.nix
{prefix}/{host}/default.nix                ← system-skip shortcut
{prefix}/{host}/{user}/default.nix         ← system-skip shortcut
```

prefix = `systems`, `homes`.

### Module Layers

- `systems/` — nix-darwin 시스템설정. `getModulePaths "systems"` 로드
- `homes/` — home-manager 사용자설정. `getModulePaths "homes"` 로드
- `sharedHome/` — 전 호스트 공유 home-manager 모듈. **변경 → 전체 호스트 영향**
- `files/workspace/` — 정적 dotfiles. `homes/file.nix`가 `~/`로 재귀 심링크. `.manual-link` 있는 디렉토리 통째 링크

호스트별: `systems/workspace/`, `homes/workspace/`, `files/workspace/`, `secrets/workspace/`

- `docs/solutions/` — 과거 해결한 문제와 베스트 프랙티스 문서. 카테고리별 구성, YAML frontmatter(`module`, `tags`, `problem_type`)로 검색 가능. 특정 모듈(예: `homelab`, `jj`, `hindsight-memory-plugin`)에서 구현·디버깅·의사결정 시 같은 도메인의 prior solution 확인에 유용

### myOptions

전 모듈 `specialArgs` 전달 컨텍스트 객체 (flake.nix):

`key`, `email`, `system`, `hostName`, `userName`, `paths`, `absoluteProjectPath`

모듈 작성 시 `myOptions` 필수. 나머지(`config`, `lib`, `inputs`, `pkgs` 등) 기존 모듈 시그니처 참조.

## Secrets

sops-nix + age 암호화. `.sops.yaml` creation_rules 정의.
- 편집: `sops secrets/workspace/secrets.yaml`
- **평문 비밀 커밋 절대 금지**

## Plans

plan → `docs/plans/` 저장.

## Nix LSP (nixd)

본 프로젝트는 `claude-code-lsps` 플러그인으로 nixd LSP가 세션에 등록되어 있다 (`~/.claude/plugins/cache/claude-code-lsps/nixd/1.0.0/.lsp.json`). `.nix` 파일을 다룰 때 텍스트 읽기만으론 option path, attribute 정의, 타입 정보 resolution이 불가하므로 다음 규칙을 따른다.

1. **세션 초기화**: Nix 파일 분석이 예상되는 세션 시작 시 `ToolSearch` 호출로 `LSP` deferred tool schema를 선제 로드한다:
   ```
   ToolSearch(query: "select:LSP", max_results: 1)
   ```
   한 번 로드된 schema는 세션 동안 유효. 비용 거의 0.
2. **LSP 사용 시점**: 아래 상황에서 Read/Grep 대신(또는 병행) `LSP` tool 활용:
   - `myOptions.*`, `flake.inputs.*`, `config.services.*` 등 **attribute/option path resolution**
   - nix-darwin 또는 home-manager **option 정의/타입 확인** (예: `users.users.<name>.linger`의 타입)
   - `import`, `callPackage`, `getFlake` 같은 **cross-file symbol 추적**
   - 모듈 평가 에러 진단 (타입 불일치, undefined attribute)
3. **Fallback**: `LSP` tool이 deferred 목록에 없거나 nixd 바이너리 부재 시 조용히 Read/Grep으로 fallback. 에러 시 사용자에게 bubble up.
4. **무관한 파일**: 문서, JSON, YAML 등 Nix 아닌 파일은 LSP 경로 건너뛸 것.

관련: `docs/solutions/developer-experience/nix-zed-lsp-nixd-switch-2026-03-26.md` (Zed 에디터 nixd 설정, 동일 바이너리 공유).

## graphify

This project has a graphify knowledge graph at graphify-out/.

Rules:
- Before answering architecture or codebase questions, read graphify-out/GRAPH_REPORT.md for god nodes and community structure
- If graphify-out/wiki/index.md exists, navigate it instead of reading raw files
- After modifying code files in this session, run `graphify update .` to keep the graph current (AST-only, no API cost)
