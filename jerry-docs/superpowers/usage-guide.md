---
title: gstack Plugin 사용 가이드 & 유의사항
date: 2026-03-24
status: Active
---

# gstack Plugin 사용 가이드 & 유의사항

## TL;DR

- `/gstack:스킬명`으로 28개 스킬 호출 가능
- 커스텀은 `commands/*.md`의 CUSTOM 영역에서만
- LaunchAgent가 6시간마다 자동 동기화
- 원본 SKILL.md는 절대 수정 금지

---

## 1. 커맨드 사용법

Claude Code에서 슬래시 커맨드로 호출:

```
/gstack:qa              # 웹앱 QA 테스트 + 버그 자동 수정
/gstack:ship            # 테스트 → 리뷰 → VERSION 범프 → PR
/gstack:office-hours    # YC 오피스아워 브레인스토밍
/gstack:review          # PR diff 분석
/gstack:cso             # OWASP Top 10 + STRIDE 보안 감사
/gstack:investigate     # 체계적 디버깅 (root cause 분석)
/gstack:browse          # 헤드리스 브라우저 (~100ms/명령)
/gstack:retro           # 주간 엔지니어링 회고
```

전체 28개 목록은 `jerry-docs/superpowers/specs/2026-03-24-gstack-plugin-wrapper-design.md` 섹션 4 참고.

---

## 2. 자동 동기화 (LaunchAgent)

### 동작 방식

- **주기**: 6시간마다 + 로그인 시 즉시 1회
- **경로**: `~/Library/LaunchAgents/com.jerry.gstack-sync.plist`
- **로그**: `~/.gstack/sync.log`

### 동기화 플로우

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

### LaunchAgent 관리 명령

```bash
# 상태 확인
launchctl list | grep gstack

# 로그 확인
tail -30 ~/.gstack/sync.log

# 즉시 실행 (테스트용)
launchctl start com.jerry.gstack-sync

# 해제
launchctl unload ~/Library/LaunchAgents/com.jerry.gstack-sync.plist

# 재등록
launchctl load ~/Library/LaunchAgents/com.jerry.gstack-sync.plist
```

---

## 3. 수동 업데이트

급히 최신 upstream을 반영해야 할 때:

```bash
cd ~/Projects/gstack-plugin
git fetch upstream
git merge upstream/main
bash bin/sync-commands.sh
```

browse 데몬도 변경됐을 경우:

```bash
./setup
```

---

## 4. 커스텀 수정 규칙

### 반드시 지킬 것

| 규칙 | 이유 |
|:-----|:-----|
| **원본 SKILL.md 수정 금지** | upstream merge 시 충돌 발생. 모든 커스텀은 commands/ CUSTOM 영역에서 |
| **SYNCED 영역 수동 편집 금지** | `sync-commands.sh`가 덮어씀. 다음 sync 시 수정 내용 사라짐 |
| **plugin.json의 name 변경 금지** | `gstack`이어야 `/gstack:` prefix로 인식됨 |

### 커스텀 방법

`commands/*.md` 파일의 CUSTOM 영역에서 수정:

```markdown
<!-- ===== CUSTOM OVERRIDES — 자유롭게 수정 ===== -->
## 추가 지침 (커스텀)
- 모든 리포트는 한글로 작성
- 테스트 완료 후 Slack #qa-alerts 채널에 요약 전송
<!-- ===== END CUSTOM ===== -->
```

이 영역은 `sync-commands.sh` 실행 시에도 보존됨.

### 나만의 커맨드 추가

upstream에 없는 워크플로우는 `commands/` 에 새 파일 생성:

```markdown
<!-- commands/my-workflow.md -->
---
name: my-workflow
description: "내 프로젝트 전용 워크플로우"
---

## 나만의 워크플로우
1. /gstack:plan-ceo-review 실행
2. 승인 후 /gstack:qa 실행
3. /gstack:ship으로 배포
```

---

## 5. gstack 개발 플로우 가이드

### 5.1 전체 파이프라인 개요

gstack은 소프트웨어 개발의 전 단계를 역할 기반 스킬로 커버한다. "Boil the Lake" 철학 — 빠짐없이 전부 하자.

