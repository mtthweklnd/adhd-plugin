#!/bin/sh
# session-briefing.sh
# Polyglot hook script for Google Antigravity (AGY) and Claude Code (CC).
#
# AGY  — fires on PreInvocation; stdin JSON has invocationNum + workspacePaths.
#         Emits { injectSteps: [ { ephemeralMessage: <text> } ] }.
# CC   — fires on SessionStart; stdin JSON has hook_event_name + cwd.
#         Emits plain stdout text (markdown).
# Fallback (no recognizable keys / empty stdin) — treats as CC, emits plain stdout.

# 1. READ STDIN (empty stdin is fine — fallback to CC path)
INPUT=$(cat 2>/dev/null || true)

# 2. PARSE JSON FIELDS
INVOCATION_NUM=""
WORKSPACE_PATHS_0=""
CWD_FIELD=""
HOOK_EVENT_NAME=""

_parse_json() {
    if command -v python3 >/dev/null 2>&1; then
        eval "$(printf '%s' "$INPUT" | python3 -c '
import sys, json
try:
    data = json.load(sys.stdin)
    inv = data.get("invocationNum", "")
    paths = data.get("workspacePaths", [])
    ws = paths[0] if paths else ""
    cwd = data.get("cwd", "")
    hen = data.get("hook_event_name", "")
    print("INVOCATION_NUM=\"{}\"".format(str(inv)))
    print("WORKSPACE_PATHS_0=\"{}\"".format(ws))
    print("CWD_FIELD=\"{}\"".format(cwd))
    print("HOOK_EVENT_NAME=\"{}\"".format(hen))
except Exception:
    pass
' 2>/dev/null)"
    elif command -v node >/dev/null 2>&1; then
        eval "$(printf '%s' "$INPUT" | node -e '
let buf = "";
process.stdin.on("data", c => buf += c);
process.stdin.on("end", () => {
  try {
    const d = JSON.parse(buf);
    const inv = d.invocationNum != null ? d.invocationNum : "";
    const ws = (d.workspacePaths && d.workspacePaths[0]) ? d.workspacePaths[0] : "";
    const cwd = d.cwd || "";
    const hen = d.hook_event_name || "";
    console.log("INVOCATION_NUM=\"" + inv + "\"");
    console.log("WORKSPACE_PATHS_0=\"" + ws + "\"");
    console.log("CWD_FIELD=\"" + cwd + "\"");
    console.log("HOOK_EVENT_NAME=\"" + hen + "\"");
  } catch(e) {}
});
' 2>/dev/null)"
    elif command -v jq >/dev/null 2>&1; then
        INVOCATION_NUM=$(printf '%s' "$INPUT" | jq -r '.invocationNum // empty' 2>/dev/null)
        WORKSPACE_PATHS_0=$(printf '%s' "$INPUT" | jq -r '.workspacePaths[0] // empty' 2>/dev/null)
        CWD_FIELD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)
        HOOK_EVENT_NAME=$(printf '%s' "$INPUT" | jq -r '.hook_event_name // empty' 2>/dev/null)
    else
        # Fallback regex extraction
        INVOCATION_NUM=$(printf '%s' "$INPUT" | grep -o '"invocationNum":[ ]*[0-9]*' | grep -o '[0-9]*' | head -n 1)
        WORKSPACE_PATHS_0=$(printf '%s' "$INPUT" | grep -o '"workspacePaths":[ ]*\["[^"]*"' | sed -E 's/.*\["([^"]+)".*/\1/' | head -n 1)
        CWD_FIELD=$(printf '%s' "$INPUT" | grep -o '"cwd":[ ]*"[^"]*"' | sed -E 's/.*"cwd":[ ]*"([^"]+)".*/\1/' | head -n 1)
        HOOK_EVENT_NAME=$(printf '%s' "$INPUT" | grep -o '"hook_event_name":[ ]*"[^"]*"' | sed -E 's/.*"hook_event_name":[ ]*"([^"]+)".*/\1/' | head -n 1)
    fi
}

