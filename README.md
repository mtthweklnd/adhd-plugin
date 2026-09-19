# adhd-focus

Session-start briefing and focus-support tooling for ADHD-style working patterns. Works on both **Google Antigravity** and **Claude Code** from a single repository.

## What it does

- Injects a git-state briefing at the start of every session: recent commits, uncommitted changes, and `_dev/` task files.
- Emits a 3-point summary template: next action, completed, in-progress.
- Detects Azure DevOps work item IDs from branch names and reminds the model to prepend `AB#<id>:` to commits.
- Loads standing rules (no emojis, single-living-document pattern, AST hygiene) through the session briefing.
- Provides four skills: `micro-plan`, `simplify`, `trace-workflow`, `unblock`.

## Repository layout

```
adhd-focus/
├── plugin.json                   AGY manifest
├── hooks.json                    AGY PreInvocation hook
├── .claude-plugin/
│   └── plugin.json               Claude Code manifest
├── hooks/
│   └── hooks.json                Claude Code SessionStart hook
├── rules/
│   └── AGENTS.md                 Shared standing rules
├── skills/
│   ├── micro-plan/SKILL.md
│   ├── simplify/SKILL.md
│   ├── trace-workflow/SKILL.md
│   └── unblock/SKILL.md
└── scripts/
    ├── session-briefing.ps1      Polyglot briefing script (Windows/cross-platform)
    └── session-briefing.sh       Polyglot briefing script (POSIX)
```

## Installation

### Google Antigravity

AGY requires the plugin to live inside a `plugins/<name>/` directory under a customization root. The entire repo is the plugin folder — clone or copy it to the right path.

**Project-level (`.agents/plugins/`):**
```sh
git clone <repo-url> .agents/plugins/adhd-focus
```

**Global (user-wide, Gemini 2.0+):**
```sh
git clone <repo-url> ~/.gemini/config/plugins/adhd-focus
```

The AGY hook (`hooks.json`) fires `session-briefing.ps1` on first invocation of each session. On macOS/Linux, swap the hook command to `sh scripts/session-briefing.sh` in `hooks.json`.

### Claude Code

**Via CLI (recommended):**
```sh
claude plugin install <repo-url>
```

**Manual:**
Clone the repo and place it in your Claude Code plugins directory, or add it to your project's `.claude/plugins/` path. Claude Code reads `.claude-plugin/plugin.json` and `hooks/hooks.json`.

The CC hook fires `session-briefing.ps1` on `SessionStart` using `${CLAUDE_PLUGIN_ROOT}` so the path resolves correctly regardless of where the plugin is installed.

On macOS/Linux with CC, update `hooks/hooks.json` to call `session-briefing.sh` instead:
```json
"command": "sh \"${CLAUDE_PLUGIN_ROOT}/scripts/session-briefing.sh\""
```

## Polyglot briefing script

`scripts/session-briefing.ps1` (and `.sh`) detects which platform invoked it by inspecting the stdin JSON:

| Field present in stdin | Platform | Output |
|---|---|---|
| `invocationNum` or `workspacePaths` | Antigravity | JSON: `{ "injectSteps": [{ "ephemeralMessage": "..." }] }` |
| `hook_event_name` or `cwd` | Claude Code | Plain stdout text (markdown) |
| Empty / unrecognized | Fallback (manual run) | Plain stdout text (markdown) |

AGY skips briefing on follow-up turns (`invocationNum > 0`). Claude Code fires once per `SessionStart`.

Workspace root is resolved from `workspacePaths[0]` (AGY), `cwd` (CC), or `$PWD` (fallback).

## Skills

| Skill | Trigger |
|---|---|
| `micro-plan` | `/micro-plan`, `/plan`, "break this down", AB# work item |
| `simplify` | "simplify this", "reduce cognitive load", "make this cleaner" |
| `trace-workflow` | "trace this workflow", "flatten this call chain", "too many function hops" |
| `unblock` | "I'm stuck", "unblock me", "I don't know where to start" |

## Standing rules

`rules/AGENTS.md` defines the working contract injected at session start:

- No emojis.
- 3-point session summary (next action / completed / in-progress).
- Single living document in `_dev/`.
- `AB#<id>:` prefix on commits when a work item is active.
- Max 2-level call chains and indentation depth.
