---
title: "/gstack:gemini 커맨드 설계"
date: 2026-03-24
status: Approved
approach: Codex 패턴 복제 + Gemini CLI 적응
---

# /gstack:gemini 커맨드 설계

## TL;DR

- Codex 스킬과 동일한 3모드 (Review / Challenge / Consult)를 Gemini CLI로 구현
- `gemini -p "<prompt>" --approval-mode plan -o stream-json`으로 실행
- 세션 관리는 Gemini 내장 기능 (`-r latest`) 활용, 파일 관리 불필요
- 커맨드 파일: `commands/gemini.md` (plugin auto-discovery)

---

## 1. 개요

gstack의 `/codex` 스킬이 OpenAI Codex CLI를 래핑하여 독립적 2차 의견을 제공하듯,
`/gstack:gemini`는 Google Gemini CLI를 래핑하여 동일한 역할을 수행한다.

### 설계 결정 사항

| 항목 | 결정 | 근거 |
|:-----|:-----|:-----|
| 커맨드명 | `/gstack:gemini` | Codex와 공존, 나중에 3중 검증 가능 |
| 실행 모드 | `-p` 헤드리스 | ACP는 향후 고도화 (단발 호출에 과잉) |
| 페르소나 | Codex와 동일 | Cross-model 비교 시 공정한 기준 |
| 읽기 전용 | `--approval-mode plan` | 코드 수정 방지 |

---

## 2. 모드별 설계

### 2A. Review 모드

Codex에는 `codex review --base <branch>` 전용 서브커맨드가 있지만,
Gemini에는 없으므로 **diff를 프롬프트에 포함**하여 구현한다.

```bash
# diff 추출
DIFF=$(git diff origin/<base>...HEAD 2>/dev/null || git diff <base>...HEAD)

# Gemini 실행
gemini -p "<review prompt with diff>" --approval-mode plan -o stream-json
```

**Review 프롬프트:**

```
You are a brutally honest code reviewer — direct, terse, technically precise.
Review the following git diff. For each finding, assign priority:
- [P1] Critical — must fix before merge (security, data loss, logic error)
- [P2] Important — should fix (performance, maintainability, edge cases)

Be adversarial. No compliments — just the problems.

GIT DIFF:
<diff content>
```

**GATE 판정:** 출력에 `[P1]`이 있으면 FAIL, 없으면 PASS. (Codex와 동일)

### 2B. Challenge (적대적) 모드

```bash
gemini -p "<adversarial prompt>" --approval-mode plan -o stream-json
```

**기본 프롬프트 (포커스 없음):**

```
Review the changes on this branch. Your job is to find ways this code will
fail in production. Think like an attacker and a chaos engineer. Find edge
cases, race conditions, security holes, resource leaks, failure modes, and
silent data corruption paths. Be adversarial. Be thorough. No compliments.

GIT DIFF:
<diff content>
```

**포커스 지정 시 (예: security):**

```
Focus specifically on SECURITY. Find every way an attacker could exploit
this code. Injection vectors, auth bypasses, privilege escalation, data
exposure, timing attacks. Be adversarial.

GIT DIFF:
<diff content>
```

### 2C. Consult 모드

```bash
# 새 세션
gemini -p "<prompt>" --approval-mode plan -o stream-json

# 이어가기
gemini -r latest -p "<follow-up>" --approval-mode plan -o stream-json
```

**세션 연속성 흐름:**

```
1. gemini --list-sessions 실행
2. 세션 존재?
   ├── YES → AskUserQuestion: "이어가기(A) / 새로 시작(B)"
   │   ├── A → gemini -r latest -p "<prompt>"
   │   └── B → gemini -p "<prompt>"
   └── NO → gemini -p "<prompt>"
```

**플랜 리뷰 자동 감지:**
Codex와 동일하게 `~/.claude/plans/*.md`에서 현재 프로젝트 플랜 파일을 찾아
자동으로 리뷰 프롬프트에 포함.

---

## 3. 출력 파싱

### stream-json 형식 (실제 테스트 확정)

Gemini의 `-o stream-json`은 NDJSON 형식. 5개 이벤트 타입:

| type | 설명 |
|:-----|:-----|
| `init` | 세션 시작 (session_id, model) |
| `message` (role: user) | 입력 프롬프트 |
| `message` (role: assistant, delta: true) | 응답 스트리밍 청크 |
| `tool_use` | 도구 호출 (tool_name, parameters) |
| `tool_result` | 도구 결과 (status, output) |
| `result` | 완료 + 토큰 통계 (models별 분류 포함) |

