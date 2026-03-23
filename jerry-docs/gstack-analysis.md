---
title: gstack 전체 분석
version: v0.11.9.0
repo: garrytan/gstack
license: MIT
date: 2026-03-24
---

# gstack 전체 분석

## TL;DR

- Garry Tan(YC CEO)이 만든 Claude Code 스킬 모음으로, 스타트업 전체 워크플로우를 28개 역할 기반 스킬로 자동화한다
- "Boil the Lake" 철학 — 기획부터 배포, QA, 보안 감사, 회고까지 빠짐없이 커버
- Bun + Playwright + 접근성 트리 기반 헤드리스 브라우저 데몬 모델
- 각 스킬이 명확한 역할과 허용 도구(allowed-tools)를 가져 권한이 구조적으로 분리됨
- MIT 라이선스, Claude Code / Codex / Gemini CLI 호환

---

## 1. 개요

**gstack**은 Y Combinator CEO **Garry Tan**이 만든 Claude Code 스킬 컬렉션이다. GitHub 리포지토리 `garrytan/gstack`에서 MIT 라이선스로 공개되어 있으며, 현재 버전은 **v0.11.9.0**이다.

스타트업 빌딩에 필요한 전체 파이프라인 — 아이디어 검증, 기획 리뷰, 디자인, 구현, 코드 리뷰, QA, 배포, 보안 감사, 회고 — 을 하나의 통합 스킬셋으로 제공한다.

---

## 2. 핵심 철학

### 역할 기반 분리 (Role-Based Separation)

각 스킬은 CEO, 엔지니어링 매니저, 디자이너, CSO 등 특정 역할의 관점에서 동작한다. 하나의 만능 프롬프트가 아니라, 역할별로 독립된 스킬이 각자의 전문 영역에 집중한다.

### 완전성 원칙 (Boil the Lake)

"호수를 끓여라" — 소프트웨어 개발 라이프사이클의 모든 단계를 빠짐없이 커버하겠다는 원칙. 기획(`office-hours`) → 리뷰(`autoplan`) → 구현 → QA(`qa`) → 배포(`ship`, `land-and-deploy`) → 모니터링(`canary`) → 회고(`retro`)까지 끊김 없는 체인을 형성한다.

### 구조화된 거버넌스 (Structured Governance)

- 각 스킬에 `allowed-tools`가 명시되어 권한 범위가 제한됨
- `careful`, `freeze`, `guard` 등 안전 가드레일 스킬이 파괴적 명령을 사전 차단
- Hook 시스템(`PreToolUse`)으로 도구 실행 전 검증

---

## 3. 기술 스택

| 구성 요소 | 역할 |
|:---|:---|
| **Bun** | 런타임 및 패키지 매니저. Node.js 대비 빠른 실행 속도 |
| **Playwright** | 헤드리스 브라우저 제어. QA, 디자인 리뷰, 스크린샷 비교 등에 사용 |
| **접근성 트리 (Accessibility Tree)** | DOM 대신 접근성 트리를 파싱하여 페이지 구조를 이해. 토큰 효율적 |
| **데몬 모델** | 브라우저를 백그라운드 데몬으로 유지하여 명령당 ~100ms 응답 달성 |

---

## 4. 28개 스킬 전체 목록

### 4.1 메인 라우터

| 스킬명 | 버전 | 설명 | Allowed Tools |
|:---|:---|:---|:---|
| `gstack` | v1.1.0 | 헤드리스 브라우저 + 다른 스킬 제안 허브 | Bash, Read, AskUserQuestion |

### 4.2 기획 / 브레인스토밍

