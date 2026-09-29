# Pi 설정의 근거와 직접 검증

확인일: 2026-09-29. 설치 절차는 [Pi 설정](pi-agent.md), 실제 요청 예시는 [작업 가이드](pi-agent-workflows.md)에 있다.

## 로컬 snippets와 세션 분석 추가

`prompt-snippets`와 `analyze-sessions`의 원본을 `files/workspace/.config/pi/`에 두고 Home Manager의 개별 디렉터리 링크를 선언했다. 현재 Mac에도 동일 원본을 가리키는 링크를 연결했다. 전체 시스템 switch는 실행하지 않았다.

- `nix fmt -- homes/workspace/pi.nix`, 두 `home.file` 항목의 `nix eval`, `nix flake check --all-systems --no-build --show-trace`가 통과했다.
- Pi 0.87.1의 실제 resource loader에서 기존 패키지와 함께 로컬 확장·스킬을 자동 발견했다. 확장 로드 오류와 스킬 진단은 0개였으며 `/snippets`와 `Alt+S` 등록을 확인했다. 직접 SDK로 시작한 검사에서는 기존 `pi-subagents`의 실행 위치 감지 경고가 있었으므로 이 검사로 서브에이전트 지연 로드까지 판정하지 않았다.
- 별도 인증·세션 디렉터리의 실제 Pi CLI PTY(100×30)에서 `/snippets`, `Alt+S`, 한글 본문 미리보기, 선택 표시와 작업 방식 상호 배제를 확인했다. 모델에 프롬프트를 보내지 않았다.
- 실제 SDK loader/runner를 쓴 입력 검사에서 앞뒤 지침 순서, 이미지 유지, 전송 후 초기화, extension/RPC 입력의 선택 미소비, 메뉴 취소, tree/shutdown 초기화, 자동 압축 시 선택 유지가 통과했다. 40·60열 메뉴·미리보기의 렌더 폭과 스크롤도 검사했다. 이는 모델의 지침 준수율을 측정한 검사가 아니다.
- 세션 분석의 임시 JSONL fixture에서 오래된 세션의 최근 메시지 포함, UTC 날짜·모델별 비용, 비용 정보 누락 구분, `openai-codex` 필터, 중첩 서브에이전트 포함/제외와 artifact 복사본 제외를 확인했다. 한국어 요청 추출·검색·세션 열람의 기간 필터도 통과했다. 여기서 복사본 제외는 `subagent-artifacts` 경로에 한정하며 일반 fork/clone 중복 제거를 뜻하지 않는다.

로컬 재현 검사는 `/tmp/pi-prompt-snippets-probe.mjs`, `/tmp/pi-session-analysis-check.py`, `/tmp/pi-config-additions-smoke.mjs`와 `/tmp/pi-config-additions-smoke-report.json`에 있다. 임시 파일은 정리 후 사라질 수 있다.

## 커뮤니티 벤치마크에서 가져온 판단

