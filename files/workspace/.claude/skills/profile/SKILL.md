---
name: profile
description: >-
  프로필을 로드/언로드하여 에이전트의 행동 맥락을 세션 단위로 전환한다.
  `/profile load <name>` — ~/.claude/profiles/<name>/PROFILE.md를 읽어 세션에 주입. 로드 후 에이전트는 해당 프로필의 성격, 가치관, 커뮤니케이션 스타일, failure mode 감지 등의 지침에 따라 행동한다.
  `/profile unload` — 현재 프로필을 해제하고 기본 행동으로 복귀.
  `/profile list` — 사용 가능한 프로필 목록 표시.
  "프로필 로드", "load profile", "프로필 전환", "프로필 불러와", "@profile", "프로필 켜", "switch profile" 등의 표현이나 /profile 호출 시 사용. 사용자가 특정 이름(예: "hj 프로필 로드해줘")을 언급하면 바로 load를 실행할 것.
---

# Profile

프로필은 에이전트의 행동을 구속하는 세션 단위 맥락이다. 로드하면 해당 프로필이 정의한 성격, 가치관, 커뮤니케이션 스타일, failure mode 감지 기준 등이 세션이 끝나거나 명시적으로 언로드할 때까지 적용된다.

## 명령어

| 명령 | 설명 |
|------|------|
| `/profile load <name>` | 프로필 로드 |
| `/profile unload` | 프로필 해제 |
| `/profile list` | 사용 가능한 프로필 목록 |

인자 없이 `/profile`만 호출하면 `list`로 취급한다.

## 프로필 위치

```
~/.claude/profiles/
├── index.md
├── hj/
│   ├── PROFILE.md      ← 로드 대상
│   ├── sessions/
│   └── memories/
└── other-profile/
    └── PROFILE.md
```

## 실행 절차

### `load <name>`

1. `~/.claude/profiles/<name>/PROFILE.md` 존재 확인 (Read 도구 사용)
2. 파일이 없으면: `프로필 [<name>]을 찾을 수 없습니다. /profile list로 사용 가능한 프로필을 확인하세요.` 출력 후 종료
3. 이미 다른 프로필이 로드된 상태면: 기존 프로필을 자동 언로드 (별도 안내 불필요)
4. PROFILE.md 전체 내용을 읽는다
5. 아래 형식으로 프로필을 출력한다:

```
---
PROFILE LOADED: <name>
이 세션에서 `/profile unload`가 호출되거나 세션이 종료될 때까지
아래 프로필의 지침에 따라 행동한다.
---

{PROFILE.md 전체 내용}

---
END PROFILE: <name>
---
```

6. `프로필 [<name>] 로드 완료.` 출력
7. 이후 모든 응답에서 프로필의 지침을 따른다 — 성격, 가치관, 커뮤니케이션 스타일, failure mode 감지 등

로드 시 주의사항:
- `sessions/`와 `memories/` 하위 디렉토리는 읽지 않는다. PROFILE.md 안에 정의된 Navigation Protocol에 따라 필요할 때만 on-demand로 접근한다.
- 프로필에 정의된 행동 지침은 대화 전반에 걸쳐 지속적으로 적용한다. 프로필이 "직접적으로 지적하라"고 명시했으면, 실제로 그렇게 행동해야 한다.

### `unload`

1. 현재 로드된 프로필이 없으면: `로드된 프로필이 없습니다.`
2. 있으면:

```
---
PROFILE UNLOADED: <name>
프로필 행동 지침이 해제되었습니다. 기본 행동으로 복귀합니다.
---
```

3. `프로필 [<name>] 언로드 완료.`

### `list`

`scripts/list.sh`를 실행하여 사용 가능한 프로필 목록을 출력한다.

```bash
bash <skill-dir>/scripts/list.sh
```

스크립트가 `~/.claude/profiles/` 하위 디렉토리를 탐색하여 `PROFILE.md`가 존재하는 프로필의 이름과 제목을 출력한다. 결과 앞에 `사용 가능한 프로필:` 헤더를 붙여 표시한다.
