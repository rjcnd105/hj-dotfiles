# Hindsight Usage

hindsight-memory 플러그인이 장기 기억을 저장할 때 태그 규약을 따른다.

## 태그 구성

저장 시 다음 태그를 항상 붙인다 — 환경변수가 존재할 때만 해당 태그를 포함한다.

| 태그 | 소스 | 조건 |
|------|------|------|
| `user:<값>` | `$HINDSIGHT_BANK_USER` | 필수 — 없으면 저장 중단 |
| `project:<값>` | `$HINDSIGHT_TAG_PROJECT` | env 존재 시 |
| `profile:<값>` | `$HINDSIGHT_TAG_PROFILE` | env 존재 시 |

사용자가 추가 태그를 지정하면 위 기본 태그에 덧붙인다. 기본 태그를 덮어쓰지 않는다.

## 검색 시 태그

recall/reflect 기본: `user:$HINDSIGHT_BANK_USER` + `tags_match: "any_strict"`.
사용자가 "전체", "모든 사용자" 등 범위 확장을 명시하면 태그를 제거한다.
