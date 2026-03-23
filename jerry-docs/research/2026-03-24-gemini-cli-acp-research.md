---
title: Gemini CLI ACP 모드 리서치
date: 2026-03-24
status: Research Complete
tags: [gemini-cli, acp, agent-communication-protocol]
---

# Gemini CLI ACP 모드 리서치

## TL;DR

- ACP(Agent Client Protocol)는 코드 에디터와 AI 에이전트 간 통신을 표준화하는 프로토콜 (LSP의 AI 버전)
- stdin/stdout 위에서 newline-delimited JSON-RPC 2.0으로 통신
- Gemini CLI를 `--acp` 플래그로 실행하면 ACP 모드 진입
- Claude Code에서 subprocess로 띄워 구조화된 통신이 가능하나, 현재 목적(2차 의견)에는 `-p` 모드로 충분

---

## 1. ACP란?

**Agent Client Protocol** — Zed 에디터가 2025년 8월 오픈 스탠다드로 공개 (Apache License).

LSP가 "언어 서버 ↔ 에디터" 통신을 표준화했듯이, ACP는 "AI 에이전트 ↔ 에디터/클라이언트" 통신을 표준화한다.

지원 구현체:
- Google Gemini CLI
- Claude Code
- OpenAI Codex CLI
- Goose (Block)

---

## 2. 작동 방식

### 전송 계층

- **stdin/stdout** 위에서 newline-delimited JSON-RPC 2.0
- 에디터가 에이전트를 **서브프로세스로 생성**하고 파이프로 통신
- 원격 에이전트의 경우 HTTP/WebSocket도 지원

### Gemini CLI 실행

```bash
gemini --acp
```

### 세션 라이프사이클

```
Uninitialized → Initialized → (Authenticated) → Ready → Processing → (Cancelling)
```

| 단계 | 메서드 | 방향 |
|:-----|:-------|:-----|
| 초기화 | `initialize` | Client → Agent |
| 인증 (선택) | `authenticate` | Client → Agent |
| 세션 생성 | `session/new` | Client → Agent |
| 프롬프트 전송 | `session/prompt` | Client → Agent |
| 스트리밍 업데이트 | `session/update` (notification) | Agent → Client |
| 프롬프트 완료 | `session/prompt` response | Agent → Client |
| 취소 | `session/cancel` | Client → Agent |

---

## 3. 메시지 포맷

### Request (응답 기대)

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "initialize",
  "params": { "protocolVersion": 1 }
}
```

### Notification (응답 없음)

```json
{
  "jsonrpc": "2.0",
  "method": "session/update",
  "params": { "sessionId": "sess-123", "update": { ... } }
}
```

### 주요 메서드

**Client → Agent:**
- `initialize` — 버전/기능 협상
- `session/new` — 세션 생성 (params: `cwd`, `mcpServers`)
- `session/prompt` — 프롬프트 전송 (params: `sessionId`, `prompt: ContentBlock[]`)
- `session/cancel` — 처리 취소
- `session/set_mode` — 모드 변경

**Agent → Client:**
- `session/update` — 스트리밍 응답 (메시지 청크, 도구 호출)
- `session/request_permission` — 도구 실행 권한 요청
- `fs/read_text_file`, `fs/write_text_file` — 파일 접근
- `terminal/create`, `terminal/output` — 터미널 관리

---

## 4. 프로그래밍 방식 통신

### Python SDK 사용

```python
from acp import spawn_agent_process, text_block
from acp.schema import InitializeRequest, NewSessionRequest, PromptRequest

async with spawn_agent_process(lambda _: MyClient(), "gemini", "--acp") as (conn, proc):
    await conn.initialize(InitializeRequest(protocolVersion=1))
    session = await conn.newSession(NewSessionRequest(cwd=".", mcpServers=[]))
    response = await conn.prompt(PromptRequest(
        sessionId=session.sessionId,
        prompt=[text_block("이 코드를 분석해줘")]
    ))
```

### 직접 subprocess 통신 (SDK 없이)

```python
import asyncio, json

process = await asyncio.create_subprocess_shell(
    'gemini --acp',
    stdin=asyncio.subprocess.PIPE,
    stdout=asyncio.subprocess.PIPE,
    stderr=asyncio.subprocess.PIPE
)

msg = json.dumps({"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":1}})
process.stdin.write((msg + "\n").encode())
await process.stdin.drain()

line = await process.stdout.readline()
response = json.loads(line)
```

---

## 5. 세션 관리: Codex vs Gemini 비교

### Codex 세션 관리

```bash
# 새 세션 → session-id를 .context/codex-session-id에 수동 저장
codex exec "<prompt>" -s read-only --json 2>/dev/null
# → thread.started 이벤트에서 thread_id 추출 → 파일에 저장

