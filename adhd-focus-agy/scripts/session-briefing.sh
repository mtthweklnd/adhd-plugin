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
  FILE_LIST=""
  if command -v python3 >/dev/null 2>&1; then
    FILE_LIST=$(python3 -c '
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
    print(f"- `{rel}`")
' "$DEV_PATH" "$WORK_ITEM_ID")
  elif command -v node >/dev/null 2>&1; then
    FILE_LIST=$(node -e '
const fs = require("fs");
const path = require("path");
const devPath = process.argv[1];
const workItem = process.argv[2] || "";
const exts = [".md", ".txt", ".yaml", ".yml"];
function walk(dir) {
  let res = [];
  try {
    for (const d of fs.readdirSync(dir, { withFileTypes: true })) {
      const full = path.join(dir, d.name);
      if (d.isDirectory()) res = res.concat(walk(full));
      else if (d.isFile() && exts.some(e => d.name.endsWith(e))) {
        try {
          const m = fs.statSync(full).mtimeMs;
          const rel = "_dev/" + path.relative(devPath, full).replace(/\\/g, "/");
          res.push({ rel, m });
        } catch {}
      }
    }
  } catch {}
  return res;
}
const items = walk(devPath).sort((a, b) => b.m - a.m).map(x => x.rel);
let sorted = items;
if (workItem) {
  const prio = items.filter(rel => path.basename(rel).includes(workItem));
  const rest = items.filter(rel => !path.basename(rel).includes(workItem));
  sorted = prio.concat(rest);
}
sorted.forEach(rel => console.log(`- \`${rel}\``));
' "$DEV_PATH" "$WORK_ITEM_ID")
  else
    RAW_FILES=$(find "$DEV_PATH" -type f \( -name "*.md" -o -name "*.txt" -o -name "*.yaml" -o -name "*.yml" \) -printf '%T@ %p\n' 2>/dev/null | sort -rn | cut -d' ' -f2-)
    if [ -z "$RAW_FILES" ]; then
      RAW_FILES=$(find "$DEV_PATH" -type f \( -name "*.md" -o -name "*.txt" -o -name "*.yaml" -o -name "*.yml" \) -exec stat -f "%m %N" {} + 2>/dev/null | sort -rn | cut -d' ' -f2-)
    fi
    PRIO=""
    REST=""
    NL='
'
    printf '%s\n' "$RAW_FILES" | while IFS= read -r f; do
      [ -z "$f" ] && continue
      rel="_dev/${f#$DEV_PATH/}"
      line="- \`$rel\`"
      if [ -n "$WORK_ITEM_ID" ] && echo "$rel" | grep -q "$WORK_ITEM_ID"; then
        PRIO="$PRIO$line$NL"
      else
        REST="$REST$line$NL"
      fi
    done
    FILE_LIST="$PRIO$REST"
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
3. Produce a **3-point summary** to the user (lead with the next action):
   - [Next Action] The single recommended next action to resume flow (be specific - name the file, function, or task)$ADO_COMMIT_REMINDER
   - [Completed] What was just completed (from git log)
   - [In Progress] What is currently in-progress or unfinished (from git status + _dev/ tasks)

Keep the summary concise. Use bullet points. Lead with the next action.

$GIT_SECTION

$DEV_SECTION
---"

# 4. OUTPUT JSON
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
  # If no reliable JSON serializer is available, bail safely with an empty response
  printf '{}\n'
  exit 0
fi
