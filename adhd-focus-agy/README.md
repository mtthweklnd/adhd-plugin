# adhd-focus-agy

A Google Antigravity plugin that supports ADHD-style working patterns: it re-orients
you at the start of every session and keeps a small set of task-discipline rules
standing in context.

This is the **AGY variant** of the `adhd-focus` plugin - structurally identical,
named for clarity when both variants coexist in the same repo.

## Components

| Component | Path | Purpose |
|---|---|---|
| Hook | `hooks.json` / `scripts/session-briefing.ps1` (PowerShell) / `scripts/session-briefing.sh` (POSIX sh) | On the first model invocation of a session (`PreInvocation`, `invocationNum == 0`), reads git log, branch, uncommitted status, and active tasks under `_dev/`. Detects Azure DevOps work items from the branch, reminds the agent to format commits (`AB#<id>:`), and injects a briefing requiring a 3-point summary (`[Next Action]`, `[Completed]`, `[In Progress]`). |
| Rules | `rules/AGENTS.md` | Standing constraints: zero-emoji mandate, reinforces the 3-point summary format, enforces the single living document pattern with in-line `[Discovered]` tasks, establishes Azure DevOps commit hygiene (`AB#<id>:`), and sets working-memory hygiene rules. |
| Skill | `skills/unblock/SKILL.md` | Triggers when the user is stuck or doesn't know where to start. Diagnoses the specific blocker, carves out a single 15-minute micro-task with a concrete first step, and states clear completion conditions. |
| Skill | `skills/micro-plan/SKILL.md` | Scaffolds and manages ADHD-friendly living task documents in `_dev/<id>-<slug>.md` with a 5-minute warm-up entry point, linear Task List, Acceptance Criteria, and a Roadmap section for deferred scope. |

## Requirements

- **Windows**: PowerShell 7+ (`pwsh`) on `PATH` to run `scripts/session-briefing.ps1`.
- **macOS / Linux**: Standard POSIX shell (`sh`) to run `scripts/session-briefing.sh`.
- **Git**: For branch inspection, commit logs, and status checks (gracefully falls back if not in a repository).

## Installation

Copy or clone this directory into wherever Antigravity looks for plugins for
your surface (CLI, IDE, or 2.0), or install it as a workspace-level plugin.
See [antigravity.google/docs/plugins](https://antigravity.google/docs/plugins/)
for the current install paths and CLI plugin-management commands.

### Platform Hook Configuration

By default, `hooks.json` is configured for Windows using PowerShell:

```json
{
  "session-briefing": {
    "PreInvocation": [
      {
        "type": "command",
        "command": "pwsh -NoProfile -NonInteractive -File scripts/session-briefing.ps1",
        "timeout": 15
      }
    ]
  }
}
```

On Linux or macOS environments without `pwsh`, update the command in `hooks.json` to use the POSIX shell script:

```json
"command": "sh scripts/session-briefing.sh"
```

## Azure DevOps Integration & Commit Hygiene

- **Branch Work Item Sniffer**: The session briefing automatically parses work item IDs from branch names matching patterns like `10425`, `10425-feature`, `feature/10425-login`, or `bugfix/10425_auth`.
- **Commit Tagging**: When a work item ID is detected, the agent is instructed to prepend `AB#<id>:` to all suggested commit messages (e.g., `git commit -m "AB#10425: add input validation"`).
- **Task Prioritization**: Files in `_dev/` matching the detected work item ID are automatically placed at the top of the active task list in the briefing.

## Single Living Document Pattern (`_dev/`)

The plugin organizes work into single living documents located in `_dev/` (e.g. `_dev/10425-user-auth.md`):

- **No Fragmentation**: Never create separate, detached plan files when intermediate steps or edge cases appear.
- **In-line Discovered Tasks**: When unexpected blockers or sub-tasks arise during execution, slot them directly under the active step in the Task List marked as `[Discovered]`.
- **Standard Terminology**:
  - **Acceptance Criteria**: Verifiable requirements defining when the work item is complete.
  - **Task List**: Linear, numbered execution steps with a 5-minute warm-up entry point.
  - **Roadmap**: Captures out-of-scope ideas and future enhancements so current focus remains protected.

## Roadmap

- Direct Azure DevOps REST API integration for syncing work item state and comments directly from the agent.
