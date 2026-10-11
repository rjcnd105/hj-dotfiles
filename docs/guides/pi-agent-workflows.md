# Pi 사용 가이드: Sol로 작업하고 필요할 때 위임하기

[설치, 설정 위치, 현재 검증 결과](pi-agent.md)를 먼저 확인한다. 이 문서는 매일 Pi에서 무엇을 입력하고, 어떤 작업을 하위 에이전트에 맡길지 설명한다. 설정 원본은 `files/workspace/.config/pi/`에 있다.

## 시작과 로그인

작업할 저장소에서 Pi를 연다. 로그인 전에는 인증 가능한 OpenRouter 모델로 시작할 수 있다.

```sh
cd /path/to/project
pi
```

Pi 안에서 `/login`에서 **OpenAI (ChatGPT subscription)**("Sign in with ChatGPT")를 골라 OpenAI 구독 로그인을 완료한다. 이어 `/model`에서 `openai/gpt-6.1-sol`을 선택하고 `/thinking`에서 xhigh를 확인한다. `openai-codex`(Pi 1.1.0의 "OpenAI Codex (legacy)", 로그인 항목 "OpenAI (ChatGPT Plus/Pro)")는 토큰을 따로 저장하므로, 그 공급자의 모델이나 하위 에이전트를 쓸 때만 그 항목으로 따로 로그인한다. `pi auth check`는 로컬 토큰만 보므로 서버가 거부한 토큰도 `ready`로 표시한다. 별도 터미널에서 아래 명령으로 준비 상태를 확인할 수 있다. `--credentials`는 붙이지 않는다.

```sh
pi auth check --provider openai --json
```

로그인 뒤에는 같은 저장소에서 `pi`로 시작한다. 현재 Mac에서는 mise shim이 PATH에 있어 게임 저장소에서도 이 명령이 동작한다. `mise exec -- pi`는 shell의 mise 활성화나 PATH가 준비되지 않았거나 mise 환경을 명시하고 싶을 때 쓰는 선택 사항이다. 기본 대화 모델은 `openai/gpt-6.1-sol`/xhigh다. 로그인 전에는 인증 가능한 다른 제공자로 초기 모델 선택이 달라질 수 있다. Pi 인증 파일은 `~/.pi/agent/auth.json`에 로컬로 남으며 flake에 들어가지 않는다.

## 하루 작업 흐름

1. 메인 세션에 목표, 현재 증거, 범위, 완료 조건을 말한다. 저장소의 `AGENTS.md`와 관련 스킬을 먼저 적용하도록 요청한다.
2. 메인 세션이 계획·구현·검증을 직접 한다. 병렬로 나눌 독립 작업이나 메인 문맥을 채울 긴 기계적 처리가 있을 때만 `worker`에게 **소유 파일, 제외 범위, 검증 명령**을 담아 맡기도록 요청한다. Pi는 허가된 위임 요청에서 `subagents_enable`로 도구를 활성화할 수 있다. 사용자는 보통 자연어로 요청하면 된다.
3. 위임했다면 메인 세션이 결과를 기다려 변경과 검사 결과를 읽고 필요한 재검증을 수행한다. 브라우저 화면이나 실제 게임 조작처럼 작업자의 기본 도구 밖에 있는 증거는 부모가 확인한다.
4. 완료 후 `/session`으로 사용량과 세션 정보를 확인한다. Pi는 세션을 자동 저장한다. 다음에 같은 디렉터리에서 `pi --continue`로 이어간다.