```
아이디어 → 기획 리뷰 → 설계 → 구현 → 코드 리뷰 → QA → 배포 → 모니터링 → 회고
```

각 단계에 대응하는 스킬:

| 단계 | 스킬 | 역할 |
|:-----|:-----|:-----|
| 아이디어 검증 | `/gstack:office-hours` | YC 스타일 6가지 강제 질문으로 아이디어 다듬기 |
| 전략 리뷰 | `/gstack:plan-ceo-review` | CEO 관점 — 10x 비전, 범위 확대/축소 판단 |
| 기술 리뷰 | `/gstack:plan-eng-review` | 엔지니어링 매니저 — 아키텍처/데이터 플로우/테스트 |
| 디자인 리뷰 | `/gstack:plan-design-review` | 디자이너 — UI/UX 0-10점 평가 |
| 자동 리뷰 | `/gstack:autoplan` | 위 3단계를 자동 순차 실행 |
| 디자인 시스템 | `/gstack:design-consultation` | DESIGN.md 생성 (색상/타이포/레이아웃) |
| 디버깅 | `/gstack:investigate` | 근본 원인 없이 수정 없음. 4단계 체계적 분석 |
| 코드 리뷰 | `/gstack:review` | PR diff 분석 (SQL 안전성, LLM 경계 등) |
| QA | `/gstack:qa` | 웹앱 테스트 + 버그 자동 수정 |
| QA (보고만) | `/gstack:qa-only` | 리포트만 생성, 코드 수정 없음 |
| 2차 의견 | `/gstack:codex` | OpenAI Codex CLI로 독립 검증 |
| 배포 준비 | `/gstack:ship` | 테스트 → 리뷰 → VERSION → CHANGELOG → PR |
| 배포 실행 | `/gstack:land-and-deploy` | PR 머지 → CI → 프로덕션 헬스 체크 |
| 배포 모니터링 | `/gstack:canary` | 스크린샷 비교 + 콘솔 에러 감시 |
| 성능 측정 | `/gstack:benchmark` | Core Web Vitals, 번들 사이즈 회귀 감지 |
| 보안 감사 | `/gstack:cso` | OWASP Top 10, STRIDE, 공급망 감사 |
| 문서 업데이트 | `/gstack:document-release` | 배포 후 README/ARCHITECTURE 동기화 |
| 회고 | `/gstack:retro` | 주간 커밋 분석 + 팀 기여도 + 트렌드 |

---

### 5.2 사례별 플로우

#### Case 1: 새 기능 개발 (가장 일반적)

> "사용자 프로필 페이지에 다크 모드를 추가해야 해"

```
1. /gstack:office-hours     ← 기능 범위 정의. "정말 필요한가?" 검증
   └─ 산출물: 디자인 문서 초안

2. /gstack:autoplan          ← CEO+엔지니어링+디자인 3단계 자동 리뷰
   또는 개별 실행:
   ├── /gstack:plan-ceo-review      ← 범위 적절한가?
   ├── /gstack:plan-eng-review      ← 아키텍처 문제 없나?
   └── /gstack:plan-design-review   ← UI/UX 빠진 부분?

3. (구현) ← 직접 코딩

4. /gstack:review            ← PR diff 분석
5. /gstack:qa                ← 브라우저로 실제 테스트 + 버그 자동 수정
6. /gstack:ship              ← VERSION 범프 → CHANGELOG → PR 생성
7. /gstack:land-and-deploy   ← 머지 → CI → 프로덕션 배포
8. /gstack:canary            ← 배포 후 모니터링 (스크린샷 비교)
```

**핵심**: 기획(1-2) → 구현(3) → 검증(4-5) → 배포(6-8) 순서를 지킨다.

---

#### Case 2: 새 프로젝트 시작

> "새로운 SaaS 대시보드 프로젝트를 시작하려고 해"

