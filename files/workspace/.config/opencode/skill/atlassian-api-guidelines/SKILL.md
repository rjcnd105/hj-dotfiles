---
name: atlassian-api-guidelines
description: "Jira 티켓 생성/검색/조회/상태변경, Bitbucket PR 생성/읽기/머지/승인 등 Atlassian API 작업 시 활성화. JQL 쿼리, q 파라미터를 통한 서버 사이드 필터링 필수. 'jira 티켓 만들어줘', 'jira 이슈 검색', 'bitbucket pr 생성', 'pr 머지해줘', 'pr 승인' 등의 요청에 사용."
license: MIT
compatibility: opencode
metadata:
  audience: developers
  category: api-best-practices
  triggers: jira, bitbucket, ticket, issue, pr, pullrequest, merge, approve
---

## What I do

Atlassian (Jira & Bitbucket) Cloud API를 사용할 때 효율적이고 표준화된 방식을 안내합니다.

- 서버 사이드 필터링(JQL, q 파라미터) 사용 강제
- Swagger 명세서를 Source of Truth로 참조하도록 유도
- 페이지네이션, 인증, 에러 처리 가이드 제공

## When to use me

- Jira 이슈를 생성, 검색, 조회, 상태 변경할 때
- Bitbucket PR을 생성, 조회, 머지, 승인할 때
- Bitbucket 레포지토리 정보를 조회할 때
- API 연동 코드를 작성하거나 리뷰할 때

## 핵심 원칙

### 1. 서버 사이드 필터링 필수 (⚠️ 가장 중요)

**❌ 절대 하지 말 것:**

```
// 전체 데이터 받아서 클라이언트에서 필터링 - 비효율적!
let all_issues = get_all_issues();
let filtered = all_issues.filter(i => i.status == "Open");
```

**✅ 반드시 할 것:**

- **Jira:** JQL(Jira Query Language)로 서버에서 필터링
- **Bitbucket:** `q` 파라미터로 서버에서 필터링

### 2. 명세서 참조 방법

특정 엔드포인트의 정확한 스펙이 필요하면:

1. **웹 검색으로 해당 엔드포인트만 찾기** (권장 - 토큰 절약)
2. 또는 아래 Swagger URL에서 필요한 부분만 확인:

| 서비스 | Swagger URL |
|--------|-------------|
| Jira Cloud | `https://dac-static.atlassian.com/cloud/jira/platform/swagger-v3.v3.json` |
| Bitbucket Cloud | `https://dac-static.atlassian.com/cloud/bitbucket/swagger.v3.json` |

⚠️ **주의:** 전체 Swagger 파일을 읽지 말 것! 수백만 토큰을 소비함.

### 3. 페이지네이션

| 서비스 | 필드 |
|--------|------|
| Jira | `startAt`, `maxResults`, `total` |
| Bitbucket | `pagelen`, `page`, `next` |

### 4. 인증

- **Jira/Bitbucket Cloud:** Basic Auth (email + API token) 또는 OAuth 2.0
- Authorization 헤더: `Basic base64(email:api_token)`

### 5. 에러 처리

상태 코드별 처리 필수:

- `200/201`: 성공
- `400`: 잘못된 요청 (파라미터 확인)
- `401`: 인증 실패
- `403`: 권한 없음
- `404`: 리소스 없음
- `429`: Rate limit 초과

## 자주 사용하는 API 요약

### Jira 주요 작업

👉 **상세 정보: `jira-endpoints.md` 참조**

- 이슈 검색 (JQL 필수)
- 이슈 생성/조회/수정
- 상태 전환 (Transition)
- 댓글 추가
- 담당자 변경

### Bitbucket 주요 작업 (읽기/PR 위주)

👉 **상세 정보: `bitbucket-endpoints.md` 참조**

- PR 생성/조회/목록
- PR 머지/승인/거절
- PR 코멘트
- 레포지토리 조회
- 브랜치/커밋 조회

⚠️ **레포지토리 설정 변경 API는 사용하지 말 것**