검증된 Python 파서:

```python
import sys, json
content_parts = []
tokens_info = None
for line in sys.stdin:
    line = line.strip()
    if not line: continue
    try:
        obj = json.loads(line)
        t = obj.get('type', '')
        if t == 'message' and obj.get('role') == 'assistant':
            c = obj.get('content', '')
            if c: content_parts.append(c)
        elif t == 'tool_use':
            tn = obj.get('tool_name', '')
            if tn: content_parts.append(f'[gemini used tool: {tn}]')
        elif t == 'result':
            stats = obj.get('stats', {})
            tokens_info = {
                'total': stats.get('total_tokens', 0),
                'input': stats.get('input_tokens', 0),
                'output': stats.get('output_tokens', 0),
                'duration_ms': stats.get('duration_ms', 0),
                'tool_calls': stats.get('tool_calls', 0)
            }
    except: pass
print(''.join(content_parts))
if tokens_info:
    print(f"\n---STATS---\ntotal_tokens: {tokens_info['total']}\nduration_ms: {tokens_info['duration_ms']}")
```

상세 형식 분석: `jerry-docs/research/2026-03-24-gemini-cli-stream-json-format.md`

### 출력 표시 형식

```
GEMINI SAYS (code review):
════════════════════════════════════════════════════════════
<full gemini output, verbatim — do not truncate or summarize>
════════════════════════════════════════════════════════════
GATE: PASS                    Tokens: 12,450
```

---

## 4. Cross-model Comparison

`/review` (Claude)가 이미 실행된 경우, Gemini 결과와 비교:

```
CROSS-MODEL ANALYSIS:
  Both found: [겹치는 발견사항]
  Only Gemini found: [Gemini만 발견]
  Only Claude found: [Claude만 발견]
  Agreement rate: X% (N/M)
```

---

## 5. 에러 처리

| 상황 | 처리 |
|:-----|:-----|
| `gemini` 바이너리 없음 | "Gemini CLI not found. Install: `npm install -g @anthropic-ai/gemini-cli`" |
| 인증 실패 | "Gemini 인증 실패. `gemini` 실행하여 로그인하거나 GEMINI_API_KEY 설정" |
| 5분 타임아웃 | "Gemini timed out. diff가 너무 크거나 API가 느림" |
| 빈 응답 | "Gemini returned no response. stderr 확인" |
| 세션 resume 실패 | 세션 삭제 후 새로 시작 |

---

## 6. 파일 구조

```
commands/gemini.md          ← 커맨드 래퍼 (신규 생성)
```

`commands/gemini.md`는 upstream에 없는 우리만의 커맨드이므로
sync-commands.sh의 SYNCED/CUSTOM 패턴이 아니라 **전체가 커스텀**.

---

## 7. Codex 스킬과의 대응표

| 요소 | Codex (`/codex`) | Gemini (`/gemini`) |
|:-----|:-----------------|:-------------------|
| 바이너리 체크 | `which codex` | `which gemini` |
| Review 실행 | `codex review --base <b>` | `gemini -p "<prompt with diff>" --approval-mode plan` |
| Challenge 실행 | `codex exec "<prompt>" -s read-only` | `gemini -p "<prompt>" --approval-mode plan` |
| Consult 실행 | `codex exec "<prompt>" -s read-only` | `gemini -p "<prompt>" --approval-mode plan` |
| 출력 파싱 | `--json` + python JSONL parser | `-o stream-json` + python parser |
| 세션 이어가기 | `codex exec resume <id>` | `gemini -r latest` |
| 세션 저장 | `.context/codex-session-id` 수동 관리 | 자동 (Gemini 내장) |
| 읽기 전용 | `-s read-only` | `--approval-mode plan` |
| 타임아웃 | 5분 | 5분 |
| 출력 헤더 | `CODEX SAYS` | `GEMINI SAYS` |
| 리뷰 로그 | `gstack-review-log` (codex-review) | `gstack-review-log` (gemini-review) |

---

## 8. 관련 문서

- 리서치: `jerry-docs/research/2026-03-24-gemini-cli-acp-research.md`
- 3중 검증 TODO: `jerry-docs/superpowers/todo-triple-verification.md`
- Codex 원본: `codex/SKILL.md.tmpl`

---

| 버전 | 날짜 | 변경 내용 |
|:-----|:-----|:----------|
| v1.0.0 | 2026-03-24 | 초기 설계 |