```
1. /gstack:office-hours         ← "무엇을 만들 것인가?" 정의
   └─ 스타트업 모드: 6가지 강제 질문
      · 수요 현실성 / 현 상황 / 구체적 필요
      · 좁은 쐐기 / 관찰 / 미래 적합성

2. /gstack:autoplan             ← 전략+기술+디자인 리뷰 한번에

3. /gstack:design-consultation  ← 디자인 시스템 생성
   └─ 산출물: DESIGN.md (미학/타이포/색상/레이아웃/모션)

4. /gstack:setup-deploy         ← 배포 플랫폼 자동 감지 + CLAUDE.md 설정
   └─ Fly.io / Render / Vercel / Netlify 등 자동 인식

5. (프로젝트 초기 구현)

6. /gstack:cso                  ← 초기 보안 감사 (시크릿/공급망/CI)
7. /gstack:benchmark            ← 성능 기준선 수립
```

**핵심**: `office-hours`로 방향 → `design-consultation`으로 비주얼 토대 → `setup-deploy`로 인프라 토대.

---

#### Case 3: 버그 수정

> "로그인 후 세션이 5분 만에 끊겨요"

```
1. /gstack:investigate      ← 체계적 4단계 디버깅
   ├── 조사: 재현 환경 확인, 로그 수집
   ├── 분석: 관련 코드 추적, 데이터 플로우 매핑
   ├── 가설: 원인 후보 나열 + 검증
   └── 구현: 근본 원인 확인 후에만 수정
   ⚠️ 원칙: "근본 원인 없이 수정 없음"

2. /gstack:review           ← 수정 PR의 코드 리뷰
3. /gstack:qa               ← 수정 후 회귀 테스트
4. /gstack:ship             ← 핫픽스 PR 생성
5. /gstack:land-and-deploy  ← 빠른 배포
6. /gstack:canary           ← 배포 후 세션 유지 확인
```

**핵심**: `investigate`가 근본 원인을 찾은 후에만 코드를 수정한다.

---

#### Case 4: PR 코드 리뷰 (리뷰어 역할)

> "동료가 올린 PR을 리뷰해줘"

```
1. /gstack:review           ← PR diff 자동 분석
   └─ 검토 항목:
      · SQL 안전성 (인젝션, N+1)
      · LLM 신뢰 경계 (프롬프트 인젝션 가능성)
      · 조건부 부작용 (side effects)
      · 구조적 문제 (중복, 결합도)

2. /gstack:codex            ← (선택) 독립적 2차 의견
   └─ 3가지 모드:
      · Review: Codex가 독립적으로 검토 (통과/불통)
      · Challenge: 적대적으로 코드 깨뜨리기 시도
      · Consult: 특정 부분에 대해 질문
```

**핵심**: `/review`로 자동 분석 + 필요시 `/codex`로 독립 검증.

---

#### Case 5: 배포 + 릴리스

> "개발 끝났어, 배포하자"

```
1. /gstack:ship              ← 배포 준비 자동화
   ├── 기본 브랜치 자동 감지 (main/master)
   ├── 테스트 실행
   ├── diff 리뷰
   ├── VERSION 파일 범프
   ├── CHANGELOG.md 업데이트
   ├── 커밋 + 푸시
   └── PR 생성

2. /gstack:land-and-deploy   ← 병합 + 배포
   ├── PR 머지
   ├── CI 파이프라인 완료 대기
   └── 프로덕션 헬스 체크

3. /gstack:canary            ← 배포 후 모니터링
   ├── 배포 전 기준선 스크린샷 캡처
   ├── 주기적 비교 (콘솔 에러, 성능 저하, 페이지 깨짐)
   └── 이상 감지 시 알림

4. /gstack:document-release  ← 문서 동기화
   └── README / ARCHITECTURE / CONTRIBUTING / CLAUDE.md 업데이트
```

**핵심**: `ship` → `land-and-deploy` → `canary` → `document-release`는 순차 필수.

---

#### Case 6: 보안 감사

> "출시 전에 보안 점검을 하고 싶어"

