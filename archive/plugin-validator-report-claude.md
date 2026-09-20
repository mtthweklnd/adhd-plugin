> **Archived — superseded.** Pre-consolidation critique of the old `adhd-focus-claude/` subfolder, which no longer exists. `hooks/hooks.json` and `scripts/session-briefing.ps1` were rewritten to address every Critical Issue listed here — including the `rules/AGENTS.md` auto-load question (resolved: the script reads and injects it manually via the `SessionStart` hook; see step 7 of `session-briefing.ps1`). Kept for history only.

# Plugin Validation Report

## Plugin: adhd-focus (folder: `adhd-focus-claude`)
Location: `C:\Users\matt\Projects\adhd-plugin\adhd-focus-claude`

## Summary
**FAIL.** In its current flat layout, `adhd-focus-claude` is not a valid, functional Claude Code plugin — Claude Code would not even discover it. More importantly, the file *contents* (not just their location) are the Antigravity manifest/hooks/script verbatim, not a Claude Code implementation. This confirms the consolidation plan's core layout assumptions (`.claude-plugin/plugin.json`, `hooks/hooks.json`) are correct per the official spec, but the plan understates the work needed — it isn't just a file-move, the hook event, hook schema, and script I/O contract all need to be rewritten for Claude Code.

## Answer to Question 1: Is the flat layout valid for Claude Code?

**No.** Confirmed against the `plugin-structure` and `hook-development` reference skills bundled with Claude Code's own `plugin-dev` plugin:

- Manifest: "The `plugin.json` manifest MUST be in `.claude-plugin/` directory... Claude Code will not recognize plugins without this file in the correct location." (`skills/plugin-structure/references/manifest-reference.md`)
- Hooks: default/auto-discovered location is `./hooks/hooks.json`; a bare root-level `hooks.json` is not scanned.

The consolidation plan's assumption (`.claude-plugin/plugin.json` + `hooks/hooks.json`) is **correct** and matches the authoritative spec. Proceed with that part of the plan.

## Critical Issues (5)

