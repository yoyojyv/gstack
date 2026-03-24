---
title: Claude Code 플러그인 & 마켓플레이스 삽질 기록
date: 2026-03-24
context: gstack을 Claude Code 플러그인으로 래핑하면서 발견한 사항들
---

# Claude Code 플러그인 & 마켓플레이스 삽질 기록

## TL;DR

- plugin.json은 `.claude-plugin/` 디렉토리 안에 있어야 플러그인으로 인식된다
- `author` 필드는 문자열이 아닌 객체(`{ "name": "..." }`) 형식이어야 한다
- **commands/와 skills(SKILL.md)는 별개 시스템** — 스킬만 있으면 슬래시 커맨드가 등록되지 않는다
- 커맨드의 `name` 필드에 플러그인명 prefix가 자동 추가되지 않으므로 직접 `gstack:qa` 형태로 넣어야 한다
- 플러그인 캐시 초기화 = Claude Code 세션 재시작 (`/exit` 후 재진입)

---

## 1. 플러그인 디렉토리 구조

### 발견: plugin.json은 `.claude-plugin/` 안에 있어야 한다

프로젝트 루트에 `plugin.json`을 두면 Claude Code가 플러그인으로 인식하지 않는다.
반드시 `.claude-plugin/plugin.json` 경로에 위치해야 auto-discovery가 동작한다.

```
gstack-plugin/
├── .claude-plugin/
│   └── plugin.json        # 여기 있어야 인식됨
├── commands/               # 슬래시 커맨드 정의
│   ├── ship.md
│   ├── qa.md
│   └── ...
├── ship/
│   └── SKILL.md            # 스킬 정의 (자동 트리거용)
└── ...
```

**커밋:** `e3adb26 fix: move plugin.json to .claude-plugin/ for proper plugin discovery`

---

## 2. plugin.json 스키마

### 발견: author는 객체여야 한다

```json
// 틀린 예
{ "author": "garrytan (wrapped by yoyojyv)" }

// 맞는 예
{ "author": { "name": "garrytan (wrapped by yoyojyv)" } }
```

문자열로 넣으면 플러그인 로딩 시 검증 에러가 발생한다.

**커밋:** `4258b22 fix: plugin.json author field must be object, not string`

---

## 3. Commands vs Skills — 완전히 별개 시스템

### 발견: SKILL.md만으로는 슬래시 커맨드가 등록되지 않는다

이것이 가장 큰 혼동 포인트였다.

