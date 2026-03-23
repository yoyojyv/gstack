---
title: Gemini CLI stream-json 출력 형식 분석
date: 2026-03-24
status: Research Complete
tags: [gemini-cli, stream-json, output-parsing]
---

# Gemini CLI stream-json 출력 형식 분석

## TL;DR

- `gemini -o stream-json`은 NDJSON (Newline-Delimited JSON) 형식으로 이벤트를 스트리밍
- 이벤트 타입: `init`, `message`, `tool_use`, `tool_result`, `result`
- Codex의 `--json` 대비 훨씬 단순하고 직관적인 구조
- `result` 이벤트에 모델별 토큰 사용량까지 포함

---

## 1. 이벤트 타입별 구조

### init — 세션 시작

```json
{
  "type": "init",
  "timestamp": "2026-03-23T17:46:18.652Z",
  "session_id": "fa39183b-a796-402c-bd29-85046e650630",
  "model": "auto-gemini-3"
}
```

- `session_id`: 세션 고유 ID (UUID)
- `model`: 사용 모델 (auto-routing 시 `auto-gemini-3`)

### message (user) — 입력 프롬프트

```json
{
  "type": "message",
  "timestamp": "2026-03-23T17:46:18.653Z",
  "role": "user",
  "content": "Say hello in one sentence"
}
```

### message (assistant) — 응답 스트리밍

```json
{
  "type": "message",
  "timestamp": "2026-03-23T17:46:24.473Z",
  "role": "assistant",
  "content": "Hello, I'm Gemini CLI...",
  "delta": true
}
```

- `delta: true`: 스트리밍 청크임을 나타냄
- 여러 청크가 연속으로 올 수 있음 → `content`를 이어붙여야 전체 응답

### tool_use — 도구 호출

```json
{
  "type": "tool_use",
  "timestamp": "2026-03-23T17:46:41.327Z",
  "tool_name": "read_file",
  "tool_id": "read_file_1774288001327_0",
  "parameters": { "file_path": "package.json" }
}
```

### tool_result — 도구 결과

```json
{
  "type": "tool_result",
  "timestamp": "2026-03-23T17:46:41.394Z",
  "tool_id": "read_file_1774288001327_0",
  "status": "success",
  "output": ""
}
```

- `output`이 비어있을 수 있음 (도구가 내부적으로 처리)

### result — 완료 + 통계

```json
{
  "type": "result",
  "timestamp": "2026-03-23T17:46:43.094Z",
  "status": "success",
  "stats": {
    "total_tokens": 29099,
    "input_tokens": 28884,
    "output_tokens": 89,
    "cached": 0,
    "input": 28884,
    "duration_ms": 5617,
    "tool_calls": 1,
    "models": {
      "gemini-2.5-flash-lite": {
        "total_tokens": 2695,
        "input_tokens": 2525,
        "output_tokens": 44,
        "cached": 0,
        "input": 2525
      },
      "gemini-3-flash-preview": {
        "total_tokens": 26404,
        "input_tokens": 26359,
        "output_tokens": 45,
        "cached": 0,
        "input": 26359
      }
    }
  }
}
```

- `models`: auto-routing 시 어떤 모델이 얼마나 사용됐는지 분류
- `duration_ms`: 전체 실행 시간

---

## 2. Codex `--json` 형식과 비교

| 항목 | Gemini (`-o stream-json`) | Codex (`--json`) |
|:-----|:--------------------------|:-----------------|
| 형식 | NDJSON | NDJSON |
| 세션 시작 | `type: "init"` + session_id | `type: "thread.started"` + thread_id |
| 응답 텍스트 | `type: "message"`, role: assistant | `type: "item.completed"`, item.type: agent_message |
| 사고 과정 | 없음 (비공개) | `item.type: "reasoning"` |
| 도구 호출 | `type: "tool_use"` + tool_name | `item.type: "command_execution"` + command |
| 완료 | `type: "result"` + stats | `type: "turn.completed"` + usage |
| 모델별 분류 | `stats.models` 에 상세 분류 | 없음 |
| 파서 복잡도 | 낮음 (5개 이벤트 타입) | 높음 (중첩 구조, item.type 분기) |

### 핵심 차이

1. **Gemini가 훨씬 단순**: 최상위 `type` 필드만 보면 됨. Codex는 `type` → `item.type` 2단계 분기.
2. **Gemini에 reasoning 없음**: Codex는 `[codex thinking]` 추출 가능하지만, Gemini는 사고 과정 비공개.
3. **Gemini에 모델별 토큰 분류**: auto-routing 시 어떤 모델이 얼마나 사용됐는지 알 수 있음.

---

## 3. 파서 구현 (Python)

### 최소 파서

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
    print(f"\n---STATS---")
    print(f"total_tokens: {tokens_info['total']}")
    print(f"duration_ms: {tokens_info['duration_ms']}")
```

---

## 4. 실제 테스트 결과

### 테스트 1: 간단한 응답

```bash
gemini -p "Say hello in one sentence" -o stream-json
```

- 이벤트 4개: init → message(user) → message(assistant) → result
- 토큰: 14,510 (input: 14,236 / output: 54)
- 시간: 5,863ms

### 테스트 2: 도구 사용

```bash
gemini -p "Read package.json and tell me the project name" --approval-mode yolo -o stream-json
```

- 이벤트 7개: init → message(user) → message(assistant) → tool_use → tool_result → message(assistant) x2 → result
- 토큰: 29,099 (tool_calls: 1)
- 시간: 5,617ms

### 테스트 3: 코드 리뷰 (P1/P2 마커)

```bash
gemini -p "Review this code... function divide(a, b) { return a / b; }" --approval-mode plan -o stream-json
```

- [P1] Division by Zero, [P2] Missing Type Validation 정상 출력
- 토큰: 12,717 (output: 163)
- 시간: 8,324ms
- GATE 판정 파서: `[P1]` 감지 → FAIL 판정 정상 동작

### 테스트 4: 세션 이어가기

```bash
gemini -r latest -p "What was the most critical finding?" --approval-mode plan -o stream-json
```

- 이전 세션 컨텍스트 정상 유지
- [P1] Division by Zero를 기억하고 답변

---

## 5. 발견 사항 및 주의점

### auto-gemini-3 라우팅

- `model: "auto-gemini-3"` 사용 시 `gemini-2.5-flash-lite`와 `gemini-3-flash-preview` 사이에서 자동 라우팅
- 간단한 요청은 flash-lite, 복잡한 요청은 flash-preview로 분배
- `result.stats.models`에서 어떤 모델이 사용됐는지 확인 가능

### 입력 토큰이 많음

- "Say hello" 같은 간단한 프롬프트에도 input_tokens: 14,236
- Gemini CLI가 내부적으로 시스템 프롬프트 + 컨텍스트를 함께 전송하기 때문
- 비용 영향은 크지 않음 (flash 모델의 입력 토큰 비용은 매우 저렴)

### `--approval-mode plan` 동작

- 파일 읽기/쓰기 도구 사용 불가 (read-only)
- Review/Challenge 모드에 적합
- Consult 모드에서도 기본 plan 모드 사용 (코드 수정 방지)

### 세션 관리

- 프로젝트 디렉토리 기준으로 세션 자동 관리
- `--list-sessions`로 조회, `-r latest` 또는 `-r <N>`으로 이어가기
- `--delete-session <N>`으로 삭제
- Codex의 수동 session-id 파일 관리 대비 훨씬 편리

---

| 버전 | 날짜 | 변경 내용 |
|:-----|:-----|:----------|
| v1.0.0 | 2026-03-24 | 초기 작성. 4가지 테스트 결과 포함 |
