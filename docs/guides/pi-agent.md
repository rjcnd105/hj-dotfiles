# Pi 개인 에이전트 설정

이 flake는 Pi 설정을 `files/workspace/.config/pi/`에 보관하고 Home Manager가 각 파일을 `~/.pi/agent/`에 쓰기 가능한 out-of-store 심볼릭 링크로 연결한다. `auth.json`, 세션, 패키지 캐시는 Pi가 로컬에서 관리한다. OMP는 사용하지 않는다.

Pi는 agent 디렉터리에서 컨텍스트 파일을 하나만 읽는다. 그래서 `~/.pi/agent/AGENTS.md`는 APM이 생성한 공용 지침 `files/workspace/.codex/AGENTS.md`에 연결하고, Pi 전용 지침은 `files/workspace/.config/pi/APPEND_SYSTEM.md`에 둔다. 공용 지침은 `.apm/instructions/`에서 수정하고 [APM 절차](../solutions/tooling-decisions/apm-codex-first-agent-settings-2026-07-30.md#workflow)로 다시 생성한다. 단, 신뢰한 프로젝트에 `.pi/APPEND_SYSTEM.md`가 있으면 그 파일이 전역 `APPEND_SYSTEM.md`를 대체한다.

[작업별 사용법과 복사 가능한 요청 예시](pi-agent-workflows.md), [커뮤니티 벤치마크 해석과 직접 테스트 결과](pi-agent-validation.md)를 함께 참고한다.

## 고정한 구성

| 구성 | 버전 | 용도 |
|---|---|---|
| Pi CLI | 0.87.1 | OpenAI 구독과 OpenRouter 모델 실행 |
| [pi-subagents](https://github.com/nicobailon/pi-subagents) | 0.73.1 | Sol/xhigh의 독립된 작업 문맥과 결과 회수 |
| [pi-mcp-adapter](https://github.com/nicobailon/pi-mcp-adapter) | 3.2.0 | 단일 프록시와 필요한 시점의 서버 연결 |
| [pi-vcc](https://github.com/sting8k/pi-vcc) | 0.8.0 | 모델 호출 없는 세션 압축과 현재 세션 원문 재검색 |
| [pi-interactive-shell](https://github.com/nicobailon/pi-interactive-shell) | 0.17.0 | 입력이 필요한 CLI를 Pi 안의 PTY에서 실행하고 출력 확인 |
| [pi-ask-user](https://github.com/edlsh/pi-ask-user) | 0.15.1 | 결정이 필요할 때 선택지·다중 선택·자유 입력으로 사용자에게 묻는 `ask_user` 도구 |
| 로컬 `prompt-snippets` 확장 | 저장소 관리 | `/snippets`에서 이번 요청에 붙일 짧은 작업 지침 선택 |
| 로컬 `analyze-sessions` 스킬 | 저장소 관리 | Pi 세션의 비용·반복 요청·과거 대화를 읽기 전용 분석 |

두 로컬 기능은 [amosblomqvist/pi-config의 `f82da56`](https://github.com/amosblomqvist/pi-config/tree/f82da563ab05d66729492d64c7ed4e96db3663f3)를 바탕으로 이 설정에 맞췄다. 원본은 `files/workspace/.config/pi/extensions/prompt-snippets/`와 `skills/analyze-sessions/`이며 Home Manager가 각각 Pi의 확장·스킬 디렉터리에 연결한다. npm 패키지나 전역 공유 스킬을 추가하지 않는다. 사용법은 [작업 가이드](pi-agent-workflows.md#요청별-지침-snippets)에서 확인한다.

## 새 Mac에서 시작

1. [루트 설치 안내](../../README.md#install)에 따라 Nix, mise, flake를 적용한다. 기존 전역 mise 설정은 `files/workspace/.config/mise/config.toml`을 가리킨다.
2. Pi CLI를 설치한다. Node 24는 기존 mise 설정에서 제공한다.

   ```sh
   mise install npm:@earendil-works/pi-coding-agent@0.87.1
   pi --version
   ```

3. SOPS 렌더 파일이 준비됐는지 값 출력 없이 확인한다.

   ```sh
   for name in OPENROUTER_API_KEY TYPESAFE_API_KEY CONTEXT7_API_KEY; do
     test -s "$HOME/.config/sops-nix/secrets/rendered/env/$name.env" || printf 'missing: %s\n' "$name"
   done
   ```

4. `pi`를 열고 `/login openai-codex`로 OpenAI 구독 로그인을 완료한다. 로그인 전에는 인증 가능한 OpenRouter 모델로 열릴 수 있다. Pi는 토큰을 로컬 `~/.pi/agent/auth.json`에 저장한다. 로그인 뒤 `/model`에서 `openai-codex/gpt-6-astra`를 선택하고 high를 확인한다. 새 세션의 설정상 기본값은 Astra/high다.

   ```sh
   pi
   ```

현재 Mac에서는 게임 저장소에서도 mise shim의 `pi`가 PATH에 있고 `pi --version`이 0.87.1을 반환한다. 일상적으로 `mise exec -- pi`를 붙일 필요는 없다. shell의 mise 활성화나 PATH가 준비되지 않았거나 mise 환경을 명시해 실행할 때만 선택적으로 사용한다.

첫 실행 시 Pi가 `settings.json`의 고정 버전 확장 패키지를 설치한다. `pi list`로 설치 목록을 확인한다. OpenRouter의 Aion 3.5, DeepSeek V4.1 Flash, MiMo V2.6 Pro는 모델 선택기에서 직접 고를 수 있으며, 키는 SOPS에서 mise 환경으로 주입된다. Pi는 `~/.agents/skills`를 기본으로 읽는다. Claude Code나 claude.ai에서만 의미 있는 스킬은 `settings.json`의 `skills` 제외 규칙(`-skills/<이름>`, `~/.agents` 기준)으로 Pi에서만 뺀다. 웹 조사와 로그인된 사이트·화면 조작은 공유 `ego-browser` 스킬과 CLI를 사용한다. 별도 웹 확장과 Chrome MCP는 두지 않는다. Context7과 CodeGraph MCP 서버는 도구 사용 시 연결된다. CodeGraph는 해당 저장소에 `.codegraph/` 인덱스가 있어야 한다. 프로젝트의 공용 `.mcp.json`은 신뢰 확인 후 로드되지만 Codex 프로젝트 전용 설정은 자동으로 가져오지 않는다.

`pi-interactive-shell`은 `settings.json`에 버전을 고정했다. 현재 Mac에서는 `pi install npm:pi-interactive-shell@0.17.0`으로 설치했고, 저장소 원본을 가리키는 `~/.pi/agent/settings.json` 링크가 유지되는 것을 확인했다. 별도 `interactive-shell.json`의 `defer: true`로 큰 `interactive_shell` 도구를 평소에는 숨기고, 필요할 때 Pi가 작은 `enable_interactive_shell` 도구로 활성화한다. 사용자가 활성화 명령을 직접 입력할 필요는 없다. 사용자는 대화에서 대화형 CLI 실행을 요청하거나 `/attach` 같은 명령을 사용한다. 일반 비대화형 명령은 기존 `bash` 도구를 사용한다. 상세 예시는 [작업별 사용법](pi-agent-workflows.md#대화형-cli와-개발-서버)에 있다.

## 작업 방식

기본 대화는 `openai-codex/gpt-6-astra`/high다. `pi-subagents`의 기본 모델과 내장 역할은 `openai-codex/gpt-6-sol`/xhigh로 설정했다. 부모가 범위와 파일 소유권을 명시해 작업을 맡기고 결과를 검토한다. 한 번에 하나의 상위 하위 에이전트 작업 흐름을 실행한다. 확장의 동시 실행 한도 2는 각 흐름 안에 적용된다.

## 확인 기록 (2026-09-29)

현재 Mac에서 Pi 0.87.1과 다섯 확장 패키지의 시작 및 RPC 명령 로드를 확인했다. 현재 도구 목록에서 이전 웹 도구가 빠지고 `enable_interactive_shell`만 먼저 활성화되는 것을 확인했다. ego-browser로 페이지 열기·제목 확인·종료가 통과했다. 최초 구성에서는 OpenRouter Qwen 응답과 Jev 연결도 확인했다. Flake 검사와 Home Manager 평가가 통과했다. 전체 시스템 switch와 Pi의 OpenAI 구독 `/login`은 아직 확인하지 않았다. 작업별 관찰과 실패·재검사는 [검증 기록](pi-agent-validation.md)에 남겼다.

`pi-interactive-shell@0.17.0`은 별도 임시 디렉터리의 Pi SDK 세션에서 `interactive_shell` 도구와 `/spawn`, `/attach`, `/dismiss` 명령 등록을 확인했다. macOS PTY에 `PI_PTY_OK`를 입력하자 `READY`, `ACK:PI_PTY_OK`가 돌아왔다. 이 검사는 모델 호출 없이 수행했다. 패키지의 선택적 Jev 의미 분석은 기본값이 꺼져 있으며, 환경에 `TYPESAFE_API_KEY`가 있다는 이유만으로 켜지지 않는다. Pi TUI 화면에서 사용자가 직접 입력을 인계받는 흐름은 별도로 확인하지 않았다.

현재 `pi-subagents@0.73.1`의 `undici@8.10.0`에 moderate `GHSA-3wwx-pv8p-q78v` npm audit 경고가 있다. 상위 패키지 버전을 갱신할 때 다시 확인해야 한다. `npm audit fix --force`는 하위 버전으로 되돌리는 제안이어서 적용하지 않았다.

설정 원본: [Pi 0.87.1 설정](https://github.com/earendil-works/pi/blob/v0.87.1/packages/coding-agent/docs/settings.md), [pi-subagents 설정](https://github.com/nicobailon/pi-subagents/blob/v0.73.1/docs/configuration.md), [MCP adapter 설정](https://github.com/nicobailon/pi-mcp-adapter/blob/v3.2.0/README.md), [pi-interactive-shell 0.17.0](https://github.com/nicobailon/pi-interactive-shell/tree/v0.17.0).