사용자가 제공한 [6 harnesses × 11 models × 226 tasks 글](https://www.reddit.com/r/PiCodingAgent/comments/1wki8wq/i_benched_6_harnesses_x_11_models_x_226_tasks/)에서 연결된 원자료와 실행 어댑터를 확인했다. 이 벤치마크는 작은 파일 편집의 바이트 단위 정확도를 측정한다. 설계, 브라우저 검증, 게임 플레이, 긴 협업 작업 전체의 성능 순위는 아니다.

[고정된 데이터셋 스냅샷](https://huggingface.co/datasets/alexshpunt/explicit-edit-benchmark/blob/7e1c96ca42a6ccd4a46c66955e1a51f7dc7ff140/leaderboard.json)에는 GPT-6 Astra 결과가 없다. GPT-6 Sol은 Pi 0.87.1의 `baseline-agent`, `low` 한 구성만 있다. 이 구성은 bash만 허용하고 시스템 프롬프트를 비우므로 현재 설정이나 Pi 기본 하네스와 다르다. 따라서 이 자료로 GPT-6의 Pi 대 Codex 우열을 확정할 수 없다.

같은 실행 묶음의 `gpt-5.6-luna` / `openai-codex` / `low`, 각 226개 과제 결과는 다음과 같다.

| 하네스 | 점수 | 첫 시도 정확도 | 복구 후 정확도 | 평균 초/과제 |
|---|---:|---:|---:|---:|
| OMP 18.1.14 | 98.01% | 97.35% | 100.00% | 20.40 |
| Pi 기본 0.85.1 | 96.13% | 95.13% | 99.12% | 18.37 |
| Codex CLI 0.153.4 | 77.43% | 76.11% | 81.42% | 53.10 |

점수는 `0.75 × 첫 시도 정확도 + 0.25 × 복구 후 정확도`다. 복구 최대 5회, 라운드당 제한 120초이며 사용자 확장과 규칙은 꺼져 있다. 시간은 복구를 포함한 과제별 평균이다. [구성 원자료](https://huggingface.co/datasets/alexshpunt/explicit-edit-benchmark/resolve/7e1c96ca42a6ccd4a46c66955e1a51f7dc7ff140/data/configurations/explicit-edit-v1-five-model-eight-harness-baseline.jsonl.gz), [실행 인자](https://github.com/alexshpunt/explicit-edit-benchmark/blob/eb3e18378fa8b30965f498901a4e2e3049c05ff6/scripts/prepare-benchmark.mjs#L306-L475), [방법론](https://github.com/alexshpunt/explicit-edit-benchmark/blob/eb3e18378fa8b30965f498901a4e2e3049c05ff6/docs/methodology.md).

추가로 확인한 자료도 모델과 조건을 함께 읽어야 한다.

- [Composio Pi–OMP 비교](https://composio.dev/content/pi-vs-omp)는 DeepSeek V4 Flash의 외부 도구 작업 30개에서 Pi 20개, OMP 17개 성공을 보고한다. 본문에는 Pi의 추론 수준이 high였고 24개 실행의 API 경로가 달랐다는 단서가 있다. 비용 차이를 하네스 하나의 효과로 분리할 수 없다.
- [FrontierHarness](https://runta.com/blog/introducing-frontierharness-eval/)는 Kimi K3의 30개 과제에서 Codex 66.7%, Pi 60.0%를 보고한다. Pi의 성공당 중앙 비용은 더 낮았다. 성공률과 비용을 따로 봐야 한다.
- [Databricks의 실제 코드베이스 평가](https://www.databricks.com/blog/benchmarking-coding-agents-databricks-multi-million-line-codebase)는 같은 모델·추론 수준에서도 하네스가 매 턴 넣는 문맥이 비용에 영향을 준다고 보고한다. 모든 코드베이스에서 Pi가 우세하다는 증거는 아니다.

이 설정에서는 Pi 기본 편집 도구를 유지하고, MCP와 서브에이전트 도구는 필요한 시점에 활성화한다. Astra/high 기본값과 Sol/max 위임은 사용자의 작업 방식과 명시한 선호를 반영한다. 위 벤치마크가 그 조합의 최적성을 입증한 것은 아니다.

## 최초 구성에서 직접 실행한 작업

Pi 0.87.1과 당시 설치된 확장을 실제로 실행했다. 아래 Brave·Exa 검사는 웹 구성을 ego-browser로 정리하기 전의 기록이다. 현재 설정에는 pi-web-access와 Chrome DevTools MCP가 없다. 기존 프로젝트 파일을 바꾸지 않도록 `/tmp`의 독립된 작업 디렉터리를 사용했다. 아래 모델 테스트는 OpenRouter Qwen 경로다. OpenAI 구독은 Pi에 아직 로그인하지 않아 Astra/Sol의 실제 응답은 검증하지 않았다.

| 검사 | 관찰 결과 | 경과 시간 | Pi 보고 모델 비용 |
|---|---|---:|---:|
| 티켓 상태 코드 수정 | `read → edit → bash`; 테스트 1/2에서 2/2 통과 | 6.95초 | $0.002825 |
| 공식 문서 웹 조사 | Brave 검색·공식 문서 조회 성공, 최종 답변의 출처 귀속 오류 발견 | 12.91초 | $0.001553 |
| 출처 대조를 명시한 재검사 | 뒷받침되지 않은 주장을 보류했으나 도구 호출 10회로 증가 | 28.59초 | $0.008689 |
| Context7 MCP | 실제 React 문서 조회와 공식 링크 반환; 잘못된 인자를 한 번 수정 | 12.02초 | $0.000857 |
| 백그라운드 worker | 두 파일을 읽어 17+25=42; `bg_wait`로 완료 회수 | 11.95초 | 부모·자식 합계 $0.002238 |
| Jev 자동 라우팅 재검사 | GLM으로 시작해 Jev가 quick 선택, Qwen/off로 전환 후 정확한 JSON 반환 | 1.66초 | $0.000039 |
| pi-vcc 압축·검색 | 두 번 압축하고 세션을 다시 열어도 한국어 표식, 원본 메시지, 후속 작업 유지 | 결정적 SDK 검사 | 모델 호출 0회 |

비용은 Pi 응답의 usage 필드를 합산한 모델 비용이다. 실제 청구서, Jev·검색 API 비용, OpenAI 구독 한도 차감량을 측정한 수치는 아니다. 작은 사례 각 1회와 필요한 재검사이므로 성능 벤치마크로 일반화하지 않는다.

### 검사에서 고친 점

- 라우팅 후 Qwen이 전역 high 추론 설정을 상속했다. Qwen별 thinking을 off로 고정했고 재검사에서 확인했다.
- Bifrost의 quick 기본 선택 전략이 random이었다. 해당 범주를 first로 명시했다.
- 첫 MCP 연결에서 모델이 인자 이름을 추측했다. 익숙하지 않은 도구는 schema 설명을 먼저 조회하도록 Pi 지침을 보강했다.
- 문서 조사에서 검색 요약의 문구를 다른 원문에 귀속한 사례를 확인했다. quick 경로를 입력이 주어진 기계적 작업과 실행 검사 가능한 수정으로 좁혔다. 출처/API 조사는 Sol/Astra 경로와 원문 대조를 사용한다.
- 자식이 부모의 라우터를 상속하면 지정한 모델을 바꿀 수 있어 확장 상속을 제한했다. 실제 자식 기록에서 Qwen/off와 격리된 확장 구성을 확인했다. 운영 설정의 자식 모델은 Sol/max다.

백그라운드 worker의 실행 상태는 complete/success였지만 acceptance는 `review-required`였다. 내장 worker가 작성자 역할로 분류된 결과이며, 부모가 출력과 완료 조건을 검토해야 한다. 이 검사에서는 두 파일을 독립적으로 읽어 합계를 확인했다. 작업자의 종료 상태만으로 최종 검증이 끝났다고 판단하지 않는다.

### pi-vcc 압축·검색 검사

실제 Pi 0.87.1 SDK에 설치된 `@sting8k/pi-vcc@0.8.0`을 로드하고 임시 세션의 압축 훅과 `vcc_recall`을 실행했다. 인증 조회는 빈 결과로 대체하고 모델 호출 수를 기록했다. 첫 압축의 `fromHook: true`, `details.compactor: pi-vcc`를 확인했다. 원본 메시지 8개는 모두 JSONL에 남았고, `제비꽃-640x360`과 ASCII 표식이 요약·검색 결과에 있었다. 최신 작업도 모델에 제공하는 문맥에 남았다.

후속 메시지를 추가한 두 번째 압축은 이전 요약을 재사용했다. 세션 파일을 다시 열어도 원래 메시지 ID, 한국어 표식, 후속 작업을 확인했다. 인증 조회는 2회, 모델 호출은 0회였다. 이는 압축 연결과 원문 검색의 동작 검사이며 임의의 긴 실제 대화에서 모든 의미를 보존한다는 검증은 아니다. 재현 스크립트와 결과는 임시 증거 디렉터리의 `vcc/run-vcc.mjs`, `vcc/report.json`에 있다.

## 최초 구성의 설치와 설정 검사

- Pi 버전과 고정된 패키지의 로드, 실제 프로젝트 지침·스킬을 포함한 RPC 시작을 확인했다.
- 기존 환경 변수를 제거한 외부 임시 디렉터리에서도 mise가 SOPS의 OpenRouter, TypeSafe, Brave, Exa, Context7 키를 공급했다. 키 값은 출력하지 않았다.
- OpenRouter 인증 인식, TypeSafe HTTP 200, Brave HTTP 200을 확인했다.
- JSON/TOML 구문, Nix 포맷, Home Manager의 Pi 파일 연결 평가, `nix flake check --all-systems --no-build --show-trace`가 통과했다.
- 전체 시스템 switch는 수행하지 않았다. 현재 Mac의 Pi 파일은 원본에 개별 연결했고 CLI와 확장을 설치했다.

로컬 임시 실행 증거는 `/tmp/pi-workflow-tests-OLMtGe/`와 `/tmp/pi-workflow-root/`에 있다. 임시 파일은 재부팅·정리 후 사라질 수 있으며 저장소에는 이 검증 요약을 남긴다.


## ego-browser 중심 구성으로 정리

사용자 선택에 따라 `pi-web-access` 패키지, `web-search.json`, Pi의 전역 Chrome DevTools MCP를 제거했다. 이 설치에서 추가했던 Brave·Exa의 전역 mise 환경 파일 참조도 제거했으며 SOPS의 원래 키는 유지했다. 전역 MCP는 Context7과 CodeGraph 두 개다.

`researcher`와 `evidence-auditor`는 ego-browser 스킬을 읽고 bash로 실행한다. 이전 웹 도구를 요구하던 내장 prompt와 도구 목록도 override했다. researcher는 결과 파일 작성을 위해 `write`를 추가로 사용한다. 공유 `~/.agents/skills/ego-browser/SKILL.md`는 Pi의 기본 검색에서 발견되므로 별도 복사나 skills 설정을 추가하지 않았다.

7개 역할에 반복되던 동일 model override를 제거한 뒤 실제 `discoverAgents` 결과가 이전과 동일함을 확인했다. 공통 `defaultModel`이 Sol을 지정한다. 내장 역할의 low/medium/high 값을 덮어쓰는 `thinking: max`는 역할별로 유지했다. 자식의 확장 격리, VCC의 최소 설정 파일, 기본 off인 선택적 Bifrost도 각각 모델 유지·파일 자동 재작성 방지·요청된 라우팅을 위해 남겼다.

- 실제 `ego-browser nodejs`로 임시 task space에서 `https://example.com`을 열고 제목 `Example Domain`을 확인한 뒤 종료했다.
- Pi RPC 시작이 성공했으며 MCP 상태는 `2 servers enabled`, Bifrost는 off였다. `pi list`에는 고정 버전 패키지 다섯 개가 나온다.
- `nix fmt -- homes/workspace/pi.nix files/workspace/.config/mise/config.toml`과 `nix flake check --all-systems --no-build --show-trace`가 통과했다. 전체 시스템 switch는 수행하지 않았다.
- OpenAI 구독 로그인은 여전히 확인되지 않았다. RPC 검사는 인증 가능한 Qwen 모델을 명시했으며 Astra/Sol의 응답 품질이나 구독 연결 성공을 입증하지 않는다.

### pi-interactive-shell 추가 및 지연 로드

`pi-interactive-shell@0.17.0`을 고정하고 `interactive-shell.json`의 `defer: true`를 Home Manager의 개별 파일 연결에 포함했다. 기본 Jev 분류 기능은 off이며, 키가 환경에 있다는 이유로 켜지지 않는다.

실제 macOS PTY에서 background dispatch를 시작하고 입력 `PI_PTY_OK`를 보내 출력 `READY`, `PI_PTY_OK`, `ACK:PI_PTY_OK`를 확인했다. 모델 호출은 0회다. Pi SDK의 RPC 확장 초기화까지 수행한 별도 검사에서 처음에는 `enable_interactive_shell`만 활성화되고, 호출 후 `interactive_shell`을 사용할 수 있었다. 지연 모드에서도 같은 PTY 입력·출력 검사가 통과했다.

직렬화한 parameter schema의 길이는 전체 도구 18,117자, 활성화 도구 33자였다. 이는 schema만의 문자 수이며 토큰 수나 전체 prompt 절약량은 아니다. `/spawn`, `/attach`, `/dismiss` 명령도 등록됐다. 다른 에이전트 위임은 이 확장의 spawn 경로 대신 기존 `pi-subagents`를 사용하도록 지침을 유지했다.

최종 전체 확장 구성에서도 `createAgentSession` 후 `bindExtensions({ mode: "rpc" })`를 거친 실제 시작 상태를 확인했다. 확장 로드 오류는 없었고, 초기 활성 도구에는 `enable_interactive_shell`이 있으며 `interactive_shell`과 이전 네 웹 도구는 없었다. 7개 역할의 최종 Sol/max, 조사 역할의 도구·스킬 상속·빈 확장 목록도 검사했다. PTY 재현 스크립트는 `/tmp/pi-interactive-shell-review/run-probe.mjs`이며 TUI 화면의 사용자 입력 인계는 검증하지 않았다.

OpenAI 모델 경고도 카탈로그와 인증을 나누어 확인했다. 설치된 Pi 0.87.1의 오프라인 전체 카탈로그에는 `openai-codex/gpt-6-astra`와 `openai-codex/gpt-6-sol`이 모두 있다. 현재 OpenAI 구독 인증이 없어 available 모델 수가 0이며 `--list-models`와 enabledModels 검사에서 no-match 경고가 난다. 모델 ID 미지원으로 판정하지 않았고, 실제 구독 응답은 로그인 후 확인해야 한다.
