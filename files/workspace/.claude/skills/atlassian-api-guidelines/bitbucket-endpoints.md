# Bitbucket Cloud API 엔드포인트 요약

자주 사용하는 Bitbucket API 엔드포인트 정리입니다.
전체 스펙이 필요하면 웹 검색으로 해당 엔드포인트만 찾아보세요.

**Base URL:** `https://api.bitbucket.org/2.0`

**Swagger:** `https://dac-static.atlassian.com/cloud/bitbucket/swagger.v3.json`

⚠️ **주의:** 레포지토리 설정 변경 API는 사용 금지

---

## PR 목록 조회

```
GET /repositories/{workspace}/{repo_slug}/pullrequests
```

| 파라미터 | 설명 |
|----------|------|
| `state` | PR 상태 필터: `OPEN`, `MERGED`, `DECLINED`, `SUPERSEDED` |
| `q` | 쿼리 필터 (예: `state="OPEN"`) |
| `sort` | 정렬 (예: `-created_on`) |
| `pagelen` | 페이지당 결과 수 (최대 50) |

**q 파라미터 예시:**

```
q=state="OPEN" AND author.account_id="user-id"
q=destination.branch.name="main"
```

---

## PR 상세 조회

```
GET /repositories/{workspace}/{repo_slug}/pullrequests/{pull_request_id}
```

---

## PR 생성

```
POST /repositories/{workspace}/{repo_slug}/pullrequests
Content-Type: application/json
```

**Request Body:**

```json
{
  "title": "PR 제목",
  "description": "PR 설명",
  "source": {
    "branch": { "name": "feature-branch" }
  },
  "destination": {
    "branch": { "name": "main" }
  },
  "close_source_branch": true,
  "reviewers": [
    { "account_id": "reviewer-account-id" }
  ]
}
```

---

## PR 수정

```
PUT /repositories/{workspace}/{repo_slug}/pullrequests/{pull_request_id}
Content-Type: application/json
```

**Request Body:**

```json
{
  "title": "수정된 제목",
  "description": "수정된 설명"
}
```

---

## PR 머지

```
POST /repositories/{workspace}/{repo_slug}/pullrequests/{pull_request_id}/merge
Content-Type: application/json
```

**Request Body (선택):**

```json
{
  "message": "머지 커밋 메시지",
  "close_source_branch": true,
  "merge_strategy": "merge_commit"
}
```

| merge_strategy | 설명 |
|----------------|------|
| `merge_commit` | 머지 커밋 생성 |
| `squash` | 스쿼시 머지 |
| `fast_forward` | Fast-forward 머지 |

---

## PR 승인

```
POST /repositories/{workspace}/{repo_slug}/pullrequests/{pull_request_id}/approve
```

## PR 승인 취소

```
DELETE /repositories/{workspace}/{repo_slug}/pullrequests/{pull_request_id}/approve
```

---

## PR 거절 (Decline)

```
POST /repositories/{workspace}/{repo_slug}/pullrequests/{pull_request_id}/decline
```

---

## PR 코멘트 목록

```
GET /repositories/{workspace}/{repo_slug}/pullrequests/{pull_request_id}/comments
```

## PR 코멘트 추가

```
POST /repositories/{workspace}/{repo_slug}/pullrequests/{pull_request_id}/comments
Content-Type: application/json
```

**Request Body:**

```json
{
  "content": {
    "raw": "코멘트 내용"
  }
}
```

**인라인 코멘트 (코드 리뷰):**

```json
{
  "content": { "raw": "코드 리뷰 코멘트" },
  "inline": {
    "path": "src/main.rs",
    "to": 42
  }
}
```

---

## 레포지토리 조회

```
GET /repositories/{workspace}/{repo_slug}
```

---

## 브랜치 목록

```
GET /repositories/{workspace}/{repo_slug}/refs/branches
```

| 파라미터 | 설명 |
|----------|------|
| `q` | 필터 쿼리 (예: `name ~ "feature"`) |
| `sort` | 정렬 (예: `-target.date`) |
| `pagelen` | 페이지당 결과 수 |

---

## 커밋 목록

```
GET /repositories/{workspace}/{repo_slug}/commits
```

| 파라미터 | 설명 |
|----------|------|
| `branch` | 특정 브랜치의 커밋만 |
| `include` | 포함할 커밋/브랜치 |
| `exclude` | 제외할 커밋/브랜치 |

---

## 커밋 상세

```
GET /repositories/{workspace}/{repo_slug}/commit/{commit}
```

---

## Diff 조회

```
GET /repositories/{workspace}/{repo_slug}/diff/{spec}
```

`spec` 예시: `main..feature-branch`, `commit-hash`

---

## 파일 내용 조회

```
GET /repositories/{workspace}/{repo_slug}/src/{commit}/{path}
```

---

## 에러 응답

```json
{
  "type": "error",
  "error": {
    "message": "에러 메시지"
  }
}
```

| 상태 코드 | 의미 |
|----------|------|
| 400 | 잘못된 요청 |
| 401 | 인증 필요 |
| 403 | 권한 없음 |
| 404 | 리소스 없음 |
| 429 | Rate limit 초과 |
