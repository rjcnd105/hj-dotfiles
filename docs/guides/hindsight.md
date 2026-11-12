# Hindsight 메모리 서버

Claude Code, Codex, pi가 공유하는 장기 기억 서버다. 용어는 [GLOSSARY.md](../../GLOSSARY.md), 임베딩 모델 결정은 [ADR 0001](../adr/0001-hindsight-embedding-kure-v3-1024.md)을 본다.

## 구성

| 부분 | 위치 | 내용 |
|---|---|---|
| 서버 | `systems/homelab/hindsight.nix` | Hindsight API 1.2.1 컨테이너(리랭커 `hs-rerank-1` 내장), 공유 PostgreSQL의 `hindsight` DB(pgvector) |
| 임베딩 | 같은 파일 | llama.cpp로 KURE-v3 서빙, 앞단 프록시가 1,024차원으로 절단 |
| LLM | 같은 파일 | OpenRouter `deepseek/deepseek-v4.1-flash` (retain의 사실 추출, reflect). `HINDSIGHT_API_LLM_EXTRA_BODY`로 fp8 이상 upstream 중 최저가로 라우팅 |
| 공개 경로 | 같은 파일 | Caddy(loopback) → cloudflared. 인증은 Hindsight API 키 |
| 백업 | `systems/homelab/backup.nix` | 야간 논리 덤프에 `hindsight` DB 포함 |
| 클라이언트 | `homes/workspace/hindsight.nix` | `@vectorize-io/hindsight-coding-agents` 0.8.7을 store에 고정, 설정은 sops로 렌더 |

API 호스트명에는 Cloudflare Access를 걸지 않는다. 코딩 에이전트 클라이언트가 `Authorization: Bearer` 헤더만 보낼 수 있어서다. `/metrics`는 Caddy에서 막는다.

대시보드(Control Plane 1.2.1)는 별도 호스트명 `hindsight-ui.deopjib.cc`로 열고 Beszel과 같은 방식으로 Cloudflare Access(이메일 OTP) 뒤에 둔다. 대시보드 컨테이너가 API 키를 들고 API를 대신 호출하므로, 이 호스트명은 Access 앱 없이 열면 안 된다.

통합(auto consolidation), 코드베이스 조사, git 이력 시딩, 페이지 자동 갱신은 꺼 두었다. 에이전트는 프롬프트마다 recall 결과만 자동 주입받고, 세션이 끝날 때 대화를 retain한다.

## 서버 배포 순서

새 sops secret과 그것을 `LoadCredential`로 읽는 서비스를 한 switch에 넣으면 `243/CREDENTIALS`로 실패한다. 그래서 옵션이 둘이다.

1. `homelab.hindsight.enable` — secret, DB, 임베딩, 라우팅.
2. `homelab.hindsight.server.enable` — DB 설정 oneshot과 API 컨테이너.

3. `homelab.hindsight.dashboard.enable` — 대시보드 컨테이너와 그 라우팅. 대시보드용 env 템플릿은 1에 들어 있다.

sops 템플릿의 `restartUnits`에는 이미 있는 유닛만 넣는다. 없는 유닛이 들어가면 `sops-install-secrets`가 try-restart 실패로 죽어 switch가 깨지고, 이 유닛에 의존하는 `cloudflared`와 `hindsight`가 멈춘다(2026-11-12 실측, 약 4분 중단).

새 호스트에 올릴 때는 1을 먼저 배포하고 2와 3을 따로 배포한다. 대시보드 호스트명은 DNS 레코드보다 Access 앱을 먼저 만든다. 공개 호스트명은 Cloudflare DNS에 터널 레코드로 직접 추가한다.

## 에이전트 연결

세 에이전트가 `~/.hindsight/coding-agents`(Nix store 링크)의 같은 런타임과 `~/.hindsight/coding-agent.json`을 읽는다. 등록 위치는 다음과 같다.

| 에이전트 | hook / extension | MCP |
|---|---|---|
| Claude Code | `files/workspace/.claude/settings.json`의 `hooks` | `~/.claude.json` (아래 명령) |
| Codex | `files/workspace/.codex/hooks.json` | `files/workspace/.codex/config.toml`의 `mcp_servers.hindsight` |
| pi | `files/workspace/.config/pi/settings.json`의 `extensions` | extension이 도구를 직접 등록 |