이 설정은 하위 에이전트를 `openai/gpt-6.1-sol`/xhigh와 새 문맥으로 시작한다. 2026-10-07 비교에서 매번 위임하는 방식은 품질 차이 없이 시간과 비용만 늘렸다([검증 기록](pi-agent-validation.md#위임-강제-제거-2026-10-07)). 한 번에 상위 위임 흐름 하나를 실행하고, 그 흐름 안의 동시 작업은 최대 2개, 위임 깊이는 1단계다. 자식은 부모의 MCP 확장을 자동 상속하지 않아 지정한 Sol 모델을 유지한다. `worker`, `researcher`, `evidence-auditor`는 발견된 스킬 목록을 받는다. 조사 역할은 `~/.agents/skills/ego-browser/SKILL.md`를 읽고 bash로 브라우저를 사용한다. 작업 브리프에도 관련 스킬 경로를 명시한다.

부모의 기본 내장 도구는 `read`, `bash`, `edit`, `write`다. Pi 내장 MCP는 CodeGraph와 godot-ai를 `codemode` 노출로 두어, 모델이 `codemode` 스크립트에서 필요한 도구만 호출한다. 웹 조사와 화면 조작은 `ego-browser` 스킬을 읽고 CLI로 실행한다. 이 구성은 평소 문맥의 도구 수를 줄이지만, Codex보다 품질·속도·비용이 낫다는 보장은 없다.

## Pi 세션 분석

`analyze-sessions`는 저장된 Pi JSONL을 읽어 비용 집계, 사용자 요청 추출, 대화 검색과 세션 열람을 수행한다. 자연어로 요청하거나 스킬을 명시해서 사용한다.

```text
/skill:analyze-sessions 최근 7일 Pi 세션에서 반복해서 수정 지시한 내용을 찾아줘. 세션과 시각을 근거로 개선안을 제안하고 설정은 바꾸지 마.
```

```text
/skill:analyze-sessions 최근 7일 Pi의 모델별 기록 비용과 서브에이전트 비용을 집계해줘.
```

분석은 기록을 읽는 작업이며 지침·메모리를 자동 갱신하지 않는다. 반복 요청이 발견되면 공통 규칙의 문제인지, 상황에 따라 선택할 지침인지 구분해 제안한다. 비용은 세션의 `usage.cost` 집계이며 실제 청구액이나 구독 사용 한도 차감량이 아니다. 현재 세션의 원문 회수는 기존 `vcc_recall`을 사용하고, 여러 과거 세션을 비교할 때 이 스킬을 사용한다.

## 모델 선택과 세션 관리

| 목적 | Pi에서 하는 일 |
|---|---|
| 설계·원인 분석·구현·검증 | 메인 세션(`openai/gpt-6.1-sol`)이 직접 한다. 현재 기본값은 xhigh다. |
| 병렬 독립 작업·긴 기계적 처리 | 메인 세션에 Sol 6.1/xhigh `worker` 위임을 요청한다. |
| 부모 모델을 직접 Sol로 전환 | `/model`에서 `openai-codex/gpt-6-sol` 선택 후 `/thinking`에서 max를 확인한다. 한 번의 실행은 `pi --model openai-codex/gpt-6-sol --thinking max`로 시작할 수 있다. |
| OpenRouter 모델 직접 사용 | `/model`에서 `openrouter/aion-labs/aion-3.5`, `openrouter/deepseek/deepseek-v4.1-flash`, `openrouter/xiaomi/mimo-v2.6-pro` 중 하나를 선택하거나 `pi --model <모델>`로 시작한다. DeepSeek V4.1 Flash의 기본 thinking은 off이고 나머지는 전역 기본 high를 따른다. |

`Ctrl+P`는 현재 설정된 `openai/gpt-6.1-sol`, Codex 공급자의 Astra·Sol 6·Sol 6.1, Aion 3.5, DeepSeek V4.1 Flash, MiMo V2.6 Pro 일곱 모델 사이를 순환한다. `/model`은 인증 가능한 더 넓은 모델 목록을 검색한다. 모델과 thinking 변경은 현재 세션에 기록되며, 재개하면 복원된다. `/model` 선택 화면에서 `Ctrl+S`는 새 세션의 기본 모델도 저장한다. 이 동작은 링크된 저장소 설정 원본을 수정하므로 전역 기본값을 바꾸려는 경우에만 쓰고 diff를 확인한다.

`/name`으로 작업 이름을 붙이고, `/resume` 또는 `pi --resume`으로 다른 세션을 고른다. `/tree`는 현재 세션의 이전 지점에서 다른 대화 분기를 만든다. 별도 세션으로 분리하려면 `/fork`, 현재 분기의 복사본이 필요하면 `/clone`을 쓴다.

### 긴 대화 압축과 이전 내용 찾기

`pi-vcc`는 부모 세션의 자동 임계값 압축과 `/compact`를 맡는다. 현재 Pi의 압축 임계값은 그대로 두고, 압축 시 LLM 호출 대신 대화에서 목표·변경 파일·남은 문제와 짧은 흐름을 추출한다. 필요한 때 `/pi-vcc`로 수동 압축하고, 최근 사용자 턴 3개를 그대로 남기려면 `/pi-vcc keep:3`을 쓴다. 기본 설정의 `smartKeepTail`은 최근 꼬리가 작을 때 보존할 턴 수를 늘린다.

압축된 요약에 모든 세부 내용이 들어가지는 않는다. 원래 대화는 **현재 세션의 JSONL 기록**에 남으므로 `/pi-vcc-recall 검색어`로 이전 부분을 찾거나 Pi에게 그 내용을 찾아 달라고 요청한다. 이때 에이전트는 `vcc_recall` 도구를 사용할 수 있다. 기본 검색 범위는 현재 대화 분기이고 `scope:all`은 같은 세션의 다른 분기까지 넓힌다. 이전에 종료한 별도 세션을 가로지르는 기억 기능은 아니다. 하위 에이전트는 확장 로딩을 제한했으므로 Pi 기본 압축을 사용한다.

## 실제 요청 예시

아래 문장은 Pi 입력창에 그대로 붙여 넣고 파일명·티켓 번호만 바꿔 쓸 수 있다. 위임은 요청에 명시했거나 병렬·긴 처리가 필요할 때만 일어난다.

### React 관리자 화면과 서버 계약

> 티켓 상세의 문제 부품 표시가 API 응답과 어긋나는 원인을 먼저 확인해 줘. 생성된 스키마, 실제 응답, 화면 매핑의 소유자를 구분하고 기존 수정 범위를 제안해. 범위가 정해지면 해당 컴포넌트와 매핑 파일만 고쳐. 관련 타입 검사와 집중 테스트를 실행하고, diff와 실제 화면·네트워크 증거를 확인한 뒤 결과를 알려 줘.

서버가 소유한 쓰기 정책을 UI에서 추측하지 않도록 API 계약을 먼저 확인한다. 화면 조작과 응답 검증이 필요하면 부모가 ego-browser 스킬의 현재 API를 읽고 로그인된 브라우저에서 확인한다.

### Nix 설정과 SOPS

> `files/workspace/.config/mise/config.toml`의 도구 버전만 바꿔 줘. 이 저장소의 AGENTS와 Nix 규칙을 읽고 해당 파일만 고쳐. 비밀 값은 출력하지 말고 렌더 파일 존재 여부만 확인해. diff, 포맷 검사, 해당 Home Manager 평가를 확인해. 다른 생성 파일이나 flake.lock은 건드리지 마.

이 저장소는 `files/workspace` 원본과 Home Manager 투영을 분리한다. SOPS 키는 설정의 경로·환경 변수 이름으로만 다루고, 검증 출력에 값을 넣지 않는다.

### Godot 게임 코드와 아트 경계

> Little Bird Village의 저장 후 농장 상태가 달라지는 문제를 확인해 줘. 프로젝트 `AGENTS.md`, `.agents/skills/task-start.md`, 관련 소유 코드와 검증 문서를 먼저 읽어. 범위가 정해지면 지정된 저장·로드 코드만 고쳐. 원래 주민·시설·작물 데이터를 보존하는 저장 왕복과 실제 입력 플레이를 확인하고, 결과를 검토한 뒤 프로젝트 task 종료 절차를 실행해.

픽셀 아트 요청은 별도 승인 단계가 있다. 부모는 프로젝트의 디자인·픽셀 품질 문서를 읽고 소스 선택과 원본 크기 시안을 검토한 뒤 승인된 콘셉트만 제작 단계로 넘긴다. 코드 수정 요청에 아트 승인을 섞지 않는다.

현재 전역 Pi MCP에는 CodeGraph와 Godot의 `godot-ai`(4.3.0)를 연결했다. 관리자 화면의 `mui-mcp`·`next-devtools-index`는 프로젝트의 Codex 전용 설정에 있으며 Pi로 자동 이전되지 않았다. Pi 내장 MCP는 신뢰한 프로젝트의 `.pi/mcp.json`만 읽고, 프로젝트 루트의 `.mcp.json`이나 Codex 프로젝트 설정은 읽지 않는다. Pi에서 같은 도구가 필요하면 그 저장소에 `.pi/mcp.json`을 추가해야 하며, 현재 구성은 그 연결을 포함하지 않는다. 코드 수정·CLI 검사는 바로 사용할 수 있지만 이번 설치 검증이 실제 Godot 조작이나 프로젝트별 MCP 검증을 대신하지 않는다.

### 출처가 필요한 기술 조사

> Pi의 현재 세션 분기 기능이 우리 작업 흐름에 맞는지 공식 문서로 확인해 줘. researcher에게 검색과 원문 확인을 맡기고, 인용할 각 주장이 해당 원문의 위치와 내용에 맞는지 확인해. 확인된 사실과 추론을 구분해서 권고안을 제시해. 코드나 설정은 변경하지 마.

`researcher`는 `read`, `bash`, `write`를 사용한다. ego-browser로 검색 결과와 원문을 확인하고 지정된 경로에 조사 결과를 작성한다. `evidence-auditor`는 `read`, `bash`로 핵심 주장과 출처를 독립적으로 대조한다. 두 역할의 기존 웹 확장 전용 지침은 교체했다. 저장소 코드 탐색은 `.codegraph/`가 있으면 CodeGraph부터 사용하고, 최신 라이브러리 문서 조회는 부모가 담당한다. 부모에게 익숙하지 않은 MCP 도구는 먼저 검색하고 인자 설명을 확인한 뒤 호출하라고 요청한다. 프로젝트 `.pi/mcp.json` 서버는 신뢰 확인 뒤 로드된다.

참고: [Pi 모델 선택](https://github.com/earendil-works/pi/blob/v1.0.4/packages/coding-agent/docs/models.md), [세션](https://github.com/earendil-works/pi/blob/v1.0.4/packages/coding-agent/docs/sessions.md), [pi-subagents 에이전트](https://github.com/nicobailon/pi-subagents/blob/v0.73.1/docs/agents.md), [pi-vcc 0.8.0](https://github.com/sting8k/pi-vcc/tree/v0.8.0).
