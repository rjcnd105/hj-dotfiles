# ce:light-compound Maintenance Guide

이 문서는 ce:light-compound 스킬을 수정하는 에이전트를 위한 설계 맥락 문서다. 런타임에 로드되지 않는다.

## 설계 의도

compound-engineering의 ce:compound는 3개의 서브에이전트(Context Analyzer, Solution Extractor, Related Docs Finder)를 병렬로 스폰하고, Related Docs Finder는 GitHub issue 검색까지 수행한다. 이후 overlap 5차원 평가, selective refresh, specialized agent review 등이 이어진다.

이 모든 과정이 "문제 해결 문서 하나 쓰기"에는 과도하다. ce:light-compound는 원본의 compact-safe 모드를 기본으로 삼되, 기존 문서 Grep 크로스레퍼런스를 추가하여 중복을 줄인다.

## 원본 스킬 경로

```
~/.claude/plugins/cache/compound-engineering-plugin/compound-engineering/*/skills/ce-compound/SKILL.md
```

## 제거한 것과 이유

| 제거 항목 | 이유 |
|---|---|
| Context Analyzer 서브에이전트 | 대화 맥락에서 직접 추출. 가장 큰 토큰 절약 |
| Solution Extractor 서브에이전트 | 대화 맥락에서 직접 추출 |
| Related Docs Finder 서브에이전트 | 직접 Grep으로 대체 |
| GitHub issue 검색 (`gh issue list`) | 외부 fetch. 너무 무거움 (사용자 피드백) |
| Overlap 5차원 평가 (problem statement, root cause, solution, referenced files, prevention) | 서브에이전트 없이는 불가능. Grep 검색으로 대체 |
| Phase 2.5: Selective Refresh + compound-refresh 연동 | 후속 유지보수 기능. light에서 불필요 |
| Phase 3: Specialized agent review (performance-oracle, security-sentinel 등) | 문서 품질 향상 기능. light에서 불필요 |
| Auto Memory Scan (Phase 0.5) | 메모리 시스템 연동. light에서 불필요 |
| Compact-safe/Full mode 분기 | 항상 single-pass. 모드 분기 자체 불필요 |

## 반드시 유지할 것

1. **YAML frontmatter 스키마** — problem_type, component, root_cause, resolution_type, severity. 이것이 docs/solutions/의 검색 가능성을 보장한다. ce:plan의 learnings-researcher가 이 frontmatter로 문서를 찾는다
2. **카테고리 → 디렉토리 매핑** — problem_type에 따른 디렉토리 구조. 원본과 동일해야 한다
3. **문서 구조** — Problem, Symptoms, What Didn't Work, Solution, Why This Works, Prevention. 원본 Solution Extractor의 출력 구조와 동일
4. **기존 문서 Grep 검색** — 서브에이전트를 없앴으므로 직접 Grep으로 중복을 확인해야 한다. 이 단계를 건너뛰면 같은 문제에 대한 문서가 계속 생긴다
5. **docs/solutions/[category]/ 출력 경로** — 원본과 동일한 위치에 저장해야 검색 시스템이 동작한다

## 수정 시 제약

1. **서브에이전트를 추가하지 않는다** — Context Analyzer, Solution Extractor, Related Docs Finder를 다시 넣으면 ce:compound를 쓰는 것과 같다
2. **외부 fetch를 추가하지 않는다** — GitHub issue 검색, WebSearch 등. 이것이 원본에서 가장 무거운 부분이었다 (사용자 피드백)
3. **YAML frontmatter 스키마를 바꾸지 않는다** — 다른 도구(learnings-researcher 등)가 이 스키마로 문서를 검색한다
4. **self-contained** — ce:compound를 알고 있다고 전제하지 않는다
5. **description에 트리거 문구를 넣지 않는다**
6. **Grep 검색 단계를 건너뛰지 않는다** — 유일한 중복 방지 수단이다

## 사용자 피드백 이력 (2026-03-27 ~ 2026-03-30)

- 서브에이전트 3개 전부 제거 → single-pass
- GitHub issue 검색 등 외부 fetch가 "너무 무겁게 만든다"고 명시적으로 지적
- Overlap 5차원 평가 제거
- compound-refresh 연동 제거
- Phase 3 specialized agent review 제거
- 기존 문서 크로스레퍼런스는 직접 Grep으로 수행해야 한다 (스킬에 명시)
- docs/solutions/ 출력 구조와 YAML frontmatter 스키마는 원본과 동일하게 유지
