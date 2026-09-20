> **Archived — superseded.** This plan shipped in commit `1658b4b` ("unify dual-platform plugin and add simplify & trace-workflow skills"). The `adhd-focus-agy` / `adhd-focus-claude` subfolders it describes no longer exist; the repo root is the unified layout. Kept for history only.

# Implementation Plan: Unify Antigravity and Claude Code Plugins into a Single Dual-Target Plugin

Combine `adhd-focus-agy` and `adhd-focus-claude` into a single, unified plugin package (`adhd-focus`) that works out-of-the-box on both **Google Antigravity** and **Claude Code** without duplicating skills, rules, or briefing logic.

---

## User Review Required

> [!IMPORTANT]
> **Repository Layout Consolidation**:
> Currently, the repository contains two duplicate subfolders (`adhd-focus-agy` and `adhd-focus-claude`). We propose restructuring the repository so the **repository root itself** is the unified plugin package:
>
> - Antigravity installs directly from the root (`./plugin.json`, `./hooks.json`).
> - Claude Code installs directly from the root (`./.claude-plugin/plugin.json`, `./hooks/hooks.json`).
> - The duplicate subfolders `adhd-focus-agy/` and `adhd-focus-claude/` will be removed once migrated.
>
> If you prefer keeping the plugin inside a dedicated subfolder (e.g. `adhd-focus/`), please let us know. The root layout is recommended because CLI installers (`claude plugin install <git-url>` and `agy plugin install <git-url>`) look at repository root by default.

---

## Architecture & Compatibility Strategy

| Component | Antigravity Location | Claude Code Location | Unified Strategy |
|---|---|---|---|
| **Manifest** | `plugin.json` (root) | `.claude-plugin/plugin.json` | Both files coexist at root without collision. Claude Code ignores root `plugin.json`; Antigravity ignores `.claude-plugin/`. |
| **Lifecycle Hooks** | `hooks.json` (root, `PreInvocation`) | `hooks/hooks.json` (`SessionStart`) | Both files coexist. Each platform reads only its own configuration. |
| **Skills** | `skills/<name>/SKILL.md` | `skills/<name>/SKILL.md` | Identical format (YAML frontmatter + Markdown). Shared with zero duplication. |
| **Rules** | `rules/AGENTS.md` | `rules/AGENTS.md` / `AGENTS.md` | Identical standard. Claude Code natively supports `AGENTS.md`. |
| **Briefing Scripts** | `scripts/session-briefing.ps1` / `.sh` | `scripts/session-briefing.ps1` / `.sh` | Polyglot script logic: detects whether caller is Antigravity (`injectSteps` JSON) or Claude Code (stdout text). |

---

## Proposed Changes

### 1. Plugin Manifests

#### [NEW] [plugin.json](file:///c:/Users/matt/Projects/adhd-plugin/plugin.json)
Create the Antigravity plugin manifest at the root:
```json
{
  "$schema": "https://antigravity.google/schemas/v1/plugin.json",
  "name": "adhd-focus",
  "description": "Session-start briefing and focus-support tooling for ADHD-style working patterns: git/task session recap, standing task-discipline and AST hygiene rules, and skills for unblocking, living task plans, code simplification, and workflow tracing."
}
```

#### [NEW] [.claude-plugin/plugin.json](file:///c:/Users/matt/Projects/adhd-plugin/.claude-plugin/plugin.json)
Create the Claude Code manifest inside `.claude-plugin/`:
```json
{
  "name": "adhd-focus",
  "version": "0.2.0",
  "description": "Session-start briefing and focus-support tooling for ADHD-style working patterns: git/task session recap, standing task-discipline and AST hygiene rules, and skills for unblocking, living task plans, code simplification, and workflow tracing."
}
```

---

### 2. Lifecycle Hooks

#### [NEW] [hooks.json](file:///c:/Users/matt/Projects/adhd-plugin/hooks.json)
Create Antigravity lifecycle hook at root:
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