if [ -n "$INPUT" ]; then
    _parse_json
fi

# 3. PLATFORM DETECTION
IS_AGY=0
if [ -n "$INVOCATION_NUM" ] || [ -n "$WORKSPACE_PATHS_0" ]; then
    IS_AGY=1
fi
# CC: hook_event_name / cwd present, or no recognizable keys (IS_AGY stays 0)

# 4. AGY: SKIP FOLLOW-UP TURNS
if [ "$IS_AGY" = "1" ]; then
    if [ -n "$INVOCATION_NUM" ] && [ "$INVOCATION_NUM" -gt 0 ] 2>/dev/null; then
        printf '{}\n'
        exit 0
    fi
fi

# 5. RESOLVE WORKSPACE ROOT
WORKSPACE_ROOT=""
if [ "$IS_AGY" = "1" ] && [ -n "$WORKSPACE_PATHS_0" ] && [ -d "$WORKSPACE_PATHS_0" ]; then
    WORKSPACE_ROOT="$WORKSPACE_PATHS_0"
elif [ -n "$CWD_FIELD" ] && [ -d "$CWD_FIELD" ]; then
    WORKSPACE_ROOT="$CWD_FIELD"
else
    WORKSPACE_ROOT="$PWD"
fi

# 6. GIT STATE & WORK ITEM DETECTION
GIT_SECTION=""
WORK_ITEM_ID=""

if git -C "$WORKSPACE_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    BRANCH=$(git -C "$WORKSPACE_ROOT" branch --show-current 2>/dev/null | tr -d '\r\n')
    STATUS=$(git -C "$WORKSPACE_ROOT" status --short 2>/dev/null)
    RECENT_LOG=$(git -C "$WORKSPACE_ROOT" log --oneline -5 2>/dev/null)

    STATUS_TEXT="(clean - no uncommitted changes)"
    [ -n "$STATUS" ] && STATUS_TEXT="$STATUS"

    LOG_TEXT="(no commits yet)"
    [ -n "$RECENT_LOG" ] && LOG_TEXT="$RECENT_LOG"

    WORK_ITEM_ID=$(printf '%s' "$BRANCH" | grep -oE '(^|[/_-])[0-9]{3,8}([/_-]|$)' | grep -oE '[0-9]{3,8}' | head -n 1)

    ADO_HEADER=""
    [ -n "$WORK_ITEM_ID" ] && ADO_HEADER="
**Azure DevOps Work Item:** AB#$WORK_ITEM_ID"

    GIT_SECTION="## Git - Branch: \`$BRANCH\`$ADO_HEADER

**Recent commits:**
$LOG_TEXT

**Uncommitted changes:**
$STATUS_TEXT"
else
    GIT_SECTION="## Git
(could not read git state)"
fi

# 7. _dev/ TASK FILES
DEV_SECTION=""
DEV_PATH="$WORKSPACE_ROOT/_dev"

