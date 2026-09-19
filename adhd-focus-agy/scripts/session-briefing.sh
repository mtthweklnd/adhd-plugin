#!/bin/sh
# session-briefing.sh
# Fires on PreInvocation. Only runs on the first invocation (session start).
# Reads git state and _dev/ task files, then injects a structured briefing
# into the agent's context so you always know exactly where to pick up.

# Read stdin
INPUT=$(cat)

if [ -z "$INPUT" ]; then
  printf '{}\n'
  exit 0
fi

# Parse invocationNum and workspaceRoot
INVOCATION_NUM=""
WORKSPACE_ROOT=""

if command -v python3 >/dev/null 2>&1; then
  eval "$(printf '%s' "$INPUT" | python3 -c '
import sys, json
try:
    data = json.load(sys.stdin)
    inv = data.get("invocationNum", "")
    paths = data.get("workspacePaths", [])
    ws = paths[0] if paths else ""
    print(f"INVOCATION_NUM=\"{inv}\"")
    print(f"WORKSPACE_ROOT=\"{ws}\"")
except Exception:
    pass
')"
elif command -v node >/dev/null 2>&1; then
  eval "$(printf '%s' "$INPUT" | node -e '
let buf = "";
process.stdin.on("data", c => buf += c);
process.stdin.on("end", () => {
  try {
    const data = JSON.parse(buf);
    const inv = data.invocationNum ?? "";
    const ws = (data.workspacePaths && data.workspacePaths[0]) ? data.workspacePaths[0] : "";
    console.log(`INVOCATION_NUM="${inv}"`);
    console.log(`WORKSPACE_ROOT="${ws}"`);
  } catch (e) {}
});
')"
elif command -v jq >/dev/null 2>&1; then
  INVOCATION_NUM=$(printf '%s' "$INPUT" | jq -r '.invocationNum // empty')
  WORKSPACE_ROOT=$(printf '%s' "$INPUT" | jq -r '.workspacePaths[0] // empty')
else
  INVOCATION_NUM=$(printf '%s' "$INPUT" | grep -o '"invocationNum":[ ]*[0-9]*' | sed 's/[^0-9]*//g')
  WORKSPACE_ROOT=$(printf '%s' "$INPUT" | grep -o '"workspacePaths":[ ]*\["[^"]*"' | sed -E 's/.*\["([^"]+)".*/\1/')
fi

# Only fire on the very first invocation of a session
if [ -n "$INVOCATION_NUM" ] && [ "$INVOCATION_NUM" -gt 0 ] 2>/dev/null; then
  printf '{}\n'
  exit 0
fi

if [ -z "$WORKSPACE_ROOT" ] || [ ! -d "$WORKSPACE_ROOT" ]; then
  printf '{}\n'
  exit 0
fi

# 1. GIT STATUS & WORK ITEM DETECTION
GIT_SECTION=""
WORK_ITEM_ID=""

if git -C "$WORKSPACE_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  BRANCH=$(git -C "$WORKSPACE_ROOT" branch --show-current 2>/dev/null | tr -d '\r\n')
  STATUS=$(git -C "$WORKSPACE_ROOT" status --short 2>/dev/null)
  RECENT_LOG=$(git -C "$WORKSPACE_ROOT" log --oneline -5 2>/dev/null)

  STATUS_TEXT="(clean - no uncommitted changes)"
  if [ -n "$STATUS" ]; then
    STATUS_TEXT="$STATUS"
  fi

  LOG_TEXT="(no commits yet)"
  if [ -n "$RECENT_LOG" ]; then
    LOG_TEXT="$RECENT_LOG"
  fi

  # Detect work item ID from branch name (e.g. 10425, 10425-feature, feature/10425-feature)
  WORK_ITEM_ID=$(printf '%s' "$BRANCH" | grep -oE '(^|[/_-])[0-9]{3,8}([/_-]|$)' | grep -oE '[0-9]{3,8}' | head -n 1)

  ADO_HEADER=""
  if [ -n "$WORK_ITEM_ID" ]; then
    ADO_HEADER="