```
1. /gstack:cso               ← 보안 감사 (2가지 모드)
   ├── Daily 모드: 빠른 스캔, 신뢰도 8/10 이상만 보고
   └── Comprehensive 모드: 심층 스캔, 신뢰도 2/10부터 보고
       ├── 시크릿 고고학 (git 이력 속 API 키, 토큰)
       ├── 공급망 보안 (npm audit, 의존성 취약점)
       ├── CI/CD 보안 (GitHub Actions 권한)
       ├── LLM/AI 보안 (프롬프트 인젝션 경로)
       ├── OWASP Top 10
       └── STRIDE 위협 모델링

2. /gstack:review            ← 보안 수정 PR 리뷰
3. /gstack:qa                ← 수정 후 기능 회귀 테스트
```

**핵심**: 출시 전 Comprehensive, 일상적으로 Daily 모드 사용.

---

#### Case 7: 디자인 개선 / 비주얼 QA

> "UI가 좀 구린데 개선하고 싶어"

```
1. /gstack:design-review     ← 라이브 사이트 비주얼 QA
   ├── 시각적 일관성 체크
   ├── 스페이싱 / 계층 구조 / 정렬
   ├── AI 생성물 오류 감지 (Lorem ipsum 등)
   ├── 느린 상호작용 감지
   ├── 반복적 수정 + 자동 커밋
   └── before/after 스크린샷 비교

2. /gstack:benchmark         ← 디자인 변경으로 인한 성능 영향 확인
```

**디자인 시스템이 없다면** 먼저:
```
0. /gstack:design-consultation  ← DESIGN.md 생성 (미학/색상/레이아웃)
```

---

#### Case 8: 성능 최적화

> "페이지 로딩이 느려졌어"

```
1. /gstack:benchmark         ← 현재 성능 기준선 측정
   └── Core Web Vitals / 번들 사이즈 / 로딩 시간

2. /gstack:investigate       ← 성능 병목 근본 원인 분석

3. (최적화 구현)

4. /gstack:benchmark         ← 개선 효과 측정 (before vs after)
5. /gstack:qa                ← 최적화가 기능을 깨뜨리지 않았는지 확인
6. /gstack:ship              ← PR 생성
```

**핵심**: `benchmark` → `investigate` → 구현 → `benchmark` 비교.

---

#### Case 9: 주간 팀 회고

> "이번 주 뭘 했는지 정리하자"

```
/gstack:retro               ← 주간 엔지니어링 회고
├── 커밋 이력 분석
├── 팀 기여도 분석 (개인별)
├── 코드 품질 메트릭
├── 트렌드 추적 (주간 비교)
└── 산출물: 주간 보고서
```

---

#### Case 10: 리서치 / 기술 탐색

> "새 인증 방식을 도입하려는데 어떤 게 좋을지 모르겠어"

```
1. /gstack:office-hours      ← 빌더 모드로 문제 정의
   └─ "정확히 무엇이 필요한가?" 정리

2. /gstack:plan-eng-review   ← 기술 옵션 비교
   └─ 아키텍처 옵션 나열 → 의견 기반 권고
       · OAuth2 vs Passkey vs Magic Link 등

3. /gstack:codex             ← Consult 모드로 2차 의견
   └─ "Codex야, OAuth2 vs Passkey 중 뭐가 나을까?"
```

**핵심**: `office-hours`로 문제 정의 → `plan-eng-review`로 기술 분석 → `codex`로 검증.

---

### 5.3 안전 가드레일

위험한 작업 시 자동으로 보호해주는 스킬:

| 스킬 | 동작 | 사용 시나리오 |
|:-----|:-----|:-------------|
| `/gstack:careful` | `rm -rf`, `DROP TABLE` 등 파괴적 명령 감지 경고 | 항상 활성화 권장 |
| `/gstack:freeze` | 지정 디렉토리 외 편집 차단 | 프로덕션 코드 보호 |
| `/gstack:guard` | careful + freeze 결합 | 최대 안전 모드 |
| `/gstack:unfreeze` | freeze 해제 | freeze 풀 때 |

---

### 5.4 플로우 선택 가이드 (빠른 참조)

