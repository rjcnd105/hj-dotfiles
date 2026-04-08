# KB Skill Maintenance

## 설계 의도

Karpathy LLM Wiki 패턴을 Obsidian vault에 적용. Clippings/(외부 기사)만 raw source로 취급하고, kb/ 디렉토리에 AI가 종합 위키를 유지한다. Dev/ 노트는 사용자의 자체 종합이므로 ingest 대상이 아님.

핵심 설계 결정:
- SCHEMA.md가 시스템 규칙의 단일 원천. SKILL.md는 라우팅만.
- INDEX.md는 generated artifact (캐시). 손상 시 rebuild-index로 복구.
- 타입 제안은 lint 시점에만 (decision fatigue 방지).
- 타입 2개(topic, source-summary)로 시작, 사용하며 진화.

## 제거한 것

- source-summary 타입: 원본 Clipping이 이미 있으므로 기사 요약은 불필요한 중복. 위키 페이지는 개념 단위로만 존재
- sync 서브커맨드: ingest 배치 모드로 통합
- 6종 타입 시스템: 과잉 추상화. topic 1개로 시작
- Dev/ 노트 재종합: 이중 진실원천 문제 유발
- ingest 중 타입 제안: flow 중단 + decision fatigue
- 기사 1:1 매칭: Karpathy 안티패턴. "single source might touch 10-15 wiki pages"

## 수정 제약

- SCHEMA.md의 진화 프로토콜을 우회하지 않는다 (타입 추가/수정은 반드시 프로토콜 경유)
- Clippings/ 외 폴더를 ingest 대상에 추가하지 않는다 (이중 진실원천 방지)
- SKILL.md 500줄 이하 유지 (progressive disclosure)

## 피드백 이력

- 2026-04-07: 초기 버전 생성. document-review에서 P0 2건(pain 부재, 이중 진실원천) 발견 → Clippings 전용으로 범위 축소, 타입 2개로 경량화. UX 분석에서 decision fatigue 우려 → 타입 제안을 lint로 이동.
