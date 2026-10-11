# Pi 개인 에이전트 설정

이 flake는 Pi 설정을 `files/workspace/.config/pi/`에 보관하고 Home Manager가 각 파일을 `~/.pi/agent/`에 쓰기 가능한 out-of-store 심볼릭 링크로 연결한다. `auth.json`, 세션, 패키지 캐시는 Pi가 로컬에서 관리한다. OMP는 사용하지 않는다.

Pi는 agent 디렉터리에서 컨텍스트 파일을 하나 읽고, 작업 디렉터리와 모든 상위 디렉터리의 `AGENTS.md`·`CLAUDE.md`도 읽는다. 그래서 `~/.pi/agent/AGENTS.md`는 APM이 생성한 공용 지침 `files/workspace/.codex/AGENTS.md`에 연결하고, Pi 전용 지침은 `files/workspace/.config/pi/APPEND_SYSTEM.md`에 둔다. 일반 `apm compile`이 만드는 `files/workspace/AGENTS.md`는 `.gitignore`로 제외한다. 이 파일을 추적하면 Home Manager가 `~/AGENTS.md`로 연결해 홈 아래 저장소에서 같은 지침을 두 번 읽는다. 공용 지침은 `.apm/instructions/`에서 수정하고 [APM 절차](../solutions/tooling-decisions/apm-codex-first-agent-settings-2026-07-30.md#workflow)로 다시 생성한다. 단, 신뢰한 프로젝트에 `.pi/APPEND_SYSTEM.md`가 있으면 그 파일이 전역 `APPEND_SYSTEM.md`를 대체한다.

[작업별 사용법과 복사 가능한 요청 예시](pi-agent-workflows.md), [커뮤니티 벤치마크 해석과 직접 테스트 결과](pi-agent-validation.md)를 함께 참고한다.

## 고정한 구성

| 구성 | 버전 | 용도 |
|---|---|---|
| Pi CLI | mise `latest` (2026-10-07 기준 1.0.4) | OpenAI 구독과 OpenRouter 모델 실행, 내장 MCP로 CodeGraph·godot-ai 연결 |
| [pi-subagents](https://github.com/nicobailon/pi-subagents) | git main (2026-10-02, Pi 1.0 수정 #2634 포함, npm 릴리스 전) | Sol 6.1/high의 독립된 작업 문맥과 결과 회수 |
| [pi-vcc](https://github.com/sting8k/pi-vcc) | 0.8.0 | 모델 호출 없는 세션 압축과 현재 세션 원문 재검색 |
| [pi-ask-user](https://github.com/edlsh/pi-ask-user) | 0.15.1 | 결정이 필요할 때 선택지·다중 선택·자유 입력으로 사용자에게 묻는 `ask_user` 도구 |
| pi-intercom | 고정하지 않음 (2026-10-07 기준 0.16.1) | Pi 세션 간 1:1 메시지, pi-subagents 하위 에이전트의 `contact_supervisor` |
| [pi-goal](https://github.com/narumiruna/pi-extensions/tree/main/packages/pi-goal) | 고정하지 않음 (2026-10-29 기준 0.54.13) | `/goal <목표>`로 완료·차단·대기 판정까지 자동으로 이어 가는 목표 모드 |
| 로컬 `analyze-sessions` 스킬 | 저장소 관리 | Pi 세션의 비용·반복 요청·과거 대화를 읽기 전용 분석 |
| 로컬 `chatgpt-credit-fallback` 확장 | 저장소 관리 | ChatGPT 플랜 한도에 걸린 `openai/*` 실행을 같은 모델의 `openai-codex`로 옮겨 ChatGPT 크레딧으로 이어감 |

`chatgpt-credit-fallback`은 Home Manager 링크 없이 `settings.json`의 `extensions`(메인 세션)와 `subagents.defaultSubagentOnlyExtensions`(하위 에이전트)가 원본 경로를 직접 가리킨다. `openai-codex`에 로그인돼 있어야 동작한다.

`analyze-sessions`는 [amosblomqvist/pi-config의 `f82da56`](https://github.com/amosblomqvist/pi-config/tree/f82da563ab05d66729492d64c7ed4e96db3663f3)를 바탕으로 이 설정에 맞췄다. 원본은 `files/workspace/.config/pi/skills/analyze-sessions/`이며 Home Manager가 Pi의 스킬 디렉터리에 연결한다. npm 패키지나 전역 공유 스킬을 추가하지 않는다. 사용법은 [작업 가이드](pi-agent-workflows.md#pi-세션-분석)에서 확인한다.

## 새 Mac에서 시작

1. [루트 설치 안내](../../README.md#install)에 따라 Nix, mise, flake를 적용한다. 기존 전역 mise 설정은 `files/workspace/.config/mise/config.toml`을 가리킨다.
2. Pi CLI를 설치한다. 전역 mise 설정이 `latest`를 설치하고, Pi가 요구하는 Node 22.19 이상은 전역 Node 26이 제공한다.

   ```sh
   mise install npm:@earendil-works/pi-coding-agent
   pi --version
   ```

3. SOPS 렌더 파일이 준비됐는지 값 출력 없이 확인한다.

   ```sh
   for name in OPENROUTER_API_KEY TYPESAFE_API_KEY; do
     test -s "$HOME/.config/sops-nix/secrets/rendered/env/$name.env" || printf 'missing: %s\n' "$name"
   done
   ```

4. `pi`를 열고 `/login`에서 **OpenAI (ChatGPT subscription)**("Sign in with ChatGPT")를 골라 OpenAI 구독 로그인을 완료한다. 로그인 전에는 인증 가능한 OpenRouter 모델로 열릴 수 있다. Pi는 토큰을 로컬 `~/.pi/agent/auth.json`에 저장한다. 로그인 뒤 `/model`에서 `openai/gpt-6.1-sol`을 선택하고 xhigh를 확인한다. 새 세션의 설정상 기본값은 `openai/gpt-6.1-sol`/xhigh다. `openai-codex`(Pi 1.1.0의 "OpenAI Codex (legacy)", 로그인 항목 "OpenAI (ChatGPT Plus/Pro)")는 토큰을 따로 저장하므로, 그 공급자의 모델이나 하위 에이전트를 쓸 때만 그 항목으로 따로 로그인한다. `pi auth check`는 로컬 토큰만 보므로 서버가 거부한 토큰도 `ready`로 표시한다.

   ```sh
   pi
   ```

현재 Mac에서는 게임 저장소에서도 mise shim의 `pi`가 PATH에 있고 `pi --version`이 1.0.4를 반환한다. 일상적으로 `mise exec -- pi`를 붙일 필요는 없다. shell의 mise 활성화나 PATH가 준비되지 않았거나 mise 환경을 명시해 실행할 때만 선택적으로 사용한다.

ps-frontend-admin처럼 Node 22.14를 고정한 저장소에서는 PATH의 `node`가 22.14가 된다. Pi 1.0.4는 zstd 응답을 풀 때 Node 22.19 이상의 `zlib.createZstdDecompress`가 필요해 이 상태로는 첫 응답에서 멈춘다. Pi의 bin shim은 옆에 있는 `node`를 PATH보다 먼저 쓰므로, 전역 mise 설정의 `postinstall`이 `mise install` 때마다 그 자리에 전역 Node 26 링크를 만든다. 저장소의 `node`는 그대로 22.14로 남는다.

첫 실행 시 Pi가 `settings.json`의 고정 버전 확장 패키지를 설치한다. `pi list`로 설치 목록을 확인한다. OpenRouter의 Aion 3.5, DeepSeek V4.1 Flash, MiMo V2.6 Pro는 모델 선택기에서 직접 고를 수 있으며, 키는 SOPS에서 mise 환경으로 주입된다. Pi는 `~/.agents/skills`를 기본으로 읽는다. Claude Code나 claude.ai에서만 의미 있는 스킬과 코딩 작업에서 쓰지 않는 스킬(Obsidian, kb, gitbutler, hindsight 등)은 `settings.json`의 `skills` 제외 규칙(`-skills/<이름>`, `~/.agents` 기준)으로 Pi에서만 뺀다. 제외한 스킬은 Claude Code와 Codex에서 계속 쓸 수 있다. 웹 조사와 로그인된 사이트·화면 조작은 공유 `ego-browser` 스킬과 CLI를 사용한다. 별도 웹 확장과 Chrome MCP는 두지 않는다. MCP는 Pi 내장 기능을 쓴다. `~/.pi/agent/mcp.json`(원본 `files/workspace/.config/pi/mcp.json`)은 CodeGraph와 godot-ai를 `codemode` 노출로 선언한다. 두 서버의 도구는 모델에 직접 선언되지 않고 `codemode` 스크립트에서 호출한다. `pi mcp list`로 연결 상태를 확인한다. CodeGraph는 해당 저장소에 `.codegraph/` 인덱스가 있어야 한다. 내장 MCP는 프로젝트 설정으로 신뢰한 저장소의 `.pi/mcp.json`만 읽고, 프로젝트 루트의 `.mcp.json`이나 Codex 프로젝트 전용 설정은 읽지 않는다. gentle-renewal과 my-backend의 `.mcp.json` Figma 서버를 Pi에서 쓰려면 그 저장소에 `.pi/mcp.json`을 따로 둔다.

## 작업 방식

기본 대화는 `openai/gpt-6.1-sol`/xhigh이고, 기본 대화가 계획·구현·검증을 직접 맡는다. 병렬로 나눌 수 있는 독립 작업, 메인 문맥을 채울 긴 기계적 처리, 사용자·프로젝트·스킬의 명시 요청이 있을 때만 하위 에이전트에 맡긴다. `pi-subagents`의 기본 모델과 내장 역할은 `openai/gpt-6.1-sol`/xhigh다. 부모가 범위와 파일 소유권을 명시해 작업을 맡기고, 결과를 기다려 검토한 뒤 보고한다. 한 번에 하나의 상위 하위 에이전트 작업 흐름을 실행한다. 확장의 동시 실행 한도 2는 각 흐름 안에 적용된다. 위임을 강제하지 않는 근거는 [2026-10-07 하네스 비교](pi-agent-validation.md#위임-강제-제거-2026-10-07)에 있다.

## 확인 기록 (2026-10-29)

`@narumitw/pi-goal`을 추가했다. Pi 1.4.0에는 `/goal`이 없는데 실제 세션에서 `/goal` 입력이 세 번 있었다. 설정은 기본값을 쓰며, 바꿀 때는 `/goal` → Settings가 `~/.pi/agent/pi-goal.json`을 만든다.

## 확인 기록 (2026-10-27)

`pi-interactive-shell`과 로컬 `prompt-snippets` 확장을 뺐다. 최근 한 달의 실제 작업 세션 96개에서 `interactive_shell`·`enable_interactive_shell` 호출과 `/spawn`·`/attach` 입력은 0회였고, 명령 실행은 모두 `bash`가 맡았다. snippets는 네 항목 중 `구현 완료`만 두 세션에서 쓰였다. 대화형 CLI가 다시 필요하면 `pi install npm:pi-interactive-shell`로 설치한다.

## 확인 기록 (2026-10-07)

pi-mcp-adapter를 빼고 Pi 1.0.4 내장 MCP로 옮겼다. `pi list`에는 pi-subagents, pi-vcc, pi-interactive-shell, pi-ask-user, pi-intercom 다섯 패키지만 남았고, `pi mcp list`에서 context7과 codegraph가 `deferred`로 연결됐다. 홈 아래 저장소에서 Pi가 실제로 받는 시스템 프롬프트는 51.6K자에서 33.6K자로 줄었다. 중복 지침 10.1K자, 스킬 목록 5.6K자, Pi 전용 지침 1.4K자가 빠졌다.

ps-frontend-admin에서 `mise exec -- node --version`은 v22.14.0을 유지하고, Pi shim은 옆의 `node`(v26.10.0)를 실행하는 것을 `sh -x`로 확인했다. 링크를 지운 뒤 `mise install`을 다시 실행하면 `postinstall`이 링크를 되살린다.

설정 원본: [Pi 1.0.4 MCP](https://github.com/earendil-works/pi/blob/v1.0.4/packages/coding-agent/docs/mcp.md), [Pi 1.0.4 설정](https://github.com/earendil-works/pi/blob/v1.0.4/packages/coding-agent/docs/settings.md), [mise tool postinstall](https://mise.jdx.dev/dev-tools/#tool-options).

## 확인 기록 (2026-09-29)

현재 Mac에서 Pi 0.87.1과 다섯 확장 패키지의 시작 및 RPC 명령 로드를 확인했다. 현재 도구 목록에서 이전 웹 도구가 빠지고 `enable_interactive_shell`만 먼저 활성화되는 것을 확인했다. ego-browser로 페이지 열기·제목 확인·종료가 통과했다. 최초 구성에서는 OpenRouter Qwen 응답과 Jev 연결도 확인했다. Flake 검사와 Home Manager 평가가 통과했다. 전체 시스템 switch와 Pi의 OpenAI 구독 `/login`은 아직 확인하지 않았다. 작업별 관찰과 실패·재검사는 [검증 기록](pi-agent-validation.md)에 남겼다.

`pi-interactive-shell@0.17.0`은 별도 임시 디렉터리의 Pi SDK 세션에서 `interactive_shell` 도구와 `/spawn`, `/attach`, `/dismiss` 명령 등록을 확인했다. macOS PTY에 `PI_PTY_OK`를 입력하자 `READY`, `ACK:PI_PTY_OK`가 돌아왔다. 이 검사는 모델 호출 없이 수행했다. 패키지의 선택적 Jev 의미 분석은 기본값이 꺼져 있으며, 환경에 `TYPESAFE_API_KEY`가 있다는 이유만으로 켜지지 않는다. Pi TUI 화면에서 사용자가 직접 입력을 인계받는 흐름은 별도로 확인하지 않았다.

현재 `pi-subagents@0.73.1`의 `undici@8.10.0`에 moderate `GHSA-3wwx-pv8p-q78v` npm audit 경고가 있다. 상위 패키지 버전을 갱신할 때 다시 확인해야 한다. `npm audit fix --force`는 하위 버전으로 되돌리는 제안이어서 적용하지 않았다.

설정 원본: [Pi 0.87.1 설정](https://github.com/earendil-works/pi/blob/v0.87.1/packages/coding-agent/docs/settings.md), [pi-subagents 설정](https://github.com/nicobailon/pi-subagents/blob/v0.73.1/docs/configuration.md), [MCP adapter 설정](https://github.com/nicobailon/pi-mcp-adapter/blob/v3.2.0/README.md), [pi-interactive-shell 0.17.0](https://github.com/nicobailon/pi-interactive-shell/tree/v0.17.0).