#### [NEW] [hooks/hooks.json](file:///c:/Users/matt/Projects/adhd-plugin/hooks/hooks.json)
Create Claude Code lifecycle hook:
```json
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "pwsh -NoProfile -NonInteractive -File \"${CLAUDE_PLUGIN_ROOT}/scripts/session-briefing.ps1\"",
            "timeout": 15
          }
        ]
      }
    ]
  }
}
```

---

### 3. Rules & Skills

#### [NEW] [rules/AGENTS.md](file:///c:/Users/matt/Projects/adhd-plugin/rules/AGENTS.md)
Move/copy the shared `rules/AGENTS.md` to root:
* Preserves zero-emoji rule, 3-point summary, ADO commit tagging, single living document pattern, and AST hygiene rules.

#### [NEW] [skills/](file:///c:/Users/matt/Projects/adhd-plugin/skills/)
Move/copy all 4 skills to root `skills/`:
* `skills/micro-plan/SKILL.md`
* `skills/simplify/SKILL.md`
* `skills/trace-workflow/SKILL.md`
* `skills/unblock/SKILL.md`

---

### 4. Polyglot Briefing Scripts

#### [NEW] [scripts/session-briefing.ps1](file:///c:/Users/matt/Projects/adhd-plugin/scripts/session-briefing.ps1)
Upgrade PowerShell briefing script to detect caller environment:
1. **Workspace Root Detection**: Check `$input_json.workspacePaths[0]`, `$input_json.cwd`, and fall back to `$PWD.Path`.
2. **Platform Sniffing**:
   * If `$input_json.invocationNum` or `$input_json.workspacePaths` is present, it's Antigravity. Check `$invocationNum -gt 0` to exit early on follow-up turns, and emit `{ "injectSteps": [ { "ephemeralMessage": $briefing } ] }`.
   * Otherwise (Claude Code `SessionStart` or manual execution), emit raw text directly to stdout.

#### [NEW] [scripts/session-briefing.sh](file:///c:/Users/matt/Projects/adhd-plugin/scripts/session-briefing.sh)
Upgrade POSIX shell script with matching dual-output logic:
1. Parse JSON if `python3`, `node`, or `jq` is available; support `INVOCATION_NUM`, `WORKSPACE_PATHS`, and `CWD`.
2. Emit Antigravity JSON when `INVOCATION_NUM` or `WORKSPACE_PATHS` is detected; emit raw markdown when invoked by Claude Code (`SessionStart`) or interactive CLI.

---

### 5. Documentation & Cleanup

#### [NEW] [README.md](file:///c:/Users/matt/Projects/adhd-plugin/README.md)
Write unified documentation covering:
* Purpose & components.
* Installation instructions for **Google Antigravity** (CLI, IDE, 2.0).
* Installation instructions for **Claude Code** (`claude plugin install`).
* Windows (`pwsh`) and macOS/Linux (`sh`) hook switching guide.
* Work item detection and `_dev/` living document workflow.

#### [DELETE] `adhd-focus-agy/` and `adhd-focus-claude/`
Remove redundant duplicate subdirectories.

---

## Verification Plan

### Automated Tests
1. **PowerShell Script Verification**:
   * Test Antigravity payload (stdin with `invocationNum: 0`, `workspacePaths`): verify JSON output containing `injectSteps`.
   * Test Antigravity follow-up turn (`invocationNum: 1`): verify empty `{}` exit.
   * Test Claude Code payload (stdin with `hook_event_name: "SessionStart"`, `cwd`): verify plain markdown output on stdout.
   * Test fallback (empty stdin / pipe): verify clean exit / text output without crashes.
2. **Shell Script Verification**:
   * Run equivalent test inputs through `sh scripts/session-briefing.sh` to ensure cross-platform compatibility.
3. **JSON Manifest & Hook Validation**:
   * Validate JSON syntax of `plugin.json`, `.claude-plugin/plugin.json`, `hooks.json`, and `hooks/hooks.json`.

### Manual / Structural Verification
* Verify skills folder discovery structure adheres to both AGY and Claude Code standards.
* Confirm git status is clean and all files are tracked properly.