# 세션 이어가기 → session-id 직접 지정
codex exec resume <session-id> "<follow-up>" -s read-only
```

- session-id를 직접 파일로 관리해야 함
- `.context/codex-session-id`에 저장하는 패턴

### Gemini 세션 관리

```bash
# 세션 목록 조회 (프로젝트별 자동 관리)
gemini --list-sessions
# → Available sessions for this project (1):
# →   1. Say hello (Just now) [341aef65-3a04-483d-8c29-6787d6a5f9eb]

# 최근 세션 이어가기
gemini -r latest -p "<follow-up>" --approval-mode plan -o stream-json

# 특정 세션 지정 (인덱스)
gemini -r 1 -p "<prompt>" --approval-mode plan -o stream-json
```

- 프로젝트별 세션 자동 저장/관리
- session-id 파일 관리 불필요
- `latest` 키워드 또는 인덱스 번호로 접근

### 비교표

| 항목 | Codex | Gemini |
|:-----|:------|:-------|
| 세션 식별 | UUID (thread_id) | 인덱스 번호 또는 `latest` |
| 저장 방식 | 수동 (파일에 저장) | 자동 (프로젝트별 관리) |
| 이어가기 | `codex exec resume <id>` | `gemini -r latest` 또는 `-r <N>` |
| 세션 목록 | 없음 | `gemini --list-sessions` |
| 세션 삭제 | 없음 | `gemini --delete-session <N>` |
| 복잡도 | 높음 (파서 + 파일 관리) | 낮음 (CLI 내장) |

### /gstack:gemini 설계에 적용

Consult 모드에서:
1. `gemini --list-sessions`로 기존 세션 존재 여부 확인
2. 세션 있으면 사용자에게 "이어가기 / 새로 시작" 선택 요청
3. 이어가기: `gemini -r latest -p "<prompt>"`
4. 새로 시작: `gemini -p "<prompt>"`
5. `.context/` 파일 관리 불필요 — Gemini가 자동으로 처리

---

## 6. `-p` 모드 vs `--acp` 모드 비교

| 항목 | `-p` (headless) | `--acp` (JSON-RPC) |
|:-----|:----------------|:-------------------|
| 복잡도 | 낮음 — 한 줄 명령 | 높음 — 프로토콜 구현 필요 |
| 출력 형식 | text / json / stream-json | JSON-RPC 2.0 |
| 세션 관리 | `-r latest` 플래그 | 내장 세션 라이프사이클 |
| 스트리밍 | `-o stream-json` | `session/update` notification |
| 도구 권한 | `--approval-mode` | `session/request_permission` |
| 적합 용도 | 단발 호출, 2차 의견 | 지속 에이전트, IDE 통합 |

---

## 6. 결론 및 적용 방향

### 1차 구현: `-p` 모드 (현재)

gstack `/gemini` 커맨드의 Review/Challenge/Consult 3모드를 `-p` 헤드리스 모드로 구현.
Codex 스킬과 동일한 패턴으로 간단하고 안정적.

### 향후 고도화: ACP 모드 (TODO)

ACP 활용이 의미 있는 시나리오:
- **지속적 코드 리뷰 에이전트**: 파일 변경 감지 → 자동 리뷰
- **IDE 통합**: JetBrains/Zed에서 Gemini를 ACP 에이전트로 등록
- **멀티턴 디버깅 세션**: 복잡한 디버깅에서 컨텍스트 유지하며 반복 질문

---

## 7. 주의사항

- ACP 모드에서 subprocess 실행 시 OAuth 로그인 프롬프트가 뜰 수 있음 → `GEMINI_API_KEY` 환경변수 사용 권장
- MCP 서버 통합 가능 (에이전트가 파일 시스템/터미널 접근)
- 모든 파일 경로는 절대 경로 필수
- 라인 번호는 1-based 인덱싱

---

## 출처

- [ACP Protocol Overview](https://agentclientprotocol.com/protocol/overview)
- [Intro to ACP — Goose Blog](https://block.github.io/goose/blog/2025/10/24/intro-to-agent-client-protocol-acp/)
- [ACP: The LSP for AI Coding Agents — PromptLayer](https://blog.promptlayer.com/agent-client-protocol-the-lsp-for-ai-coding-agents/)
- [Gemini CLI + IntelliJ ACP Integration](https://glaforge.dev/posts/2026/02/01/how-to-integrate-gemini-cli-with-intellij-idea-using-acp/)
- [ACP Python SDK — DeepWiki](https://deepwiki.com/agentclientprotocol/python-sdk/4.1-agent-client-protocol-overview)

---

| 버전 | 날짜 | 변경 내용 |
|:-----|:-----|:----------|
| v1.0.0 | 2026-03-24 | 초기 리서치 |