| 스킬명 | 버전 | 설명 | Allowed Tools |
|:---|:---|:---|:---|
| `office-hours` | v2.0.0 | YC 오피스아워 — 스타트업 모드(6 forcing questions) / 빌더 모드 | Bash, Read, Grep, Glob, Write, Edit |
| `plan-ceo-review` | v1.0.0 | CEO/파운더 모드 — 10x 비전, 4 scope 모드 (EXPANSION / SELECTIVE / HOLD / REDUCTION). `office-hours`에서 이어받음 | Read, Grep, Glob, Bash, AskUserQuestion, WebSearch |
| `plan-eng-review` | v1.0.0 | 엔지니어링 매니저 모드 — 아키텍처, 데이터 플로우, 테스트 검토. `office-hours`에서 이어받음 | Read, Write, Grep, Glob, AskUserQuestion, Bash, WebSearch |
| `plan-design-review` | v2.0.0 | 디자이너 관점 플랜 리뷰 — 0-10 점수 평가 | Read, Edit, Grep, Glob, Bash, AskUserQuestion |

### 4.3 디자인

| 스킬명 | 버전 | 설명 | Allowed Tools |
|:---|:---|:---|:---|
| `design-consultation` | v1.0.0 | 디자인 시스템 생성, DESIGN.md 작성 | Bash, Read, Write, Edit, Glob, Grep, AskUserQuestion, WebSearch |
| `design-review` | v2.0.0 | 라이브 사이트 비주얼 QA + 자동 수정, before/after 스크린샷 | Bash, Read, Write, Edit, Glob, Grep, AskUserQuestion, WebSearch |

### 4.4 자동 리뷰

| 스킬명 | 버전 | 설명 | Allowed Tools |
|:---|:---|:---|:---|
| `autoplan` | v1.0.0 | CEO + 디자인 + 엔지니어링 리뷰 자동 순차 실행, 6 decision principles. `office-hours`에서 이어받음 | Bash, Read, Write, Edit, Glob, Grep |
| `codex` | v1.0.0 | OpenAI Codex CLI 래퍼 — 리뷰 / 챌린지 / 컨설트 3모드 | Bash, Read, Write, Glob, Grep, AskUserQuestion |

### 4.5 코드 리뷰 & 배포

| 스킬명 | 버전 | 설명 | Allowed Tools |
|:---|:---|:---|:---|
| `review` | v1.0.0 | PR diff 분석 — SQL 안전성, LLM 신뢰 경계, 조건부 side effects 검사 | Bash, Read, Edit, Write, Grep, Glob, Agent, AskUserQuestion, WebSearch |
| `ship` | v1.0.0 | 테스트 → 리뷰 → VERSION 범프 → CHANGELOG → 커밋 → PR 자동화 | Bash, Read, Write, Edit, Grep, Glob, Agent, AskUserQuestion, WebSearch |
| `land-and-deploy` | v1.0.0 | PR 머지 → CI 대기 → 프로덕션 헬스 체크 | Bash, Read, Write, Glob, AskUserQuestion |
| `document-release` | v1.0.0 | 배포 후 문서 업데이트 — README / ARCHITECTURE / CONTRIBUTING / CLAUDE.md | Bash, Read, Write, Edit, Grep, Glob, AskUserQuestion |
| `setup-deploy` | v1.0.0 | 배포 플랫폼 자동 감지 (Fly.io, Render, Vercel, Netlify 등) + CLAUDE.md 설정 | Bash, Read, Write, Edit, Glob, Grep, AskUserQuestion |

### 4.6 QA / 테스트

| 스킬명 | 버전 | 설명 | Allowed Tools |
|:---|:---|:---|:---|
| `qa` | v2.0.0 | 웹앱 QA + 버그 자동 수정. 3 tier: Quick / Standard / Exhaustive. before/after health score | Bash, Read, Write, Edit, Glob, Grep, AskUserQuestion |
| `qa-only` | v1.0.0 | 리포트만 생성, 코드 수정 없음 | Bash, Read, Write, AskUserQuestion, WebSearch |
| `benchmark` | v1.0.0 | 성능 회귀 감지 — Core Web Vitals, 번들 사이즈 측정 | Bash, Read, Write, Glob, AskUserQuestion |
| `canary` | v1.0.0 | 배포 후 카나리 모니터링, 스크린샷 비교 | Bash, Read, Write, Glob, AskUserQuestion |

### 4.7 브라우저

