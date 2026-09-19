# adhd-focus-agy

A Google Antigravity plugin that supports ADHD-style working patterns: it re-orients
you at the start of every session and keeps a small set of task-discipline rules
standing in context.

This is the **AGY variant** of the `adhd-focus` plugin — structurally identical,
named for clarity when both variants coexist in the same repo.

## Components

| Component | Path | Purpose |
|---|---|---|
| Hook | `hooks.json` → `scripts/session-briefing.ps1` | On the first model invocation of a session (`PreInvocation`, `invocationNum == 0`), reads git log/status and the most recently modified files under `_dev/`, and injects a structured briefing asking for a 3-point summary (accomplished / in-progress / next action) before anything else happens. |
| Rules | `rules/AGENTS.md` | Standing constraints: reinforces the session-briefing summary format, limits the agent to proposing one next action at a time, and sets working-memory hygiene rules (define new concepts before using them, avoid nested parentheticals, summarize long code blocks). |
| Skill | `skills/unblock/SKILL.md` | Triggers when the user is stuck or doesn't know where to start. Diagnoses the specific blocker, carves out a single 15-minute micro-task with a concrete first step, and states a done condition. |

## Requirements

- The session-briefing hook shells out to `pwsh` (PowerShell 7+). It must be
  installed and on `PATH`. This makes the hook Windows/PowerShell-specific;
  porting `scripts/session-briefing.ps1` to a POSIX shell script would be
  needed to run it on macOS/Linux.
- Git, for the git-log/status section of the briefing (the hook degrades
  gracefully — it emits an empty briefing — if git isn't available or the
  workspace isn't a repo).

## Installation

Copy or clone this directory into wherever Antigravity looks for plugins for
your surface (CLI, IDE, or 2.0), or install it as a workspace-level plugin.
See [antigravity.google/docs/plugins](https://antigravity.google/docs/plugins/)
for the current install paths and CLI plugin-management commands.

## `_dev/` convention

The hook treats a `_dev/` folder at the workspace root as the authoritative
source of current tasks/plans (`.md`, `.txt`, `.yaml`, `.yml` files, most
recently modified first). There's no fixed schema — any task-tracking files
you keep there will be surfaced.

## Roadmap

- Azure DevOps integration: once available, cross-reference work item IDs with
  `_dev/` plan phases in the briefing. Until then, `_dev/` remains the sole
  source of truth (see `rules/AGENTS.md`).
