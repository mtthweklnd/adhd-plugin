# session-briefing.ps1
# Fires on PreInvocation. Only runs on the first invocation (session start).
# Reads git state and _dev/ task files, then injects a structured briefing
# into the agent's context so you always know exactly where to pick up.

$input_json = $null
try {
    $raw = [Console]::In.ReadToEnd()
    $input_json = $raw | ConvertFrom-Json
} catch {
    # If we can't parse stdin, bail silently (output empty object)
    Write-Output '{}'
    exit 0
}

# Only fire on the very first invocation of a session
$invocationNum = $input_json.invocationNum
if ($null -ne $invocationNum -and $invocationNum -gt 0) {
    Write-Output '{}'
    exit 0
}

# Resolve workspace root (first path in workspacePaths)
$workspacePaths = $input_json.workspacePaths
$workspaceRoot = $null
if ($workspacePaths -and $workspacePaths.Count -gt 0) {
    $workspaceRoot = $workspacePaths[0]
}

if (-not $workspaceRoot -or -not (Test-Path $workspaceRoot)) {
    Write-Output '{}'
    exit 0
}

# ── 1. GIT STATUS ──────────────────────────────────────────────────────────────
$gitSection = ""
try {
    $isGitRepo = & git -C $workspaceRoot rev-parse --is-inside-work-tree 2>&1
    if ($LASTEXITCODE -eq 0) {
        $branch    = & git -C $workspaceRoot branch --show-current 2>&1
        $status    = & git -C $workspaceRoot status --short 2>&1
        $recentLog = & git -C $workspaceRoot log --oneline -5 2>&1

        $statusText = if ($status) { ($status | Out-String).Trim() } else { "(clean — no uncommitted changes)" }
        $logText    = if ($recentLog) { ($recentLog | Out-String).Trim() } else { "(no commits yet)" }

        $gitSection = @"
## 🔀 Git — Branch: ``$branch``

**Recent commits:**
$logText

**Uncommitted changes:**
$statusText
"@
    }
} catch {
    $gitSection = "## 🔀 Git`n(could not read git state)"
}

# ── 2. _dev/ TASK FILES ────────────────────────────────────────────────────────
$devSection = ""
$devPath = Join-Path $workspaceRoot "_dev"

if (Test-Path $devPath) {
    $devFiles = Get-ChildItem -Path $devPath -Recurse -Include "*.md","*.txt","*.yaml","*.yml" |
                Sort-Object LastWriteTime -Descending

    if ($devFiles.Count -gt 0) {
        $fileList = $devFiles | ForEach-Object {
            $relativePath = $_.FullName.Substring($workspaceRoot.Length).TrimStart('\','/')
            "- ``$relativePath`` (modified $($_.LastWriteTime.ToString('yyyy-MM-dd HH:mm')))"
        }
        $devSection = @"
## 📋 _dev/ — Active Plans & Tasks

$($fileList -join "`n")

> Read the most recently modified file(s) above to identify outstanding tasks.
"@
    } else {
        $devSection = "## 📋 _dev/`n(folder exists but contains no task files)"
    }
} else {
    $devSection = "## 📋 _dev/`n(no ``_dev/`` folder found in workspace root)"
}

# ── 3. ASSEMBLE BRIEFING ───────────────────────────────────────────────────────
$briefing = @"
---
# 🧠 Session Briefing

You are starting a new session. Before doing anything else, do the following:

1. Read the git log and uncommitted changes below to understand what was last worked on.
2. Read the most recently modified file(s) in ``_dev/`` to identify the current phase and any open tasks.
3. Produce a **3-point summary** to the user:
   - ✅ **What was just accomplished** (from git log)
   - 🔧 **What is currently in-progress or unfinished** (from git status + _dev/ tasks)
   - ▶️  **The single recommended next action** to resume flow (be specific — name the file, function, or task)

Keep the summary concise. Use bullet points. Lead with the next action.

$gitSection

$devSection
---
"@

# ── 4. OUTPUT ─────────────────────────────────────────────────────────────────
$output = @{
    injectSteps = @(
        @{
            ephemeralMessage = $briefing
        }
    )
}

$output | ConvertTo-Json -Depth 5 -Compress