| 스킬명 | 버전 | 설명 | Allowed Tools |
|:---|:---|:---|:---|
| `browse` | v1.1.0 | 헤드리스 브라우저 ~100ms/명령, 접근성 트리 기반 | Bash, Read, AskUserQuestion |
| `setup-browser-cookies` | v1.0.0 | 실제 브라우저 쿠키 임포트 (Comet, Chrome, Arc, Brave, Edge 지원) | Bash, Read, AskUserQuestion |

### 4.8 디버깅 & 보안

| 스킬명 | 버전 | 설명 | Allowed Tools |
|:---|:---|:---|:---|
| `investigate` | v1.0.0 | 체계적 디버깅 4단계: 조사 → 분석 → 가설 → 구현. "no fixes without root cause" 원칙 | Bash, Read, Write, Edit, Grep, Glob, AskUserQuestion, WebSearch |
| `cso` | v2.0.0 | CSO 모드 — OWASP Top 10, STRIDE, 공급망 감사. daily / comprehensive 2모드 | Bash, Read, Grep, Glob, Write, Agent, WebSearch, AskUserQuestion |
| `retro` | v2.0.0 | 주간 엔지니어링 회고, 팀 분석, 트렌드 추적 | Bash, Read, Write, Glob, AskUserQuestion |

### 4.9 안전 가드레일

| 스킬명 | 버전 | 설명 | Hook | Allowed Tools |
|:---|:---|:---|:---|:---|
| `careful` | v0.1.0 | 파괴적 명령 경고 | `PreToolUse:Bash` | Bash, Read |
| `freeze` | v0.1.0 | 특정 디렉토리만 편집 허용 | `PreToolUse:Edit` | Bash, Read, AskUserQuestion |
| `unfreeze` | v0.1.0 | freeze 해제 | — | Bash, Read |
| `guard` | v0.1.0 | careful + freeze 결합 | `PreToolUse:Bash` + `PreToolUse:Edit` | Bash, Read, AskUserQuestion |

### 4.10 유틸리티

| 스킬명 | 버전 | 설명 | Allowed Tools |
|:---|:---|:---|:---|
| `gstack-upgrade` | v1.1.0 | gstack 자체 업그레이드 | Bash, Read, Write, AskUserQuestion |

---

## 5. 설치 방법

### 글로벌 설치 (권장)

```bash
bunx gstack@latest install
```

### 프로젝트 로컬 설치

```bash
bun add -d gstack
```

### Codex / Gemini CLI 호환

gstack은 Claude Code 스킬 시스템 기반이지만, `codex` 스킬을 통해 OpenAI Codex CLI와 연동할 수 있고, Gemini CLI에서도 사용 가능하다.

---

## 6. 의존성

| 의존성 | 최소 버전 | 용도 |
|:---|:---|:---|
| **Bun** | v1.0+ | 런타임, 패키지 매니저 |
| **Git** | — | 버전 관리, PR 생성 |
| **Claude Code** | — | 스킬 실행 환경 |
| **Playwright** | — | 헤드리스 브라우저 (browse, qa, design-review 등) |

---

## 7. 참고 영상 요약 목록

이 리포지토리에 있는 gstack 관련 YouTube 요약 문서 4건:

| 파일 경로 | 배치 |
|:---|:---|
| `watchlater-ai-20260320/gstack-YC-CEO-Garry-Tan의-뇌를-빌려-딸깍/yt-summary-gstack-YC-CEO-Garry-Tan의-뇌를-빌려-딸깍-20260320.md` | 20260320 |
| `watchlater-ai-20260320/The-toolkit-from-Y-Combinator-CEO-that/yt-summary-The-toolkit-from-Y-Combinator-CEO-that-20260320.md` | 20260320 |
| `watchlater-ai-20260322/yt-summary-wr4wpYwgOTM-20260322.md` | 20260322 |
| `watchlater-ai-20260322/yt-summary-0322tGsiauo-20260322.md` | 20260322 |

---

| 버전 | 날짜 | 변경 내용 |
|:---|:---|:---|
| v1.0.0 | 2026-03-24 | 초기 작성. gstack v0.11.9.0 기준 28개 스킬 전체 분석 |
