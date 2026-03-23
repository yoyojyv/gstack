---
name: gemini
description: "Gemini CLI wrapper — three modes. Code review: independent diff review with pass/fail gate. Challenge: adversarial mode that tries to break your code. Consult: ask Gemini anything with session continuity. Use when asked to 'gemini review', 'gemini challenge', 'ask gemini', 'second opinion gemini', or 'consult gemini'."
---

# /gemini — Multi-AI Second Opinion (Gemini)

You are running the `/gstack:gemini` skill. This wraps the Google Gemini CLI to get an
independent, brutally honest second opinion from a different AI system.

Gemini is the "200 IQ autistic developer" — direct, terse, technically precise, challenges
assumptions, catches things you might miss. Present its output faithfully, not summarized.

---

## Step 0: Check gemini binary

```bash
GEMINI_BIN=$(which gemini 2>/dev/null || echo "")
[ -z "$GEMINI_BIN" ] && echo "NOT_FOUND" || echo "FOUND: $GEMINI_BIN"
```

If `NOT_FOUND`: stop and tell the user:
"Gemini CLI not found. Install it: `npm install -g @anthropic-ai/gemini-cli` or see https://github.com/google-gemini/gemini-cli"

---

## Step 0.5: Detect base branch

Determine which branch this PR targets. Use the result as "the base branch" in all subsequent steps.

1. Check if a PR already exists for this branch:
   `gh pr view --json baseRefName -q .baseRefName`
   If this succeeds, use the printed branch name as the base branch.

2. If no PR exists (command fails), detect the repo's default branch:
   `gh repo view --json defaultBranchRef -q .defaultBranchRef.name`

3. If both commands fail, fall back to `main`.

---

## Step 1: Detect mode

Parse the user's input to determine which mode to run:

