---
title: "TODO: 3중 검증 (Claude + Codex + Gemini)"
date: 2026-03-24
status: TODO
prerequisite: /gstack:gemini 구현 완료, Codex CLI 설치
---

# TODO: 3중 검증 (Claude + Codex + Gemini)

## 개요

Claude Code의 `/review` + Codex의 `/codex review` + Gemini의 `/gemini review`를
순차 또는 병렬 실행하여 3개 AI 모델의 합의율 기반 코드 리뷰.

## 예상 플로우

```
/triple-review 또는 /gstack:multi-review
  ├── Claude /review 실행
  ├── Codex /codex review 실행
  ├── Gemini /gemini review 실행
  └── Cross-model Analysis (3-way)
      ├── 3개 모두 발견: HIGH CONFIDENCE 이슈
      ├── 2개 발견: MEDIUM CONFIDENCE
      ├── 1개만 발견: LOW CONFIDENCE (모델 특유 발견)
      └── Agreement rate: X% (N/M)
```

## 선행 조건

1. `/gstack:gemini` 커맨드 구현 완료
2. Codex CLI 설치 및 인증 (`npm install -g @openai/codex`)
3. 3중 검증 시 비용: Claude(기본) + Codex(~$0.12) + Gemini(무료/유료) ≈ $0.15-0.30/회

## ACP 고도화 가능성

3중 검증을 ACP 프로토콜로 구현하면:
- 3개 에이전트를 subprocess로 동시 기동 → 병렬 리뷰
- 구조화된 JSON-RPC 응답으로 자동 파싱/비교
- 세부 사항은 `jerry-docs/research/2026-03-24-gemini-cli-acp-research.md` 참고

---

| 버전 | 날짜 | 변경 내용 |
|:-----|:-----|:----------|
| v1.0.0 | 2026-03-24 | 초기 작성 (TODO) |