**Azure DevOps Work Item:** AB#$WORK_ITEM_ID"
  fi

  GIT_SECTION="## Git - Branch: \`$BRANCH\`$ADO_HEADER

**Recent commits:**
$LOG_TEXT

**Uncommitted changes:**
$STATUS_TEXT"
else
  GIT_SECTION="## Git
(could not read git state)"
fi

# 2. _dev/ TASK FILES
DEV_SECTION=""
DEV_PATH="$WORKSPACE_ROOT/_dev"

if [ -d "$DEV_PATH" ]; then
  DEV_FILES=$(find "$DEV_PATH" -type f \( -name "*.md" -o -name "*.txt" -o -name "*.yaml" -o -name "*.yml" \) 2>/dev/null)

  if [ -n "$DEV_FILES" ]; then
    PRIORITIZED=""
    OTHERS=""
    SORTED_FILES=$(ls -t $DEV_FILES 2>/dev/null)

    if [ -n "$WORK_ITEM_ID" ]; then
      for f in $SORTED_FILES; do
        fname=$(basename "$f")
        case "$fname" in
          *"$WORK_ITEM_ID"*) PRIORITIZED="$PRIORITIZED $f" ;;
          *) OTHERS="$OTHERS $f" ;;
        esac
      done
      FINAL_FILES="$PRIORITIZED $OTHERS"
    else
      FINAL_FILES="$SORTED_FILES"
    fi

    FILE_LIST=""
    for f in $FINAL_FILES; do
      if [ -f "$f" ]; then
        REL_PATH="${f#$WORKSPACE_ROOT/}"
        FILE_LIST="${FILE_LIST}- \`$REL_PATH\`
"
      fi
    done

    DEV_SECTION="## _dev/ - Active Plans & Tasks

${FILE_LIST}
> Read the most recently modified file(s) above to identify outstanding tasks."
  else
    DEV_SECTION="## _dev/
(folder exists but contains no task files)"
  fi
else
  DEV_SECTION="## _dev/
(no \`_dev/\` folder found in workspace root)"
fi

# 3. ASSEMBLE BRIEFING
ADO_COMMIT_REMINDER=""
if [ -n "$WORK_ITEM_ID" ]; then
  ADO_COMMIT_REMINDER="
- Prepend \`AB#$WORK_ITEM_ID:\` to all git commit messages for this work item."
fi

BRIEFING="---
# Session Briefing

You are starting a new session. Before doing anything else, do the following:

1. Read the git log and uncommitted changes below to understand what was last worked on.
2. Read the most recently modified file(s) in \`_dev/\` to identify the current phase and any open tasks.
3. Produce a **3-point summary** to the user:
   - [Completed] What was just completed (from git log)
   - [In Progress] What is currently in-progress or unfinished (from git status + _dev/ tasks)
   - [Next Action] The single recommended next action to resume flow (be specific - name the file, function, or task)$ADO_COMMIT_REMINDER

Keep the summary concise. Use bullet points. Lead with the next action.

$GIT_SECTION

$DEV_SECTION
---"

# 4. OUTPUT JSON
if command -v python3 >/dev/null 2>&1; then
  python3 -c '
import sys, json
msg = sys.argv[1]
print(json.dumps({"injectSteps": [{"ephemeralMessage": msg}]}))
' "$BRIEFING"
elif command -v node >/dev/null 2>&1; then
  node -e '
const msg = process.argv[1];
console.log(JSON.stringify({injectSteps: [{ephemeralMessage: msg}]}));
' "$BRIEFING"
else
  ESCAPED=$(printf '%s' "$BRIEFING" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | awk '{printf "%s\\n", $0}' | sed 's/\\n$//')
  printf '{"injectSteps":[{"ephemeralMessage":"%s"}]}\n' "$ESCAPED"
fi
