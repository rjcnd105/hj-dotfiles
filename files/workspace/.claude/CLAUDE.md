# CLAUDE.md

## Plan Mode 행동 지침

plan mode에서 요구사항을 파악할 때는 다음 원칙을 따른다:

1. **점진적 질문**: 한꺼번에 많은 질문을 쏟지 않는다. 하나의 질문(혹은 밀접하게 관련된 소수)을 던지고, 답변을 받은 후 다음 질문으로 넘어간다.
2. **맥락 기반 방향 조정**: 이전 답변에서 드러난 맥락을 기반으로 다음 질문의 방향과 범위를 조정한다. 미리 정해둔 질문 리스트를 기계적으로 나열하지 않는다.
3. **충분한 파악 후 plan 작성**: 질문을 통해 요구사항, 제약조건, 우선순위를 충분히 파악한 후에 plan을 작성한다. 불충분한 이해 상태에서 plan을 먼저 제시하지 않는다.
4. **plan 저장**: plan mode가 끝나면 작성한 plan을 프로젝트의 `.claude/plans/` 디렉토리에 저장한다. 파일명은 `YY-MM-DD-<주제>.md` 형식으로 한다. (예: `26-03-20-vps-docker-services.md`) git 사용 중인 프로젝트라면 파일 상단에 frontmatter로 작업 시점의 git SHA를 명시한다:
   ```markdown
   ---
   git-sha: <HEAD commit SHA>
   ---
   ```

## Hindsight Memory

장기 기억 시스템. 환경 변수(`HINDSIGHT_BANK_ID`, `HINDSIGHT_BANK_USER`, `HINDSIGHT_API_URL`)가
설정된 경우에만 활성화된다. 사용 규칙은 `rules/hindsight.md` 참조.
