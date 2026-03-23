#!/bin/bash
# bin/sync-commands.sh — upstream SKILL.md → commands/*.md 동기화
#
# 동작:
# 1. 각 스킬 디렉토리의 SKILL.md에서 frontmatter(name, description) + 본문 추출
# 2. commands/*.md 파일이 없으면 새로 생성
# 3. 기존 파일이 있으면 SYNCED 영역만 교체, CUSTOM 영역 보존
# 4. 새 스킬이 추가되었으면 자동 생성

set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
COMMANDS_DIR="$PLUGIN_ROOT/commands"
mkdir -p "$COMMANDS_DIR"

# 스킬 목록 (디렉토리명 → 커맨드명)
SKILLS=(
  "autoplan"
  "benchmark"
  "browse"
  "canary"
  "careful"
  "codex"
  "cso"
  "design-consultation"
  "design-review"
  "document-release"
  "freeze"
  "gstack-upgrade"
  "guard"
  "investigate"
  "land-and-deploy"
  "office-hours"
  "plan-ceo-review"
  "plan-design-review"
  "plan-eng-review"
  "qa"
  "qa-only"
  "retro"
  "review"
  "setup-browser-cookies"
  "setup-deploy"
  "ship"
  "unfreeze"
)

# SKILL.md에서 frontmatter의 name 추출
extract_name() {
  awk '/^---$/{n++;next} n==1 && /^name:/{sub(/^name:[ \t]*/, ""); print; exit}' "$1"
}

# SKILL.md에서 frontmatter의 description 추출 (첫 줄 요약)
extract_description() {
  awk '
    /^---$/ { n++; next }
    n==1 && /^description:/ {
      d=1
      sub(/^description:[ \t]*/, "")
      # block scalar indicator (|)
      if (/^[|][ \t]*$/) { next }
      # inline value
      if (length > 0) { gsub(/^"/, ""); gsub(/"$/, ""); print; exit }
      next
    }
    d && /^  / {
      sub(/^  /, "")
      if (length > 0) { print; exit }
      next
    }
    d && !/^  / { d=0 }
  ' "$1"
}

# SKILL.md에서 frontmatter 이후 본문 추출
extract_body() {
  awk '
    /^---$/ { n++; if(n==2) { body=1; next } next }
    body { print }
  ' "$1"
}

# 기존 CUSTOM 영역 추출
extract_custom() {
  local file="$1"
  if [ ! -f "$file" ]; then
    echo ""
    return
  fi
  awk '
    /<!-- ===== CUSTOM OVERRIDES/ { capture=1; next }
    /<!-- ===== END CUSTOM/ { capture=0; next }
    capture { print }
  ' "$file"
}

synced=0
created=0

for skill in "${SKILLS[@]}"; do
  SKILL_FILE="$PLUGIN_ROOT/$skill/SKILL.md"
  CMD_FILE="$COMMANDS_DIR/$skill.md"

  if [ ! -f "$SKILL_FILE" ]; then
    echo "WARN: $SKILL_FILE not found, skipping"
    continue
  fi

  name=$(extract_name "$SKILL_FILE")
  desc=$(extract_description "$SKILL_FILE")
  body=$(extract_body "$SKILL_FILE")

  # 기존 CUSTOM 영역 보존
  custom=$(extract_custom "$CMD_FILE")

  # 커맨드 파일 생성/갱신
  cat > "$CMD_FILE" << CMDEOF
---
name: ${name}
description: "${desc}"
---

<!-- ===== SYNCED FROM ${skill}/SKILL.md — DO NOT EDIT BELOW ===== -->
${body}
<!-- ===== END SYNCED CONTENT ===== -->

<!-- ===== CUSTOM OVERRIDES — 자유롭게 수정 ===== -->
${custom}
<!-- ===== END CUSTOM ===== -->
CMDEOF

  if [ -z "$custom" ]; then
    created=$((created + 1))
  else
    synced=$((synced + 1))
  fi
done

# 메인 라우터 (루트 SKILL.md → commands/gstack.md)
GSTACK_SKILL="$PLUGIN_ROOT/SKILL.md"
GSTACK_CMD="$COMMANDS_DIR/gstack.md"
if [ -f "$GSTACK_SKILL" ]; then
  name=$(extract_name "$GSTACK_SKILL")
  desc=$(extract_description "$GSTACK_SKILL")
  body=$(extract_body "$GSTACK_SKILL")
  custom=$(extract_custom "$GSTACK_CMD")

  cat > "$GSTACK_CMD" << CMDEOF
---
name: ${name}
description: "${desc}"
---

<!-- ===== SYNCED FROM SKILL.md — DO NOT EDIT BELOW ===== -->
${body}
<!-- ===== END SYNCED CONTENT ===== -->

<!-- ===== CUSTOM OVERRIDES — 자유롭게 수정 ===== -->
${custom}
<!-- ===== END CUSTOM ===== -->
CMDEOF

  created=$((created + 1))
fi

echo "sync-commands: ${created} created, ${synced} updated (custom preserved)"
echo "total commands: $(ls "$COMMANDS_DIR"/*.md 2>/dev/null | wc -l | tr -d ' ')"
