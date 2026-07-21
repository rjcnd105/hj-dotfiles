# Jira Cloud API 엔드포인트 요약

자주 사용하는 Jira API 엔드포인트 정리입니다.
전체 스펙이 필요하면 웹 검색으로 해당 엔드포인트만 찾아보세요.

**Base URL:** `https://{your-domain}.atlassian.net`

**Swagger:** `https://dac-static.atlassian.com/cloud/jira/platform/swagger-v3.v3.json`

---

## 이슈 검색 (⭐ JQL 필수)

```
GET /rest/api/3/search
```

| 파라미터 | 필수 | 설명 |
|----------|------|------|
| `jql` | ✅ | JQL 쿼리 문자열 |
| `startAt` | - | 시작 인덱스 (기본 0) |
| `maxResults` | - | 최대 결과 수 (기본 50, 최대 100) |
| `fields` | - | 반환할 필드 목록 (예: `summary,status,assignee`) |

**JQL 예시:**

```
project = MYPROJ AND status = "In Progress"
project = MYPROJ AND assignee = currentUser()
project = MYPROJ AND updated >= -7d ORDER BY created DESC
```

---

## 이슈 조회

```
GET /rest/api/3/issue/{issueIdOrKey}
```

| 파라미터 | 필수 | 설명 |
|----------|------|------|
| `issueIdOrKey` | ✅ | 이슈 키 (예: `PROJ-123`) 또는 ID |
| `fields` | - | 반환할 필드 목록 |
| `expand` | - | 확장할 정보 (예: `changelog,renderedFields`) |

---

## 이슈 생성

```
POST /rest/api/3/issue
Content-Type: application/json
```

**Request Body:**

```json
{
  "fields": {
    "project": { "key": "PROJ" },
    "summary": "이슈 제목",
    "description": {
      "type": "doc",
      "version": 1,
      "content": [{"type": "paragraph", "content": [{"type": "text", "text": "설명"}]}]
    },
    "issuetype": { "name": "Task" },
    "assignee": { "accountId": "user-account-id" },
    "labels": ["label1", "label2"]
  }
}
```

---

## 이슈 수정

```
PUT /rest/api/3/issue/{issueIdOrKey}
Content-Type: application/json
```

**Request Body:**

```json
{
  "fields": {
    "summary": "수정된 제목",
    "labels": ["updated-label"]
  }
}
```

---

## 이슈 상태 전환 (Transition)

**1. 가능한 전환 목록 조회:**

```
GET /rest/api/3/issue/{issueIdOrKey}/transitions
```

**2. 상태 전환 실행:**

```
POST /rest/api/3/issue/{issueIdOrKey}/transitions
Content-Type: application/json
```

**Request Body:**

```json
{
  "transition": { "id": "31" }
}
```

---

## 댓글 추가

```
POST /rest/api/3/issue/{issueIdOrKey}/comment
Content-Type: application/json
```

**Request Body:**

```json
{
  "body": {
    "type": "doc",
    "version": 1,
    "content": [{"type": "paragraph", "content": [{"type": "text", "text": "댓글 내용"}]}]
  }
}
```

---

## 담당자 변경

```
PUT /rest/api/3/issue/{issueIdOrKey}/assignee
Content-Type: application/json
```

**Request Body:**

```json
{
  "accountId": "user-account-id"
}
```

---

## 프로젝트 목록 조회

```
GET /rest/api/3/project
```

| 파라미터 | 설명 |
|----------|------|
| `startAt` | 시작 인덱스 |
| `maxResults` | 최대 결과 수 |

---

## 사용자 검색

```
GET /rest/api/3/user/search
```

| 파라미터 | 설명 |
|----------|------|
| `query` | 검색 문자열 (이름, 이메일 등) |

---

## 에러 응답

```json
{
  "errorMessages": ["에러 메시지"],
  "errors": {}
}
```

| 상태 코드 | 의미 |
|----------|------|
| 400 | 잘못된 요청 |
| 401 | 인증 필요 |
| 403 | 권한 없음 |
| 404 | 리소스 없음 |
| 429 | Rate limit 초과 |