1. `/gemini review` or `/gemini review <instructions>` — **Review mode** (Step 2A)
2. `/gemini challenge` or `/gemini challenge <focus>` — **Challenge mode** (Step 2B)
3. `/gemini` with no arguments — **Auto-detect:**
   - Check for a diff (with fallback if origin isn't available):
     `git diff origin/<base> --stat 2>/dev/null | tail -1 || git diff <base> --stat 2>/dev/null | tail -1`
   - If a diff exists, ask the user:
     ```
     Gemini detected changes against the base branch. What should it do?
     A) Review the diff (code review with pass/fail gate)
     B) Challenge the diff (adversarial — try to break it)
     C) Something else — I'll provide a prompt
     ```
   - If no diff, check for plan files:
     `ls -t ~/.claude/plans/*.md 2>/dev/null | xargs grep -l "$(basename $(pwd))" 2>/dev/null | head -1`
     If no project-scoped match, fall back to: `ls -t ~/.claude/plans/*.md 2>/dev/null | head -1`
     but warn: "Note: this plan may be from a different project."
   - If a plan file exists, offer to review it
   - Otherwise, ask: "What would you like to ask Gemini?"
4. `/gemini <anything else>` — **Consult mode** (Step 2C), where the remaining text is the prompt

---

## Step 2A: Review Mode

Run Gemini code review against the current branch diff.

1. Capture the diff:
```bash
DIFF_CONTENT=$(git diff origin/<base>...HEAD 2>/dev/null || git diff <base>...HEAD 2>/dev/null)
echo "$DIFF_CONTENT" | head -5
echo "---"
echo "$DIFF_CONTENT" | wc -l
```

If the diff is empty, tell the user: "No diff found against the base branch. Nothing to review."

2. Construct the review prompt. If the user provided custom instructions (e.g., `/gemini review focus on security`), prepend them:

Default prompt:
```
You are a brutally honest code reviewer — direct, terse, technically precise.
Review the following git diff. For each finding, assign priority:
- [P1] Critical — must fix before merge (security, data loss, logic error)
- [P2] Important — should fix (performance, maintainability, edge cases)

Be adversarial. No compliments — just the problems.
If there are no issues, say "No issues found."

GIT DIFF:
```

With custom instructions (e.g., "focus on security"):
```
You are a brutally honest code reviewer — direct, terse, technically precise.
Focus specifically on: <user instructions>
For each finding, assign priority:
- [P1] Critical — must fix before merge
- [P2] Important — should fix

GIT DIFF:
```

3. Write the full prompt (review text + diff) to a temp file and run Gemini (5-minute timeout):
```bash
TMPROMPT=$(mktemp /tmp/gemini-prompt-XXXXXX.txt)
cat > "$TMPROMPT" << 'PROMPT_EOF'
<review prompt here>
PROMPT_EOF
echo "" >> "$TMPROMPT"
git diff origin/<base>...HEAD >> "$TMPROMPT" 2>/dev/null || git diff <base>...HEAD >> "$TMPROMPT" 2>/dev/null
```

```bash
gemini -p "$(cat "$TMPROMPT")" --approval-mode plan -o stream-json 2>/dev/null | python3 -c "
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
full_content = ''.join(content_parts)
print(full_content)
if tokens_info:
    print(f\"\"\"
---STATS---
total_tokens: {tokens_info['total']}
input_tokens: {tokens_info['input']}
output_tokens: {tokens_info['output']}
duration_ms: {tokens_info['duration_ms']}
tool_calls: {tokens_info['tool_calls']}\"\"\")
"
```

Use `timeout: 300000` on the Bash call.

4. Determine gate verdict by checking the output for critical findings.
   If the output contains `[P1]` — the gate is **FAIL**.
   If no `[P1]` markers are found (only `[P2]` or no findings) — the gate is **PASS**.

5. Present the output:

```
GEMINI SAYS (code review):
════════════════════════════════════════════════════════════
<full gemini output, verbatim — do not truncate or summarize>
════════════════════════════════════════════════════════════
GATE: PASS                    Tokens: 14,331 | Duration: 5.8s
```

or

```
GATE: FAIL (N critical findings)
```

6. **Cross-model comparison:** If `/review` (Claude's own review) was already run
   earlier in this conversation, compare the two sets of findings:

```
CROSS-MODEL ANALYSIS:
  Both found: [findings that overlap between Claude and Gemini]
  Only Gemini found: [findings unique to Gemini]
  Only Claude found: [findings unique to Claude's /review]
  Agreement rate: X% (N/M total unique findings overlap)
```

7. Clean up temp files:
```bash
rm -f "$TMPROMPT"
```

---

## Step 2B: Challenge (Adversarial) Mode

Gemini tries to break your code — finding edge cases, race conditions, security holes,
and failure modes that a normal review would miss.

1. Capture the diff (same as Review mode).

2. Construct the adversarial prompt. If the user provided a focus area
(e.g., `/gemini challenge security`), include it:

Default prompt (no focus):
```
Review the following code changes. Your job is to find ways this code will fail
in production. Think like an attacker and a chaos engineer. Find edge cases, race
conditions, security holes, resource leaks, failure modes, and silent data
corruption paths. Be adversarial. Be thorough. No compliments — just the problems.

GIT DIFF:
```

With focus (e.g., "security"):
```
Review the following code changes. Focus specifically on SECURITY. Your job is to
find every way an attacker could exploit this code. Think about injection vectors,
auth bypasses, privilege escalation, data exposure, and timing attacks. Be adversarial.

GIT DIFF:
```

3. Write prompt + diff to temp file and run Gemini with the same stream-json parser as Review mode.
   Use `--approval-mode plan` (read-only). Timeout: 5 minutes.

4. Present the full output:

```
GEMINI SAYS (adversarial challenge):
════════════════════════════════════════════════════════════
<full output, verbatim>
════════════════════════════════════════════════════════════
Tokens: N | Duration: Xs
```

---

## Step 2C: Consult Mode

Ask Gemini anything about the codebase. Supports session continuity for follow-ups.

1. **Check for existing sessions:**
```bash
gemini --list-sessions 2>/dev/null | grep -v "^Loaded" | head -10
```

If sessions exist (output contains numbered entries), ask the user:
```
You have existing Gemini sessions for this project. Continue the latest or start fresh?
A) Continue the latest session (Gemini remembers the prior context)
B) Start a new session
```

2. **Plan review auto-detection:** If the user's prompt is about reviewing a plan,
or if plan files exist and the user said `/gemini` with no arguments:
```bash
ls -t ~/.claude/plans/*.md 2>/dev/null | xargs grep -l "$(basename $(pwd))" 2>/dev/null | head -1
```
If a plan file is found, read it and prepend the persona:
```
You are a brutally honest technical reviewer. Review this plan for: logical gaps
and unstated assumptions, missing error handling or edge cases, overcomplexity
(is there a simpler approach?), feasibility risks (what could go wrong?), and
missing dependencies or sequencing issues. Be direct. Be terse. No compliments.

THE PLAN:
<plan content>
```

3. Run Gemini (5-minute timeout):

For a **new session:**
```bash
gemini -p "<prompt>" --approval-mode plan -o stream-json 2>/dev/null | python3 -c "
<same stream-json parser as Review mode>
"
```

For a **resumed session** (user chose "Continue"):
```bash
gemini -r latest -p "<follow-up prompt>" --approval-mode plan -o stream-json 2>/dev/null | python3 -c "
<same stream-json parser as Review mode>
"
```

4. Present the full output:

```
GEMINI SAYS (consult):
════════════════════════════════════════════════════════════
<full output, verbatim>
════════════════════════════════════════════════════════════
Tokens: N | Duration: Xs
Session saved — run /gstack:gemini again to continue this conversation.
```

5. After presenting, note any points where Gemini's analysis differs from your own
   understanding. If there is a disagreement, flag it:
   "Note: Claude Code disagrees on X because Y."

---

## Model & Output

**Model:** No model is hardcoded — Gemini uses its auto-routing default (currently
`auto-gemini-3`, which routes between flash-lite and flash-preview). As Google ships
newer models, /gemini automatically uses them. If the user wants a specific model,
pass `-m <model>` through to gemini.

**Output:** All modes use `-o stream-json` for structured output parsing. The parser
extracts assistant messages, tool usage, and token statistics from the JSONL events.

If the user specifies a model (e.g., `/gemini review -m gemini-2.5-pro`),
pass the `-m` flag through to gemini.

---

## Error Handling

- **Binary not found:** Detected in Step 0. Stop with install instructions.
- **Auth error:** Surface the error:
  "Gemini authentication failed. Run `gemini` in your terminal to authenticate, or set GEMINI_API_KEY."
- **Timeout:** If the Bash call times out (5 min), tell the user:
  "Gemini timed out after 5 minutes. The diff may be too large or the API may be slow. Try again or use a smaller scope."
- **Empty response:** If no assistant messages were captured, tell the user:
  "Gemini returned no response. Run `gemini` interactively to check for issues."
- **Session resume failure:** If resume fails, start a fresh session instead.

---

## Important Rules

- **Never modify files.** This skill is read-only. Gemini runs with `--approval-mode plan`.
- **Present output verbatim.** Do not truncate, summarize, or editorialize Gemini's output
  before showing it. Show it in full inside the GEMINI SAYS block.
- **Add synthesis after, not instead of.** Any Claude commentary comes after the full output.
- **5-minute timeout** on all Bash calls to gemini (`timeout: 300000`).
- **No double-reviewing.** If the user already ran `/review`, Gemini provides a second
  independent opinion. Do not re-run Claude Code's own review.
