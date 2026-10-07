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

이 설정에서는 Pi 기본 편집 도구를 유지하고, MCP와 서브에이전트 도구는 필요한 시점에 활성화한다. Astra/high 기본값과 Sol/max 위임은 사용자의 작업 방식과 명시한 선호를 반영한다. 위 벤치마크가 그 조합의 최적성을 입증한 것은 아니다. 2026-10-07 비교 뒤 위임 강제는 제거했고 Astra 기본값은 xhigh로 바꿨다([위임 강제 제거](#위임-강제-제거-2026-10-07)).

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

## 위임 강제 제거 (2026-10-07)

실제 업무에서 가져온 미션 8종으로 Pi 1.0.4와 Codex CLI 0.160.1을 비교했다. 미션은 nix-dots 평가 오류 수정, 홈랩 변경 리뷰, Pi 문서 정리, Godot 게임 기능, ps-frontend-admin 기능 2건, gentle-renewal 버그 2건이다. 각 미션은 실제 저장소의 APFS 복제본에서 herdr headless 세션으로 TUI를 띄워 실행했다. 채점은 에이전트가 볼 수 없는 숨은 테스트, 기존 회귀 테스트, 타입·린트 기준선, 범위 검사로 했다. 리뷰와 문서 미션은 rubric으로 판정했다.

비교한 하네스는 네 가지다. cur는 실험 전 실제 설정이며 홈 아래에서 실행했다. lean은 위임 강제와 중복 지침을 걷어내고 내장 MCP와 스킬 10개 제외를 더한 별도 agent 디렉터리이며 Astra는 high다. final은 아래 변경을 모두 반영한 실제 설정(Astra xhigh)이며, switch 이후 상태와 같도록 홈 밖에서 실행했다. Codex에는 final과 지침이 같고 Astra만 high인 final·high를 더해 반복 측정했다.

| 비교 (미션별 중앙값, 8미션) | 시간 | API 환산 비용 | 처리 토큰 |
|---|---:|---:|---:|
| Pi cur → lean | −40% | −33% | −58% |
| Codex cur → lean | −46% | −44% | −78% |
| cur → final (Pi·Codex) | −1% | −12% | −60% |
| Pi lean → final (high → xhigh) | +59% | +25% | +14% |
| Codex final·high → final (high → xhigh) | +61% | +46% | +35% |
| Codex lean → final·high (반복 측정 평균) | +4% | −5% | +7% |

60회 실행이 모두 채점을 통과했다. cur 실행은 거의 매번 서브에이전트를 1~2개 띄웠고(16회 중 18개), 나머지 설정은 한 번도 띄우지 않았다. 시간·비용 차이는 대부분 강제 위임에서 나왔다. Codex는 Pi 전용 지침 없이 공용 지침만 읽는데도 cur에서 `gpt-6-sol` 서브 스레드를 띄웠다. Codex 비용은 rollout의 요청별 토큰에 Pi 1.0.4의 같은 가격표를 적용한 추정이다.

Astra xhigh는 그 시간 이득을 대부분 되돌렸다. Pi와 Codex 모두 8개 미션 전부에서 high보다 오래 걸렸고, 출력 토큰 중앙값이 약 1.6배, Codex 추론 토큰 중앙값이 922에서 2,726으로 늘었다. 품질은 모두 통과했고, rubric 차이는 N2에서 Pi가 secret을 먼저 배포하는 두 단계 순서까지 짚어 3.5점에서 4.0점이 된 한 건이다. 기본값 xhigh는 사용자 결정으로 반영했다.

Codex lean과 final·high는 설정 파일이 같고 공용 지침이 "결과를 기다려 검토한다"는 한 문장만 다르다. 같은 설정을 두 번 돌린 P1·R2에서도 시간이 최대 1.8배 벌어졌다. 미션당 1회 실행의 차이로 하네스의 우열을 판단하지 않는다.

Pi cur의 system prompt는 51.6K자였다. 홈 아래 저장소에서는 `~/.pi/agent/AGENTS.md`와 `~/AGENTS.md`로 개인 지침을 두 번 읽었다(10.1K자 중복). final은 33.6K자다. 스킬 목록이 16.4K자에서 10.7K자로, Pi 전용 지침이 2.0K자에서 0.6K자로 줄었다.

반영한 변경은 다음과 같다.

- 공용 지침의 위임 규칙을 바꿨다. 메인 세션이 계획·구현·검증을 직접 맡고, 병렬 독립 작업, 긴 기계적 처리, 명시 요청이 있을 때만 위임한다. 위임 모델은 런타임이 제공하면 `gpt-6.1-sol`/high이고, 아니면 런타임 기본 서브에이전트 모델이다(2026-10-08, [Claude Code 측정](#claude-code-측정-2026-10-08)). 위임하면 결과를 기다려 검토한다. Pi cur는 비동기 서브에이전트를 띄운 뒤 "진행 중" 답으로 턴을 끝냈다가 완료 알림에 다시 깨어났다.
- 일반 `apm compile`이 만드는 `files/workspace/AGENTS.md`와 `CLAUDE.md`의 추적을 해제하고 `.gitignore`로 제외했다. `~/CLAUDE.md`는 agent-playbook의 CLAUDE.md를 Claude Code에 불러오고 있었다.
- `APPEND_SYSTEM.md`를 2.0K자에서 0.6K자로 줄였다. 위임 절차와 공용 지침과 겹치는 문단을 빼고 도구 메모만 남겼다.
- pi-mcp-adapter를 Pi 내장 MCP로 바꿨다. `files/workspace/.config/pi/mcp.json`이 Context7과 CodeGraph를 `deferred`로 선언한다. 내장 MCP는 신뢰한 프로젝트의 `.pi/mcp.json`만 읽으므로, gentle-renewal과 my-backend의 `.mcp.json` Figma 서버는 Pi에서 로드되지 않는다.
- 코딩 작업에서 쓰지 않는 스킬 10개를 Pi에서만 제외했다.
- Pi와 Codex의 기본값을 `gpt-6-astra`/xhigh로 맞췄다. Codex 저장소 원본에는 live 파일에만 있던 brilliant MCP를 옮겼다.
- ps-frontend-admin처럼 Node 22.14를 고정한 저장소에서는 Pi 1.0.4가 zstd 응답을 받는 순간 `zlib.createZstdDecompress` 오류로 멈췄다. cur와 lean은 `MISE_NODE_VERSION=26`으로 우회했다. 전역 mise 설정의 `postinstall`이 Pi shim 옆에 Node 26 링크를 두게 한 뒤, final의 P1·P2는 우회 없이 Node 26으로 실행돼 통과했다.

## Claude Code 측정 (2026-10-08)

같은 미션 8종을 Claude Code 2.1.293(Opus 5.5)로 74회 실행했다. 실행은 `claude -p --setting-sources project,local`로 사용자 설정을 빼고, 변형별 settings·지침·스킬과 실험용 MCP 설정만 주입했다. lean과 high는 미션마다 두 번 돌려 미션별 평균을 비교했다. claude.ai 플랜 사용량 한도에 걸린 16회는 무효로 빼고 다시 돌렸다. 동시 실행 부하로 시간이 흔들렸으므로 비용과 API 시간을 우선 본다.

변형은 다음과 같다. cur는 10-07 이전 지침을 두 번 읽고 스킬을 모두 올린 실험 전 설정이다. lean은 지침을 한 번만 읽고, 위임 문장이 런타임 중립이며, 스킬 9개를 끈 설정이다. 나머지는 lean 위에 하나씩 바꿨다. high는 effort high, coord는 `CLAUDE_CODE_COORDINATOR_MODE=1`(N1·P1·R2만), opus+adv·sonnet+adv·haiku+adv는 메인 모델을 Opus 5.5·Sonnet 5.5·Haiku 5.5로 두고 `--advisor opus`를 붙였다. scout는 "Use proactively" 설명을 단 Haiku 5.5 읽기 전용 서브에이전트를 등록했다. effort는 high를 빼고 모두 xhigh다.

숨은 테스트는 통과와 실패만 가리므로 품질을 따로 쟀다. 미션마다 채점자 서브에이전트 하나가 변형 이름을 가린 제출물(diff, 최종 보고, 채점 출력)을 무작위 순서로 받아 정확성·설계·테스트·보고를 1~5점, 종합을 10점으로 매겼다. 8개 미션의 제출 98개를 채점했고, 변형마다 돌린 미션이 달라 같은 미션의 Claude lean 점수와의 차이를 비교한다.

| 변형 (비교 기준) | 시간 | 비용 | 품질 차이 | 주요 결함 |
|---|---:|---:|---:|---:|
| lean (cur 대비) | +3% | −12% | +0.5점 | 1건/16회 (cur 2건/8회) |
| high (lean 대비) | −26% | −31% | −1.3점 | 8건/16회 |
| coord (lean 대비, 3미션) | +65% | +70% | −1.8점 | 3건/3회 |
| opus+adv (lean 대비) | +72% | +94% | +0.1점 | 0건/9회 |
| sonnet+adv (lean 대비) | +33% | +4% | −0.3점 | 3건/9회 |
| haiku+adv (lean 대비) | +31% | −48% | −0.7점 | 1건/9회 |
| scout (lean 대비, 4미션) | −3% | +24% | +0.0점 | 1건/4회 |

시간과 비용은 미션별 평균 비율의 중앙값이다. 같은 설정을 두 번 돌리면 한 미션 안에서 채점 점수가 평균 1.1점 벌어졌으므로 0.5점 안쪽 차이는 변동으로 본다. 자동 채점은 74회 중 72회가 통과했고, 실패한 N3 high와 R2 coord 실행은 채점자도 해당 미션 최하위에 두었다. P1·P2는 처음 묶음의 채점 출력 경로에 변형 이름이 남아 있어 경로를 지우고 다시 채점했다. 두 채점의 순위 상관은 0.82, 제출당 점수 차이는 평균 0.4점이었다. 채점자도 Claude이므로 Claude식 보고를 선호할 수 있고, Pi·Codex는 diff가 남은 실행만 들어가 Claude 변형끼리의 비교에만 쓴다.

판단은 다음과 같다.

- 이전 위임 문구는 Claude를 위임시키지 않았다. 코디네이터 모드 밖의 Claude 실행은 서브에이전트를 한 번도 띄우지 않았다. lean의 이득은 컨텍스트와 비용이다. 세션 시작 메모리가 6.2K에서 3.1K 토큰으로, 스킬 목록이 9.3K에서 8.5K 토큰으로 줄었다.
- effort는 xhigh를 유지한다. high는 8개 미션 모두에서 더 쌌지만, 요구 누락(N1 "경고 없이"), 날짜 기록 수정과 거짓 보고(N3), 문자열 입력에 `string | null | undefined`를 돌려주는 `maskName` 시그니처(P2)가 모두 high에서 나왔다. 숨은 테스트는 그중 N3만 잡았다.
- advisor는 기본값으로 두지 않는다. Opus advisor는 주요 결함이 없었지만 평균 점수가 lean과 같았고 비용은 거의 두 배였다. advisor 호출 42회 중 10회는 429·overloaded로 실패해 조언 없이 진행됐다. Opus 5.5 메인에 Haiku advisor를 주면 경고만 내고 무시한다. 위험한 변경에서만 `claude --advisor opus`나 `/advisor opus`로 켠다.
- Haiku 5.5 + Opus advisor는 비용이 절반이고 모든 실행이 숨은 테스트를 통과했지만, 설계 판단이 많은 G1에서 가장 낮았다. 비용의 68%가 advisor이며, advisor가 실패한 P1에서는 Haiku 단독으로 $0.06~0.08에 통과했다. 기본 설정으로 두지 않고, 위험이 낮은 반복 작업에서 세션 단위로 고른다.
- Haiku scout는 4개 미션에서 한 번도 호출되지 않아 `files/workspace/.claude/agents/`에 추가하지 않았다.
- 코디네이터 모드는 메인 스레드에 도구 6개만 남긴다. R2에서는 worker가 도는 중에 "진행 중" 보고로 끝나고 tsc 기준선을 깼고, N1에서는 확인하지 않은 내용을 검증했다고 보고했다.

반영한 변경은 다음과 같다.

- `files/workspace/.claude/CLAUDE.md`를 지웠다. `~/.claude/CLAUDE.md`가 `@../.codex/AGENTS.md`를 import하고 APM이 배포한 `~/.claude/rules/personal-agent-guide.md`도 같은 지침을 실어 두 번 읽고 있었다.
- 공용 지침의 실행 서브에이전트 모델 문장을 런타임 중립으로 바꿨다(위 10-07 변경 참고).
- `files/workspace/.claude/settings.json`의 `skillOverrides`로 최근 120일 Claude 세션에서 호출 0회인 스킬 9개(`but`, `elixir`, `find-docs`, `find-skills`, `hindsight`, `kb`, `obsidian-bases`, `obsidian-markdown`, `setup-pstack`)를 껐다.
- 전역 mise `[env]`에서 `CLAUDE_CODE_COORDINATOR_MODE=1`과 `CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING=1`을 지웠다. 앞의 것은 문서에 없는 플래그로 `claude -p`와 SDK 실행을 코디네이터 모드로 바꿨고, 뒤의 것은 Opus 5.5에 효과가 없다.