| 상황 | 추천 플로우 |
|:-----|:-----------|
| "뭘 만들지 정해야 해" | `office-hours` → `autoplan` |
| "코드 짰는데 리뷰해줘" | `review` → (선택) `codex` |
| "버그 고쳐야 해" | `investigate` → 수정 → `qa` → `ship` |
| "배포하자" | `ship` → `land-and-deploy` → `canary` |
| "보안 점검" | `cso` (Daily 또는 Comprehensive) |
| "디자인 개선" | `design-review` (시스템 없으면 `design-consultation` 먼저) |
| "성능 느려졌어" | `benchmark` → `investigate` → 수정 → `benchmark` |
| "이번 주 회고" | `retro` |
| "새 프로젝트 시작" | `office-hours` → `autoplan` → `design-consultation` → `setup-deploy` |
| "기술 리서치" | `office-hours` → `plan-eng-review` → `codex` (Consult) |

---

## 6. 유의사항

### merge conflict 발생 시

LaunchAgent가 자동으로 `git merge --abort` 처리함. 수동으로 해결 필요:

```bash
cd ~/Projects/gstack-plugin
git fetch upstream
git merge upstream/main
# 충돌 파일 수동 해결
git add .
git commit
bash bin/sync-commands.sh
```

### browse 데몬이 안 될 때

```bash
cd ~/Projects/gstack-plugin
bun install
./setup
```

### symlink 깨짐

프로젝트 경로를 옮겼다면 재설정:

```bash
ln -sf /Users/jerry/Projects/gstack-plugin ~/.claude/plugins/gstack-plugin
```

### 플러그인이 로드 안 될 때

Claude Code 플러그인은 특정 구조와 등록 방식을 따라야 인식된다.

**증상:** `/gstack:qa` 등 커맨드가 스킬 목록에 나타나지 않음

**원인 1: `plugin.json` 위치가 잘못됨**
- `plugin.json`은 루트가 아닌 **`.claude-plugin/plugin.json`**에 있어야 함
- 실제 작동하는 플러그인 구조:
  ```
  my-plugin/
  ├── .claude-plugin/
  │   └── plugin.json       ← 여기!
  ├── commands/
  │   └── cmd.md
  └── skills/
      └── skill-name/
          └── SKILL.md
  ```

**원인 2: symlink만으로는 인식 안 됨**
- `~/.claude/plugins/`에 symlink를 걸어도 Claude Code가 자동 인식하지 않음
- `installed_plugins.json` 수동 수정도 작동하지 않음

**해결 방법:**

방법 A — `--plugin-dir` 플래그 (즉시 테스트용):
```bash
claude --plugin-dir /Users/jerry/Projects/gstack-plugin
```

방법 B — shell alias (영구적):
```bash
# ~/.zshrc에 추가
alias claude='claude --plugin-dir /Users/jerry/Projects/gstack-plugin'
```

방법 C — 마켓플레이스 등록 (정석):
```bash
# jerry-claude-kit 또는 별도 마켓플레이스에 추가
# /plugin marketplace add → /plugin install gstack@marketplace
```

**검증:**
```bash
claude --plugin-dir /Users/jerry/Projects/gstack-plugin -p "List gstack commands" --output-format text
```

### SSH push 안 될 때

현재 HTTPS remote 사용 중. SSH 키 등록 후 전환하려면:

```bash
git remote set-url origin git@github.com:yoyojyv/gstack.git
```

---

## 7. 업데이트 채널 정리

| 채널 | 트리거 | 용도 |
|:-----|:-------|:-----|
| **LaunchAgent** | 6시간마다 자동 | 메인 — 항상 최신 유지 |
| **수동 명령** | `git fetch upstream && git merge upstream/main` | 급할 때 |
| **`/gstack:gstack-upgrade`** | 커맨드 호출 | gstack 내장 업그레이드 (글로벌 설치용) |

---

| 버전 | 날짜 | 변경 내용 |
|:-----|:-----|:----------|
| v1.0.0 | 2026-03-24 | 초기 작성 |
| v1.1.0 | 2026-03-24 | 개발 플로우 가이드 + 10가지 사례별 플로우 추가 |
| v1.2.0 | 2026-03-24 | 플러그인 레지스트리 등록 트러블슈팅 추가 |