if [ -d "$DEV_PATH" ]; then
    FILE_LIST=""
    if command -v python3 >/dev/null 2>&1; then
        FILE_LIST=$(python3 - "$DEV_PATH" "$WORK_ITEM_ID" <<'PYEOF'
import os, sys
dev_path = sys.argv[1]
work_item = sys.argv[2] if len(sys.argv) > 2 else ""
exts = (".md", ".txt", ".yaml", ".yml")
items = []
for root, _, files in os.walk(dev_path):
    for f in files:
        if f.endswith(exts):
            p = os.path.join(root, f)
            try:
                mtime = os.path.getmtime(p)
                rel = "_dev/" + os.path.relpath(p, dev_path).replace("\\", "/")
                items.append((mtime, rel))
            except OSError:
                pass
items.sort(key=lambda x: x[0], reverse=True)
all_items = [rel for _, rel in items]
if work_item:
    prio = [rel for rel in all_items if work_item in os.path.basename(rel)]
    rest = [rel for rel in all_items if work_item not in os.path.basename(rel)]
    all_items = prio + rest
for rel in all_items:
    print("- `{}`".format(rel))
PYEOF
)
    elif command -v node >/dev/null 2>&1; then
        FILE_LIST=$(node -e '
const fs = require("fs"), path = require("path");
const devPath = process.argv[1], workItem = process.argv[2] || "";
const exts = [".md", ".txt", ".yaml", ".yml"];
function walk(dir) {
  let res = [];
  try {
    for (const d of fs.readdirSync(dir, { withFileTypes: true })) {
      const full = path.join(dir, d.name);
      if (d.isDirectory()) res = res.concat(walk(full));
      else if (d.isFile() && exts.some(e => d.name.endsWith(e))) {
        try { const m = fs.statSync(full).mtimeMs; res.push({ rel: "_dev/" + path.relative(devPath, full).replace(/\\/g, "/"), m }); } catch {}
      }
    }
  } catch {}
  return res;
}
let items = walk(devPath).sort((a, b) => b.m - a.m).map(x => x.rel);
if (workItem) { const p = items.filter(r => path.basename(r).includes(workItem)); const rest = items.filter(r => !path.basename(r).includes(workItem)); items = p.concat(rest); }
items.forEach(r => console.log("- \`" + r + "\`"));
' "$DEV_PATH" "$WORK_ITEM_ID" 2>/dev/null)
    else
        FILE_LIST=$(find "$DEV_PATH" -type f \( -name "*.md" -o -name "*.txt" -o -name "*.yaml" -o -name "*.yml" \) 2>/dev/null | while IFS= read -r f; do
            rel="_dev/${f#$DEV_PATH/}"
            printf '- `%s`\n' "$rel"
        done)
    fi

    if [ -n "$FILE_LIST" ]; then
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

# 8. STANDING RULES (from rules/AGENTS.md)
RULES_SECTION=""
SCRIPT_DIR=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
if [ -n "$SCRIPT_DIR" ]; then
    AGENTS_PATH="$(dirname "$SCRIPT_DIR")/rules/AGENTS.md"
    if [ -f "$AGENTS_PATH" ]; then
        RULES_CONTENT=$(cat "$AGENTS_PATH")
        RULES_SECTION="
--- Standing Rules ---
$RULES_CONTENT"
    fi
fi

# 9. ASSEMBLE BRIEFING
ADO_COMMIT_REMINDER=""
[ -n "$WORK_ITEM_ID" ] && ADO_COMMIT_REMINDER="
   - Prepend \`AB#$WORK_ITEM_ID:\` to all git commit messages for this work item."

BRIEFING="---
# Session Briefing

You are starting a new session. Before doing anything else:

1. Read the git log and uncommitted changes below to understand what was last worked on.
2. Read the most recently modified file(s) in \`_dev/\` to identify the current phase and open tasks.
3. Produce a **3-point summary** to the user (lead with the next action):
   - [Next Action] The single recommended next action to resume flow (name the file, function, or task)$ADO_COMMIT_REMINDER
   - [Completed] What was just completed (from git log)
   - [In Progress] What is currently in-progress or unfinished (from git status + _dev/ tasks)

Keep the summary concise. Use bullet points. Lead with the next action.

$GIT_SECTION

$DEV_SECTION
$RULES_SECTION
---"

# 10. EMIT OUTPUT
if [ "$IS_AGY" = "1" ]; then
    if command -v python3 >/dev/null 2>&1; then
        printf '%s' "$BRIEFING" | python3 -c '
import sys, json
msg = sys.stdin.read()
print(json.dumps({"injectSteps": [{"ephemeralMessage": msg}]}))
'
    elif command -v node >/dev/null 2>&1; then
        printf '%s' "$BRIEFING" | node -e '
let buf = "";
process.stdin.on("data", c => buf += c);
process.stdin.on("end", () => {
  console.log(JSON.stringify({injectSteps: [{ephemeralMessage: buf}]}));
});
'
    else
        # No JSON serializer available — emit plain text as safe fallback
        printf '%s\n' "$BRIEFING"
    fi
else
    printf '%s\n' "$BRIEFING"
fi