| 구분 | Skills (SKILL.md) | Commands (commands/*.md) |
|------|-------------------|--------------------------|
| 위치 | `<skill-dir>/SKILL.md` | `commands/<name>.md` |
| 등록 방식 | description 기반 자동 매칭 | `/` 슬래시 커맨드로 직접 호출 |
| 호출 방식 | 사용자가 관련 키워드 말하면 자동 트리거 | `/gstack:ship` 처럼 명시적 호출 |
| 필수 여부 | 자동 트리거 원하면 필요 | 슬래시 커맨드 원하면 필요 |

**핵심:** 둘 다 있어야 완전한 플러그인이다.
- Skills → "ship해줘" 같은 자연어에 자동 반응
- Commands → `/gstack:ship` 으로 명시적 실행

`commands/`를 삭제하면 스킬의 자동 트리거는 남지만, 슬래시 커맨드 목록에서 완전히 사라진다.

**커밋:** `316c961`에서 commands/ 삭제 → `4ed3fd9`에서 복원

---

## 4. 커맨드 네이밍: prefix는 수동으로 넣어야 한다

### 발견: 플러그인명이 커맨드 name에 자동 prefix 되지 않는다

```yaml
# commands/qa.md
---
name: qa              # → "/qa (gstack)" 으로 표시됨
---
```

```yaml
# commands/qa.md (수정 후)
---
name: gstack:qa       # → "/gstack:qa (gstack)" 으로 표시됨
---
```

플러그인 시스템은 `name` 필드를 그대로 슬래시 커맨드명으로 사용한다.
`(gstack)` 레이블은 출처 표시일 뿐, 커맨드명 자체에 영향을 주지 않는다.

prefix 없이 `name: qa`로 두면:
- 다른 플러그인의 `/qa`와 충돌 가능
- `/gstack` 타이핑 시 자동완성에 나타나지 않음
- 사용자가 어느 플러그인의 커맨드인지 구분 불가

**커밋:** `8b77a9c fix: add gstack: prefix to all command names for proper namespacing`

---

## 5. 플러그인 캐시 & 리로드

### 발견: 별도 캐시 삭제 명령은 없다

- 플러그인 변경 반영 = **Claude Code 세션 재시작** (`/exit` → 재진입)
- 로컬 파일 변경은 재시작 시 즉시 반영됨
- 원격 설치된 플러그인은 `git fetch && git reset --hard` 후 재시작

---

## 6. 커맨드 파일 구조 (commands/*.md)

```yaml
---
name: gstack:ship                    # 슬래시 커맨드명 (prefix 포함)
description: "Ship workflow: ..."    # 자동완성에 표시되는 설명
---

<!-- 커맨드 본문: SKILL.md 내용을 그대로 복사하거나 참조 -->
```

- frontmatter의 `name`과 `description`만 커맨드 등록에 사용
- 본문은 커맨드 실행 시 Claude에게 전달되는 프롬프트
- SKILL.md와 동일한 내용을 넣되, 동기화 관리가 필요 (sync script 등)

---

## 7. 로컬 플러그인 개발: 마켓플레이스 없이 테스트하기

### 배경

플러그인 변경할 때마다 push → 세션 재시작을 반복하면 느리다.
로컬 디렉토리를 마켓플레이스로 등록하면 push 없이 바로 테스트 가능.

### 방법: 로컬 마켓플레이스 등록

Claude Code에는 "로컬 플러그인" 개념이 없다. 대신 **로컬 디렉토리를 마켓플레이스로 등록**한다.

```bash
# 로컬 마켓플레이스 추가
/plugin marketplace add ./path/to/marketplace

# 플러그인 설치
/plugin install my-plugin@my-marketplace
```

### 마켓플레이스 디렉토리 구조

```
my-marketplace/
├── .claude-plugin/
│   └── marketplace.json
└── plugins/
    └── my-plugin/
        ├── .claude-plugin/
        │   └── plugin.json
        ├── commands/
        └── <skill-dirs>/
```

### marketplace.json 예시

```json
{
  "name": "my-dev-marketplace",
  "owner": { "name": "Your Name" },
  "plugins": [
    {
      "name": "gstack",
      "source": "./plugins/gstack",
      "description": "gstack development build"
    }
  ]
}
```

### 변경 반영 명령

```bash
/plugin marketplace update my-dev-marketplace   # 마켓플레이스 갱신
/reload-plugins                                  # 플러그인 리로드
```

### 현재 gstack 워크플로우

gstack은 `jerry-claude-kit` GitHub 마켓플레이스에 등록되어 있고 `autoUpdate: true`이므로:

```
수정 → git push → Claude Code 세션 재시작 → 자동 업데이트 반영
```

로컬 마켓플레이스를 쓰면 push 단계를 생략할 수 있지만, 현재 워크플로우도 충분히 빠르다.

---

## 요약: 플러그인 체크리스트

- [ ] `.claude-plugin/plugin.json` 존재하는가?
- [ ] `author` 필드가 객체 형식인가?
- [ ] `commands/` 디렉토리에 커맨드 파일이 있는가?
- [ ] 커맨드 `name`에 플러그인 prefix (`gstack:`)가 있는가?
- [ ] 각 커맨드에 대응하는 SKILL.md가 있는가? (자동 트리거용)
- [ ] 변경 후 Claude Code를 재시작했는가?