- `adhd-focus-claude/plugin.json` — This file is not a Claude Code manifest at all; it's the **Antigravity** manifest (`"$schema": "https://antigravity.google/schemas/v1/plugin.json"`), and it's byte-identical to `adhd-focus-agy/plugin.json`. Fix: at `.claude-plugin/plugin.json`, drop the Antigravity `$schema`, keep `name`/`description`, add `version` (Claude Code defaults to `0.1.0` if omitted, but the proposal's `0.2.0` is fine).

- `adhd-focus-claude/hooks.json` — Wrong location (should be `hooks/hooks.json`) **and** wrong schema entirely. Current shape:
  ```json
  { "session-briefing": { "PreInvocation": [ { "type": "command", "command": "...", "timeout": 15 } ] } }
  ```
  This is Antigravity's format. Problems for Claude Code:
  - `PreInvocation` is not a valid Claude Code hook event. Valid events are: `PreToolUse`, `PostToolUse`, `Stop`, `SubagentStop`, `SessionStart`, `SessionEnd`, `UserPromptSubmit`, `PreCompact`, `Notification`.
  - Structurally, a Claude Code plugin `hooks/hooks.json` needs a `hooks` wrapper object keyed by event name, and each event entry needs a `matcher` plus a nested `hooks` array of `{type, command, timeout}` objects. The current file has neither the wrapper nor the `matcher`/nested-array shape.
  - The consolidation plan's proposed replacement (mapping to `SessionStart`, with proper `hooks.SessionStart[].hooks[]` nesting) is schema-correct.

- `adhd-focus-claude/hooks.json` command path — `"command": "pwsh ... -File scripts/session-briefing.ps1"` uses a bare relative path. Spec explicitly forbids this ("Never use... Relative paths from working directory (`./scripts/...` in commands)") and requires `${CLAUDE_PLUGIN_ROOT}`. This is a separate bug from the location/schema issue — even after moving to `hooks/hooks.json`, the command must become `"${CLAUDE_PLUGIN_ROOT}/scripts/session-briefing.ps1"` (the plan's proposed replacement already does this correctly).

- `adhd-focus-claude/scripts/session-briefing.ps1` — Written entirely against Antigravity's hook I/O contract, not Claude Code's:
  - Reads `$input_json.invocationNum` and `$input_json.workspacePaths` from stdin — these fields don't exist in Claude Code's hook payload (Claude Code sends `session_id`, `cwd`, `hook_event_name`, `transcript_path`, etc.). Under a real Claude Code `SessionStart` invocation, `$workspacePaths` will always be null, so the script falls through to `if (-not $workspaceRoot ...) { Write-Output '{}'; exit 0 }` on line 32-35 and produces **no briefing at all**.
  - Even if that branch were fixed, the output envelope (`{ injectSteps: [ { ephemeralMessage: ... } ] }`, lines 136-144) is Antigravity's response schema, not a Claude Code hook output. Claude Code `SessionStart` hooks expect plain stdout text or a hook-specific JSON shape (e.g. `additionalContext` in `hookSpecificOutput`) — `injectSteps`/`ephemeralMessage` will not be interpreted.
  - Net effect: as-is, this script is non-functional when invoked by Claude Code. It genuinely needs the "polyglot" rewrite the consolidation plan describes in its Verification Plan (Architecture & Compatibility Strategy and Automated Tests sections) — this isn't just a copy/relocate, it's new logic.

- `adhd-focus-claude/rules/AGENTS.md` — Not an auto-discovered Claude Code plugin component. Plugin auto-discovery only covers `commands/`, `agents/`, `skills/`, `hooks/hooks.json`, and `.mcp.json` (per `plugin-structure` reference skill) — there is no documented mechanism for a plugin to auto-inject an arbitrary `rules/AGENTS.md` file into every session's context. The consolidation plan's claim "Claude Code natively supports AGENTS.md" is an **unverified assumption** and, as far as the bundled spec docs show, not accurate for plugin-distributed content (it may work for a project-root `AGENTS.md`/`CLAUDE.md` that a user maintains directly, but that's a different mechanism than plugin auto-load). Recommend validating this specifically before relying on it, e.g. by testing whether a plugin's `rules/AGENTS.md` actually gets pulled into context, or by instead surfacing these rules via a `SessionStart` hook's `additionalContext` output or a skill.

## Warnings (2)

- `adhd-focus-claude/README.md` — Documents the plugin as if `hooks.json` and relative script paths already work for Claude Code (shows the same non-portable command). Should be updated once the real Claude Code hook config is written, to avoid misleading users who install from this folder today.

- `adhd-focus-claude/plugin.json` — Missing recommended metadata (`version`, `author`, `license`, `keywords`). Not required, but recommended for a distributable plugin; the consolidation plan's proposed `.claude-plugin/plugin.json` already adds `version`.

## Component Summary
- Commands: 0 found (none present — fine, optional)
- Agents: 0 found (none present — fine, optional)
- Skills: 4 found (`micro-plan`, `simplify`, `trace-workflow`, `unblock`), **4 valid** — correct `SKILL.md` format, kebab-case names matching directories, frontmatter has `name`/`description`, descriptions are trigger-rich and reasonably scoped. This part of the plugin is genuinely Claude-Code-ready and needs no changes beyond relocation.
- Hooks: present (`hooks.json`) at wrong location, with wrong event name (`PreInvocation`), wrong schema (missing `hooks` wrapper/`matcher`), and a non-portable command path — **invalid**
- MCP Servers: none configured (no `.mcp.json`, no `mcpServers` in manifest) — N/A

## Positive Findings
- All 4 skills (`skills/*/SKILL.md`) already conform to the real Claude Code skill format and directory convention — these can move to `skills/` at the new root essentially unchanged.
- The underlying design intent (session-start briefing, ADO work-item sniffing, `_dev/` living-plan convention) is sound; only the platform-adapter layer (manifest, hook config, script I/O) needs rework.

## Recommendations
1. Before moving files per the consolidation plan, first rewrite (not just relocate) `hooks.json` → `hooks/hooks.json` using the wrapper schema, `SessionStart` event, `matcher`, nested `hooks` array, and `${CLAUDE_PLUGIN_ROOT}`-based command — the plan's proposed snippet is correct and can be used as-is.
2. Rewrite `scripts/session-briefing.ps1` (and the `.sh` counterpart) to read Claude Code's actual `SessionStart` stdin fields (`cwd`, `session_id`, `hook_event_name`) and emit output Claude Code understands (plain stdout text is simplest, or `hookSpecificOutput.additionalContext` if structured injection is wanted) — don't assume the "polyglot" detection logic in the proposal will trivially work without testing both branches end-to-end, since Claude Code's actual field set differs from what the script currently checks.
3. Verify the `rules/AGENTS.md` auto-load claim before relying on it in the unified layout — test whether it's actually pulled into context, or route the standing rules through the `SessionStart` hook's context injection instead, which is a documented mechanism.
4. Fill out `.claude-plugin/plugin.json` with `version`, and consider `author`/`license`/`keywords` for distribution quality (all optional per spec, but recommended).
5. Update `README.md` hook-configuration section once the real `hooks/hooks.json` exists, so it no longer documents the non-portable relative-path command.

## Overall Assessment
**FAIL** — `adhd-focus-claude` in its current form is a mislabeled copy of the Antigravity plugin (manifest schema, hook event name, hook schema, and script I/O contract are all Antigravity's, not Claude Code's), on top of being in the wrong file locations. The consolidation plan's assumptions about required Claude Code file *locations* (`.claude-plugin/plugin.json`, `hooks/hooks.json`) are verified correct against the official plugin-dev reference docs, so proceed with that structural change. However, the plan should be scoped as "port + relocate," not just "relocate" — the hook schema and the briefing script both need real rewrites to function under Claude Code, and the `rules/AGENTS.md` auto-load assumption needs verification. The skills are the one component that's already Claude-Code-correct and can move with no changes.

Key files referenced:
- `C:\Users\matt\Projects\adhd-plugin\adhd-focus-claude\plugin.json`
- `C:\Users\matt\Projects\adhd-plugin\adhd-focus-claude\hooks.json`
- `C:\Users\matt\Projects\adhd-plugin\adhd-focus-claude\scripts\session-briefing.ps1`
- `C:\Users\matt\Projects\adhd-plugin\adhd-focus-claude\rules\AGENTS.md`
- `C:\Users\matt\Projects\adhd-plugin\adhd-focus-claude\skills\{micro-plan,simplify,trace-workflow,unblock}\SKILL.md`
- `C:\Users\matt\Projects\adhd-plugin\consolidation_proposal_plan.md`
- Reference spec used: `C:\Users\matt\.claude\plugins\cache\claude-plugins-official\plugin-dev\c447c3207a42\skills\plugin-structure\SKILL.md`, `...\references\manifest-reference.md`, `...\skills\hook-development\SKILL.md`
