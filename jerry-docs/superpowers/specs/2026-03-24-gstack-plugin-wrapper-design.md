# gstack Claude Code Plugin Wrapper — 설계 문서

> **날짜**: 2026-03-24
> **상태**: Draft
> **접근 방식**: Fork + plugin.json (C안)

---

## 1. 목적

Garry Tan의 [gstack](https://github.com/garrytan/gstack) (v0.11.9.0)을 Claude Code Plugin으로 래핑하여:

1. **`gstack:` prefix**로 모든 스킬에 접근 (예: `/gstack:qa`, `/gstack:ship`)
2. **upstream 동기화**: `git merge upstream/main` 한 줄로 최신 반영
3. **커스텀 수정**: 내 fork에서 자유롭게 수정, upstream과 독립 관리
4. **네임스페이스 격리**: 기존 프로젝트 스킬과 충돌 없음

---

## 2. 아키텍처

### 2.1 디렉토리 구조

**프로젝트 + symlink 분리 구조:**

```
/Users/jerry/Projects/gstack-plugin/   ← 실제 git repo (fork)
├── plugin.json                         ← 추가 (upstream에 없음, 충돌 없음)
├── commands/                           ← 추가: 28개 슬래시 커맨드 래퍼 (Override 레이어)
│   ├── office-hours.md
│   ├── plan-ceo-review.md
│   ├── qa.md
│   ├── ship.md
│   └── ... (28개)
├── bin/
│   └── sync-commands.sh                ← 추가: upstream→commands/ 동기화 스크립트
├── SKILL.md                            ← gstack 원본 (메인 라우터)
├── autoplan/SKILL.md                   ← gstack 원본 (수정 금지)
├── benchmark/SKILL.md
├── browse/
│   ├── SKILL.md
│   └── src/                            ← browse 데몬 소스
├── canary/SKILL.md
├── careful/SKILL.md
├── codex/SKILL.md
├── cso/SKILL.md
├── design-consultation/SKILL.md
├── design-review/SKILL.md
├── document-release/SKILL.md
├── freeze/SKILL.md
├── gstack-upgrade/SKILL.md
├── guard/SKILL.md
├── investigate/SKILL.md
├── land-and-deploy/SKILL.md
├── office-hours/SKILL.md
├── plan-ceo-review/SKILL.md
├── plan-design-review/SKILL.md
├── plan-eng-review/SKILL.md
├── qa/SKILL.md
├── qa-only/SKILL.md
├── retro/SKILL.md
├── review/SKILL.md
├── setup-browser-cookies/SKILL.md
├── setup-deploy/SKILL.md
├── ship/SKILL.md
├── unfreeze/SKILL.md
├── README.md                           ← gstack 원본
├── CLAUDE.md                           ← gstack 원본
├── ARCHITECTURE.md                     ← gstack 원본
└── .git/

~/.claude/plugins/gstack-plugin → /Users/jerry/Projects/gstack-plugin  ← symlink
```

이 구조에서:
- **프로젝트 관리**: `/Users/jerry/Projects/gstack-plugin/`에서 git 작업, 커스텀 수정
- **플러그인 등록**: symlink만 걸면 Claude Code가 자동 인식
- **원본 SKILL.md**: 수정 금지 → upstream merge 충돌 없음
- **커스텀**: commands/ 래퍼의 CUSTOM 영역에서만 처리

### 2.2 핵심 원칙

- **추가만, 수정 최소화**: upstream 파일은 가능한 한 그대로 유지
- **plugin.json + commands/**: 이 2개만 내가 추가하는 파일
- **upstream에 없는 파일 = 충돌 없음**: merge 시 안전

---

## 3. plugin.json 설계

```json
{
  "name": "gstack",
  "description": "Garry Tan's gstack — 28 opinionated tools that serve as CEO, Designer, Eng Manager, Release Manager, Doc Engineer, QA, and Security Officer for Claude Code",
  "version": "0.11.9.0",
  "author": "garrytan (wrapped by jerry)"
}
```

- `version`: gstack upstream 버전과 동기화
- commands/와 skills/는 auto-discovery로 자동 감지

---

## 4. 커맨드 매핑 (28개)

각 커맨드는 `commands/` 디렉토리의 .md 파일로, 해당 gstack SKILL.md의 내용을 로드하는 얇은 래퍼.

### 4.1 기획/브레인스토밍 (4개)

| 커맨드 | 원본 스킬 | 설명 |
|:-------|:----------|:-----|
| `/gstack:office-hours` | `office-hours/SKILL.md` | YC 오피스아워 — 스타트업/빌더 모드 브레인스토밍 |
| `/gstack:plan-ceo-review` | `plan-ceo-review/SKILL.md` | CEO 모드 플랜 리뷰 — 10x 비전, 범위 4모드 |
| `/gstack:plan-eng-review` | `plan-eng-review/SKILL.md` | 엔지니어링 매니저 모드 — 아키텍처/테스트 리뷰 |
| `/gstack:plan-design-review` | `plan-design-review/SKILL.md` | 디자이너 눈 플랜 리뷰 — 0-10 점수 |

### 4.2 디자인 (2개)

| 커맨드 | 원본 스킬 | 설명 |
|:-------|:----------|:-----|
| `/gstack:design-consultation` | `design-consultation/SKILL.md` | 디자인 시스템 생성 (DESIGN.md) |
| `/gstack:design-review` | `design-review/SKILL.md` | 라이브 사이트 비주얼 QA + 자동 수정 |

### 4.3 자동 리뷰 (2개)

| 커맨드 | 원본 스킬 | 설명 |
|:-------|:----------|:-----|
| `/gstack:autoplan` | `autoplan/SKILL.md` | CEO+디자인+엔지니어링 리뷰 자동 순차 실행 |
| `/gstack:codex` | `codex/SKILL.md` | OpenAI Codex CLI — 리뷰/챌린지/컨설트 |

### 4.4 코드 리뷰 & 배포 (5개)

| 커맨드 | 원본 스킬 | 설명 |
|:-------|:----------|:-----|
| `/gstack:review` | `review/SKILL.md` | PR diff 분석 (SQL 안전성, LLM 신뢰 경계) |
| `/gstack:ship` | `ship/SKILL.md` | 테스트→리뷰→버전 범프→CHANGELOG→PR |
| `/gstack:land-and-deploy` | `land-and-deploy/SKILL.md` | PR 머지→CI→프로덕션 헬스 체크 |
| `/gstack:document-release` | `document-release/SKILL.md` | 배포 후 문서 업데이트 |
| `/gstack:setup-deploy` | `setup-deploy/SKILL.md` | 배포 플랫폼 자동 감지 + 설정 |

### 4.5 QA/테스트 (4개)

| 커맨드 | 원본 스킬 | 설명 |
|:-------|:----------|:-----|
| `/gstack:qa` | `qa/SKILL.md` | 웹앱 QA 테스트 + 버그 자동 수정 |
| `/gstack:qa-only` | `qa-only/SKILL.md` | 리포트만 생성 (수정 없음) |
| `/gstack:benchmark` | `benchmark/SKILL.md` | 성능 회귀 감지 (Core Web Vitals) |
| `/gstack:canary` | `canary/SKILL.md` | 배포 후 카나리 모니터링 |

### 4.6 브라우저 (3개)

| 커맨드 | 원본 스킬 | 설명 |
|:-------|:----------|:-----|
| `/gstack:browse` | `browse/SKILL.md` | 헤드리스 브라우저 (~100ms/명령) |
| `/gstack:gstack` | `SKILL.md` | 메인 라우터 + 브라우저 + 스킬 제안 |
| `/gstack:setup-browser-cookies` | `setup-browser-cookies/SKILL.md` | 실제 브라우저 쿠키 임포트 |

### 4.7 디버깅 & 보안 (3개)

| 커맨드 | 원본 스킬 | 설명 |
|:-------|:----------|:-----|
| `/gstack:investigate` | `investigate/SKILL.md` | 체계적 디버깅 (조사→분석→가설→구현) |
| `/gstack:cso` | `cso/SKILL.md` | CSO 모드 — OWASP Top 10, STRIDE, 공급망 감사 |
| `/gstack:retro` | `retro/SKILL.md` | 주간 엔지니어링 회고 + 트렌드 추적 |

### 4.8 안전 가드레일 (4개)

| 커맨드 | 원본 스킬 | 설명 |
|:-------|:----------|:-----|
| `/gstack:careful` | `careful/SKILL.md` | 파괴적 명령 경고 (rm -rf, DROP TABLE 등) |
| `/gstack:freeze` | `freeze/SKILL.md` | 특정 디렉토리만 편집 허용 |
| `/gstack:unfreeze` | `unfreeze/SKILL.md` | freeze 해제 |
| `/gstack:guard` | `guard/SKILL.md` | careful + freeze 결합 (최대 안전 모드) |

### 4.9 유틸리티 (1개)

| 커맨드 | 원본 스킬 | 설명 |
|:-------|:----------|:-----|
| `/gstack:gstack-upgrade` | `gstack-upgrade/SKILL.md` | gstack 자체 업그레이드 |

---

## 5. 커맨드 래퍼 파일 구조 (Override 레이어)

### 5.1 핵심 원칙

- **원본 SKILL.md는 절대 수정하지 않는다** → upstream merge 충돌 0
- 커스텀은 `commands/` 래퍼 레이어에서만 처리
- 원본 내용은 `bin/sync-commands.sh` 스크립트가 자동 복사

### 5.2 커맨드 파일 구조

```markdown
---
name: qa
description: "gstack QA — 웹앱 테스트 + 버그 자동 수정"
---

<!-- ===== SYNCED FROM qa/SKILL.md — DO NOT EDIT BELOW ===== -->
(bin/sync-commands.sh가 원본 SKILL.md 내용을 여기에 자동 삽입)
<!-- ===== END SYNCED CONTENT ===== -->

<!-- ===== CUSTOM OVERRIDES — 자유롭게 수정 ===== -->
(사용자 커스텀 지침. 이 영역은 sync 시에도 보존됨)
<!-- ===== END CUSTOM ===== -->
```

### 5.3 sync-commands.sh 동작

```bash
#!/bin/bash
# bin/sync-commands.sh — upstream 업데이트 후 commands/ 자동 동기화
#
# 동작:
# 1. 각 스킬 디렉토리의 SKILL.md에서 frontmatter 이후 본문 추출
# 2. commands/*.md의 SYNCED 영역만 교체
# 3. CUSTOM 영역은 그대로 보존
# 4. 새 스킬이 추가되었으면 commands/ 파일 자동 생성

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
COMMANDS_DIR="$PLUGIN_ROOT/commands"

# 매핑: 스킬 디렉토리 → 커맨드 파일명
SKILLS=(
  "autoplan" "benchmark" "browse" "canary" "careful"
  "codex" "cso" "design-consultation" "design-review"
  "document-release" "freeze" "gstack-upgrade" "guard"
  "investigate" "land-and-deploy" "office-hours"
  "plan-ceo-review" "plan-design-review" "plan-eng-review"
  "qa" "qa-only" "retro" "review"
  "setup-browser-cookies" "setup-deploy" "ship" "unfreeze"
)

for skill in "${SKILLS[@]}"; do
  SKILL_FILE="$PLUGIN_ROOT/$skill/SKILL.md"
  CMD_FILE="$COMMANDS_DIR/$skill.md"
  # ... SYNCED 마커 사이 내용만 교체, CUSTOM 보존
done

# 메인 라우터 (SKILL.md → commands/gstack.md)
# ... 동일 로직
```

### 5.4 커스텀 수정 예시

**예: QA 리포트를 한글로 출력 + Slack 알림 추가**

`commands/qa.md`의 CUSTOM 영역:

```markdown
<!-- ===== CUSTOM OVERRIDES ===== -->
## 추가 지침 (커스텀)
- 모든 리포트는 한글로 작성
- 테스트 완료 후 결과를 `#qa-alerts` Slack 채널에 요약 전송
- health score가 70 미만이면 경고 이모지 추가
<!-- ===== END CUSTOM ===== -->
```

### 5.5 새 커맨드 추가

upstream에 없는 나만의 커맨드:

```markdown
<!-- commands/my-workflow.md -->
---
name: my-workflow
description: "내 프로젝트 전용 워크플로우"
---

## 나만의 워크플로우
1. /gstack:plan-ceo-review 실행
2. 승인 후 /gstack:plan-eng-review 실행
3. 구현 후 /gstack:qa + /gstack:review 실행
4. /gstack:ship으로 배포
```

---

## 6. 업데이트 전략

### 6.1 초기 설정

```bash
# 1. Fork
gh repo fork garrytan/gstack --clone=false

# 2. Clone
git clone git@github.com:yoyojyv/gstack.git /Users/jerry/Projects/gstack-plugin
cd /Users/jerry/Projects/gstack-plugin

# 3. Upstream 등록
git remote add upstream https://github.com/garrytan/gstack.git

# 4. plugin.json + commands/ + bin/sync-commands.sh 추가
# (초기 1회만)

# 5. Symlink 등록
ln -s /Users/jerry/Projects/gstack-plugin ~/.claude/plugins/gstack-plugin

# 6. 커맨드 초기 동기화
bash bin/sync-commands.sh

# 7. 빌드 (browse 데몬)
./setup

# 8. 커밋 & 푸시
git add plugin.json commands/ bin/sync-commands.sh
git commit -m "feat: add Claude Code plugin wrapper"
git push
```

### 6.2 Upstream 업데이트 (일상)

```bash
cd /Users/jerry/Projects/gstack-plugin
git fetch upstream
git merge upstream/main
# 원본 SKILL.md를 수정하지 않았으므로 충돌 없음!

# commands/ 동기화 (원본 변경분 반영, 커스텀 보존)
bash bin/sync-commands.sh
git add -A && git commit -m "sync: upstream update"
```

### 6.3 커스텀 수정 규칙

| 수정 대상 | 방법 | upstream 충돌 |
|:----------|:-----|:-------------|
| 스킬 동작 커스텀 | `commands/*.md`의 CUSTOM 영역 편집 | **없음** |
| 새 커맨드 추가 | `commands/my-xxx.md` 생성 | **없음** |
| plugin.json 수정 | 직접 편집 | **없음** (upstream에 없는 파일) |
| 원본 SKILL.md | **수정 금지** — 대신 CUSTOM 영역 사용 | — |

---

## 7. Hooks 처리

gstack의 일부 스킬은 hooks를 사용 (careful, freeze, guard):

| 스킬 | Hook | 동작 |
|:-----|:-----|:-----|
| `careful` | `PreToolUse:Bash` | 파괴적 명령 감지 경고 |
| `freeze` | `PreToolUse:Edit` | freeze 경계 외 편집 차단 |
| `guard` | 둘 다 | careful + freeze 결합 |

이 hooks는 SKILL.md에 정의되어 있으므로 스킬이 활성화되면 자동으로 적용됨.
Plugin-level hooks 별도 설정은 불필요.

---

## 8. 자동 업데이트 (macOS LaunchAgent)

### 8.1 배경: upstream 활동량

gstack은 매우 활발하게 개발 중 (2026-03-14 ~ 03-23 기준):

| 지표 | 값 |
|:-----|:---|
| 일 평균 커밋 | **10회** |
| 최근 10일 총 커밋 | 100+ |
| 버전 변화 | v0.9.0 → v0.11.9.0 (10일) |
| 커밋 간격 | 수 시간 단위 |

### 8.2 동기화 주기: 6시간

| 주기 | 판단 |
|:-----|:-----|
| 1시간 | 과함 — 네트워크 부담, 대부분 변경 없음 |
| **6시간** | **채택** — 하루 4회, 2~3개 변경 잡음 |
| 12시간 | 느림 — 이 활동량에선 뒤처질 수 있음 |
| 24시간 | 부적절 — 하루 10커밋 놓침 |

### 8.3 LaunchAgent 설정

**파일**: `~/Library/LaunchAgents/com.jerry.gstack-sync.plist`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.jerry.gstack-sync</string>

    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>-c</string>
        <string><![CDATA[
PLUGIN_DIR="$HOME/Projects/gstack-plugin"
LOG_DIR="$HOME/.gstack"
LOG_FILE="$LOG_DIR/sync.log"
mkdir -p "$LOG_DIR"

exec >> "$LOG_FILE" 2>&1
echo "--- $(date '+%Y-%m-%d %H:%M:%S') sync start ---"

cd "$PLUGIN_DIR" || { echo "PLUGIN_DIR not found"; exit 1; }

# 네트워크 체크
if ! curl -s --connect-timeout 5 https://github.com > /dev/null 2>&1; then
    echo "network unavailable, skipping"
    exit 0
fi

# upstream fetch + merge
git fetch upstream --quiet 2>&1
BEHIND=$(git rev-list HEAD..upstream/main --count 2>/dev/null || echo 0)

if [ "$BEHIND" -gt 0 ]; then
    echo "upstream ahead by $BEHIND commits, merging..."
    if git merge upstream/main --no-edit --quiet 2>&1; then
        echo "merge success"
        # commands/ 동기화 (SYNCED 영역 갱신, CUSTOM 보존)
        bash bin/sync-commands.sh 2>&1 && echo "commands synced"
        # browse 데몬 재빌드 (변경 있을 때만)
        if git diff HEAD~1 --name-only | grep -q "^browse/"; then
            echo "browse changed, rebuilding..."
            ./setup 2>&1 || echo "setup failed (non-fatal)"
        fi
    else
        echo "merge conflict! manual resolve needed"
        git merge --abort 2>&1
    fi
else
    echo "already up to date"
fi

echo "--- sync done ---"
        ]]></string>
    </array>

    <key>StartInterval</key>
    <integer>21600</integer>  <!-- 6시간 = 21600초 -->

    <key>RunAtLoad</key>
    <true/>  <!-- 로그인 시 즉시 1회 실행 -->

    <key>StandardOutPath</key>
    <string>/tmp/gstack-sync-stdout.log</string>

    <key>StandardErrorPath</key>
    <string>/tmp/gstack-sync-stderr.log</string>
</dict>
</plist>
```

### 8.4 LaunchAgent 관리

```bash
# 등록 (최초 1회)
launchctl load ~/Library/LaunchAgents/com.jerry.gstack-sync.plist

# 즉시 실행 (테스트)
launchctl start com.jerry.gstack-sync

# 상태 확인
launchctl list | grep gstack

# 로그 확인
tail -30 ~/.gstack/sync.log

# 해제
launchctl unload ~/Library/LaunchAgents/com.jerry.gstack-sync.plist
```

### 8.5 동기화 동작 요약

```
6시간마다 실행
  ├── 네트워크 없음 → skip
  ├── upstream 변경 없음 → "already up to date"
  ├── upstream 변경 있음
  │   ├── merge 성공
  │   │   ├── bin/sync-commands.sh 실행 (commands/ SYNCED 영역 갱신)
  │   │   └── browse/ 변경 시 ./setup 재빌드
  │   └── merge conflict → abort + 로그 기록 (수동 resolve 필요)
  └── 로그 → ~/.gstack/sync.log
```

### 8.6 업데이트 채널 정리 (3중)

| 채널 | 트리거 | 용도 |
|:-----|:-------|:-----|
| **LaunchAgent** | 6시간마다 자동 | 메인 — 항상 최신 유지 |
| **Plugin SessionStart hook** | Claude Code 세션 시작 시 | 보조 — LaunchAgent 놓친 경우 보완 |
| **`/gstack:gstack-upgrade`** | 수동 호출 | 긴급 — 즉시 업데이트 필요 시 |

---

## 9. 의존성

| 의존성 | 용도 | 필수 |
|:-------|:-----|:-----|
| [Bun](https://bun.sh/) v1.0+ | browse 데몬 빌드/실행 | 브라우저 스킬 사용 시 |
| [Git](https://git-scm.com/) | fork 관리 | 필수 |
| [Claude Code](https://docs.anthropic.com/en/docs/claude-code) | 플러그인 호스트 | 필수 |
| [Playwright](https://playwright.dev/) | 헤드리스 브라우저 | browse/qa 스킬 사용 시 (setup이 설치) |

---

## 10. 제약 사항 및 리스크

| 항목 | 내용 | 대응 |
|:-----|:-----|:-----|
| Override 규칙 위반 시 충돌 | 원본 SKILL.md를 직접 수정하면 upstream merge 충돌 | **수정 금지 원칙 준수** — CUSTOM 영역만 사용 |
| browse 데몬 빌드 필요 | `./setup` 실행 필수 | LaunchAgent가 browse/ 변경 감지 시 자동 재빌드 |
| Codex/Gemini 호환 파일 | `.agents/skills/` 구조가 함께 존재 | Claude Code plugin으로 사용 시 무시됨 |
| gstack의 CLAUDE.md 가이드 | "gstack 섹션을 CLAUDE.md에 추가" 안내 | 플러그인이면 자동 감지되므로 불필요할 수 있음 |
| symlink 깨짐 | 프로젝트 경로 변경 시 symlink 무효화 | `ln -sf` 로 재설정 |
| **plugin.json 위치** | 루트가 아닌 `.claude-plugin/plugin.json`에 있어야 함 | `.claude-plugin/` 디렉토리 사용 |
| **플러그인 로딩** | symlink, installed_plugins.json 수동 수정 모두 안 먹힘 | `--plugin-dir` 플래그 또는 마켓플레이스 등록 |

---

## 11. 구현 단계 및 진행 상황

| # | 단계 | 상태 | 비고 |
|:--|:-----|:-----|:-----|
| 1 | GitHub에서 garrytan/gstack fork | **완료** | `gh repo fork garrytan/gstack --clone=false` → `yoyojyv/gstack` (public) |
| 2 | Fork clone | **완료** | `git clone https://github.com/yoyojyv/gstack.git /Users/jerry/Projects/gstack-plugin` |
| 3 | Upstream remote 등록 | **완료** | `git remote add upstream https://github.com/garrytan/gstack.git` |
| 4 | plugin.json 생성 | **완료** | name: gstack, version: 0.11.9.0 |
| 5 | bin/sync-commands.sh 생성 | **완료** | BSD awk 호환, SYNCED/CUSTOM 영역 분리 |
| 6 | commands/ 초기 동기화 | **완료** | 28개 커맨드 파일 자동 생성 |
| 7 | Symlink 등록 | **완료** | `ln -sf /Users/jerry/Projects/gstack-plugin ~/.claude/plugins/gstack-plugin` |
| 8 | `./setup` 실행 (browse 데몬 빌드) | **완료** | Bun 1.3.11, browse 61MB 바이너리 빌드 성공 |
| 9 | LaunchAgent 설정 | **완료** | `com.jerry.gstack-sync.plist` 등록, 첫 실행 성공 (upstream 1커밋 merge) |
| 10 | 동작 확인 | **완료** | plugin.json 유효, symlink 정상, commands 28개, sync 멱등성 확인 |
| 11 | 커밋 & 푸시 | **완료** | 내 fork에 반영 |

### 11.1 완료된 작업 상세

**2026-03-24 세션에서 수행:**

```bash
# Step 1: Fork
gh repo fork garrytan/gstack --clone=false
# → https://github.com/yoyojyv/gstack

# Step 2: Clone (SSH 불가하여 HTTPS 사용)
git clone https://github.com/yoyojyv/gstack.git /Users/jerry/Projects/gstack-plugin

# Step 3: Upstream
cd /Users/jerry/Projects/gstack-plugin
git remote add upstream https://github.com/garrytan/gstack.git

# Step 4: plugin.json 생성
# → /Users/jerry/Projects/gstack-plugin/plugin.json

# Step 5: sync-commands.sh 생성 + 실행 권한
chmod +x bin/sync-commands.sh

# Step 6: 커맨드 동기화
bash bin/sync-commands.sh
# → sync-commands: 28 created, 0 updated (custom preserved)
# → total commands: 28

# Step 7: Symlink
ln -sf /Users/jerry/Projects/gstack-plugin ~/.claude/plugins/gstack-plugin
```

### 11.2 Step 8-11 완료 상세 (2026-03-24 2차 세션)

```bash
# Step 8: browse 데몬 빌드
bun install              # 8 packages, 736ms
./setup                  # browse 61MB, find-browse 61MB, SKILL.md 28개 생성

# Step 9: LaunchAgent 등록
# ~/Library/LaunchAgents/com.jerry.gstack-sync.plist 생성
launchctl load ~/Library/LaunchAgents/com.jerry.gstack-sync.plist
# 첫 실행: upstream 1커밋 merge + commands sync 성공

# Step 10: 동작 확인
# plugin.json JSON 유효, symlink 정상, commands 28개, sync 멱등성 확인

# Step 11: 커밋 & 푸시
git add plugin.json commands/ bin/sync-commands.sh jerry-docs/
git commit -m "feat: add Claude Code plugin wrapper with 28 commands"
git push
```

### 11.3 참고: SSH 인증 이슈

clone 시 SSH(`git@github.com:`)가 `Permission denied (publickey)`로 실패하여 HTTPS로 전환.
push 시에도 HTTPS 사용하거나, SSH 키 등록 후 remote URL 전환 필요:

```bash
# SSH 키 등록 후 전환 시
git remote set-url origin git@github.com:yoyojyv/gstack.git
```
