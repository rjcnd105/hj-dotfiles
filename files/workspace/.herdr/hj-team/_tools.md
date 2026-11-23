# Verified CLI & Script Playbook (`_tools.md`)

서브 에이전트는 추측으로 플래그를 탐색하거나 즉석 스크립트를 작성하기 전에 아래 검증된 도구·프로세스를 먼저 따른다.

## 1. 브라우저 QA (`ego-browser`, `input-replay`, `ego-rec`)
- **브라우저 조작**: Playwright를 띄우지 말고 반드시 `ego-browser`를 사용한다. 첫 호출 전에 `ego-browser skill`로 현재 버전 가이드를 확인하고 `ego-browser nodejs`로 실행한다. `p1` 페이지를 재사용하고 작업 종료 시 별도 스크립트로 `await task.finish({ keep: [] })`를 호출한다.
- **휠·트랙패드·터치 제스처 재현**: 임의의 `mouse.wheel` 대신 `input-replay` 스킬의 `scripts/replay.mjs`를 사용해 실측 장치 타이밍으로 재현한다.
- **녹화 기반 회귀 테스트**: `ego-rec` 녹화가 있으면 `ego-rec test <automation.mjs>`로 검증한다.
- **라이브 서버 URL 확인**: 하드코딩이나 포트 추측 대신 `hc-team servers --run <runId>`로 현재 런의 실제 URL을 먼저 조회한다.

## 2. VCS (`jj` vs `git`) & PR (`simple-pr`)
- 저장소 작업 전 `jj root >/dev/null 2>&1`로 `VCS_KIND`를 먼저 판별한다(성공 시 `jj`, 아니면 `git`).
- Bitbucket PR 생성·조회는 브라우저나 Bitbucket API를 직접 치지 말고 `simple-pr` CLI를 사용한다(GitHub는 `gh`).

## 3. 팀 협업 (`hc-team`, `hc`)
- 다른 role·parent 보고는 `hc-team send <role|parent> "<summary>" --kind <handoff|result|review|blocked|ask>`를 사용한다.
- 다른 터미널 출력 확인은 `hc ls` 후 `hc read <addr>`를 사용한다.

## 4. 기존 프로젝트 메모리 · 시행착오 재사용
- 하네스에 `hindsight` MCP(`hindsight_list_pages`, `hindsight_search_pages`)나 프로젝트 `docs/agent-presets/<preset>/` 오버레이가 있으면 명령을 추측하기 전에 먼저 조회한다.
- 새로 알아낸 작동 명령·주의점은 최종 `hc-team send --kind result` 요약에 1줄로 남겨 다음 런이 같은 시행착오를 반복하지 않게 한다.
