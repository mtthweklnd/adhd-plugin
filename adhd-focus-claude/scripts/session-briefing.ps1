# session-briefing.ps1
# Fires on PreInvocation. Only runs on the first invocation (session start).
# Reads git state and _dev/ task files, then injects a structured briefing
# into the agent's context so you always know exactly where to pick up.

$input_json = $null
try {
    $raw = [Console]::In.ReadToEnd()
    if ($raw) {
        $input_json = $raw | ConvertFrom-Json
    }
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

# 1. GIT STATUS & WORK ITEM DETECTION
$gitSection = ""
$workItemId = $null

try {
    $isGitRepo = & git -C $workspaceRoot rev-parse --is-inside-work-tree 2>&1
    if ($LASTEXITCODE -eq 0) {
        $branch    = (& git -C $workspaceRoot branch --show-current 2>&1).Trim()
        $status    = & git -C $workspaceRoot status --short 2>&1
        $recentLog = & git -C $workspaceRoot log --oneline -5 2>&1

        $statusText = if ($status) { ($status | Out-String).Trim() } else { "(clean - no uncommitted changes)" }
        $logText    = if ($recentLog) { ($recentLog | Out-String).Trim() } else { "(no commits yet)" }

        # Detect work item ID from branch name (e.g. 10425, 10425-feature, feature/10425-feature)
        if ($branch -match '(?:^|[/_-])(\d{3,8})(?:[/_-]|$)') {
            $workItemId = $matches[1]
        }

        $adoHeader = if ($workItemId) { "`n**Azure DevOps Work Item:** AB#$workItemId" } else { "" }

        $gitSection = @"
## Git - Branch: ``$branch``$adoHeader

**Recent commits:**
$logText

**Uncommitted changes:**
$statusText
"@
    }
} catch {
    $gitSection = "## Git`n(could not read git state)"
}

# 2. _dev/ TASK FILES
$devSection = ""
$devPath = Join-Path $workspaceRoot "_dev"

if (Test-Path $devPath) {
    $allDevFiles = Get-ChildItem -Path $devPath -Recurse -Include "*.md","*.txt","*.yaml","*.yml"

    if ($allDevFiles.Count -gt 0) {
        # Prioritize work item files if work item ID was detected
        $sortedFiles = if ($workItemId) {
            $matching = $allDevFiles | Where-Object { $_.Name -match "\b$workItemId\b" } | Sort-Object LastWriteTime -Descending
            $others   = $allDevFiles | Where-Object { $_.Name -notmatch "\b$workItemId\b" } | Sort-Object LastWriteTime -Descending
            @($matching) + @($others)
        } else {
            $allDevFiles | Sort-Object LastWriteTime -Descending
        }

        $fileList = $sortedFiles | ForEach-Object {
            $relativePath = $_.FullName.Substring($workspaceRoot.Length).TrimStart('\','/')
            "- ``$relativePath`` (modified $($_.LastWriteTime.ToString('yyyy-MM-dd HH:mm')))"
        }
        $devSection = @"
## _dev/ - Active Plans & Tasks

$($fileList -join "`n")

> Read the most recently modified file(s) above to identify outstanding tasks.
"@
    } else {
        $devSection = "## _dev/`n(folder exists but contains no task files)"
    }
} else {
    $devSection = "## _dev/`n(no ``_dev/`` folder found in workspace root)"
}

# 3. ASSEMBLE BRIEFING
$adoCommitReminder = if ($workItemId) {
    "`n- Prepend ``AB#${workItemId}:`` to all git commit messages for this work item."
} else {
    ""
}

$briefing = @"
---
# Session Briefing

You are starting a new session. Before doing anything else, do the following:

1. Read the git log and uncommitted changes below to understand what was last worked on.
2. Read the most recently modified file(s) in ``_dev/`` to identify the current phase and any open tasks.
3. Produce a **3-point summary** to the user:
   - [Completed] What was just completed (from git log)
   - [In Progress] What is currently in-progress or unfinished (from git status + _dev/ tasks)
   - [Next Action] The single recommended next action to resume flow (be specific - name the file, function, or task)$adoCommitReminder

Keep the summary concise. Use bullet points. Lead with the next action.

$gitSection

$devSection
---
"@

# 4. OUTPUT
$output = @{
    injectSteps = @(
        @{
            ephemeralMessage = $briefing
        }
    )
}

$output | ConvertTo-Json -Depth 5 -Compress