스킬 `hindsight-coding-agent`는 `files/workspace/.agents/skills`와 `.claude/skills`에서 런타임의 `skill/`로 링크한다.

Claude Code의 사용자 범위 MCP는 저장소 밖 `~/.claude.json`에 있어 새 머신에서는 한 번 등록한다.

```sh
claude mcp add --scope user hindsight \
  --env HINDSIGHT_MCP_HARNESS=claude-code -- \
  node --preserve-symlinks-main \
  "$HOME/.hindsight/coding-agents/dist/mcp-server.js"
```

`--preserve-symlinks-main`은 빼면 안 된다. 런타임이 store로 가는 symlink라서 이 플래그가 없으면 MCP 서버가 자기를 main 모듈로 인식하지 못하고 출력 없이 종료한다. hook 스크립트와 pi extension은 플래그 없이 동작한다.

클라이언트 버전을 올릴 때는 `homes/workspace/hindsight.nix`의 `version`과 `hash`를 함께 바꾼다. `autoUpdate`는 꺼 두었으므로 클라이언트가 스스로 갱신하지 않는다.

## 확인

```sh
curl -s https://hindsight.deopjib.cc/health
tail ~/.hindsight/coding-agents-logs/diag.jsonl
claude mcp get hindsight
codex mcp get hindsight
```

`diag.jsonl`에는 hook마다 `session_start`, `inject_recall`, `retain_ok` 같은 이벤트와 걸린 시간이 남는다.

## 측정 (2026-11-12)

| 항목 | 값 | 조건 |
|---|---|---|
| 서버 기동 | push 후 135초 뒤 `/health` 정상 | 이미지 약 1GB 첫 pull 포함 |
| retain 2건 | 10.3초 | 공개 경로 왕복, LLM 사실 추출 포함 |
| recall API | 1.5–4.0초 | 공개 경로 왕복, 사실 2건 뱅크. 서버 내부 단계 합계는 0.1초 미만 |
| recall API (빈 뱅크) | 1.1–1.4초 | 공개 경로 왕복 |
| 자동 주입 hook | 1.1–1.4초 | `inject_recall` |
| 세션 시작 hook | 1.4–2.3초 | `session_start` |
| 홈랩 임베딩 1건 | 0.22초 | loopback, CPU |
| 홈랩 임베딩 32건 배치 | 4.7초 | loopback, CPU. Mac에서는 같은 GGUF로 0.71초 |
| `hindsight` 컨테이너 메모리 | 1.3GB, 최대 1.7GB | 리랭커 포함 |
| `hindsight-embedding` 메모리 | 1.6GB, 배치 후 2.7GB | 컨텍스트 16,384 토큰 |
| `postgresql` 메모리 | 139MB, 최대 148MB | 앱 DB와 공유 |

홈랩은 RAM 30GB 중 24GB가 남고 swap은 쓰지 않는다. 뱅크가 작아 리랭커가 후보 수십 건을 채점하는 부하와,
사실이 수백 건 쌓인 뱅크에서의 recall 시간은 아직 재지 못했다.

## 실험 목록 (TODO)

기본값으로 두고 나중에 비교해 볼 것들이다. 위에서부터 우선한다.

- [ ] LLM A/B: `deepseek/deepseek-v4.1-flash`와 Spark-X2.6의 사실 추출 품질·비용·지연 비교.
- [ ] 통합 켜기(`HINDSIGHT_API_ENABLE_AUTO_CONSOLIDATION`): observation이 recall 품질에 주는 이득과 CPU·LLM 비용. 과거 CPU 적체 사례는 `docs/solutions/performance-issues/hindsight-auto-consolidation-cpu-backlog.md`.
- [ ] 클라이언트 `codebaseSurvey`, `autoSeed`: 새 저장소에서 초기 뱅크를 채우는 효과와 비용.
- [ ] 페이지 자동 갱신(`pageTriggerType`을 `cron`으로): 페이지가 실제로 쓰이는지 먼저 확인.
- [ ] `autoInject: "reflect"`: recall 주입 대비 품질과 프롬프트당 지연.
- [ ] 임베딩 Vulkan 가속: CPU 대비 처리량. 리랭커 사례는 `docs/solutions/performance-issues/hindsight-reranker-vulkan-acceleration-2026-04-19.md`.
- [ ] 임베딩을 Ollama로 서빙: 기존 Ollama와 합쳐 프로세스를 줄일 수 있는지.
