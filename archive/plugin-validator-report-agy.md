> **Archived — superseded.** Pre-consolidation critique of `consolidation_proposal_plan.md`. Its "CRITICAL" layout issue was resolved in the shipped consolidation (commit `1658b4b`); the repo now matches its "Recommended AGY Install Layout" section. Kept for history only.

# AGY Plugin Validation Report

Cross-checked against the official Antigravity Customization System documentation (hooks.md, plugins.md, skills.md, rules.md).

**Source proposal:** `consolidation_proposal_plan.md`
**Date:** 2026-09-19

---

## Summary Verdict

**The AGY-specific portions of the proposal are structurally correct.** The plugin manifest, hooks.json format, and skills/rules paths all align with the official spec. There are **one critical issue**, **one important caveat**, and **one unverifiable claim** to resolve before implementation.

---

## Issue 1 — CRITICAL: `plugin.json` Must Live Inside a `plugins/` Subfolder, Not at the Repo Root

> [!CAUTION]
> This is the most significant structural problem in the proposal.

**The proposal says:**
> "Antigravity installs directly from the root (`./plugin.json`, `./hooks.json`)"

**What the docs actually say (plugins.md):**
> "A plugin must be contained within a subdirectory of a `plugins/` folder in a customization root (e.g., `.agents/plugins/`)."

The expected on-disk shape is:
```
.agents/
└── plugins/
    └── adhd-focus/
        ├── plugin.json        ← manifest lives HERE, inside a named subfolder
        ├── hooks.json
        ├── rules/
        │   └── AGENTS.md
        └── skills/
            └── <skill>/
                └── SKILL.md
```

The repo root is **not** a valid plugin location for Antigravity. A bare `plugin.json` at the git root will not be auto-discovered.

**Fix options:**
- Keep the source repo layout at root but document that installation means placing the repo into `.agents/plugins/adhd-focus/` in each target project, **or**
- Document that global install is `cp -r . ~/.gemini/config/plugins/adhd-focus/` and that `agy plugin install <git-url>` should be verified to confirm it handles this path correctly.

---

## Issue 2 — IMPORTANT: `hooks.json` Working Directory Caveat

> [!WARNING]
> The relative script path in `hooks.json` depends on directory layout being preserved.

**From hooks.md:**
> "The working directory is set to the **directory containing `hooks.json`**."

The proposed `hooks.json`:
```json
"command": "pwsh -NoProfile -NonInteractive -File scripts/session-briefing.ps1"
```

This is correct **as long as** `scripts/` remains a sibling of `hooks.json`. In the existing `adhd-focus-agy/hooks.json` this already works because the relative layout is:
```
adhd-focus-agy/
├── hooks.json
└── scripts/
    └── session-briefing.ps1
```

When the directory is flattened, confirm `scripts/` and `hooks.json` remain at the same level.

---

## Issue 3 — UNVERIFIABLE CLAIM: "CLI Installers Look at Repo Root by Default"

> [!IMPORTANT]
> This claim in the proposal is not supported by current AGY documentation.

The AGY docs describe plugin discovery as requiring a `plugins/<name>/` path inside a customization root. There is no documented support for a bare `plugin.json` at a git repo root being auto-installed by `agy plugin install <git-url>`. This should be verified against actual CLI behavior before the layout recommendation is finalised.

---

## Confirmed Correct Elements

| Proposal Element | Verdict | Notes |
|---|---|---|
| `plugin.json` with `$schema` field | Correct | Schema URI matches existing plugin. |
| `plugin.json` `name` field | Correct | Optional per spec; defaults to directory name if omitted. |
| `hooks.json` top-level named key (`session-briefing`) | Correct | Matches hooks.md spec exactly. |
| `PreInvocation` event name | Correct | Valid event type per hooks.md. |
| `"type": "command"` in hook handler | Correct | Only supported handler type. |
| `"timeout": 15` | Correct | Valid; docs default is 30s, 15 is tighter but legal. |
| `injectSteps` with `ephemeralMessage` | Correct | Matches `PreInvocation` output contract verbatim. |
| `invocationNum` field name (camelCase) | Correct | Confirmed in hooks.md PreInvocation stdin payload. |
| `workspacePaths` field name (camelCase) | Correct | Present in common hook input fields. |
| Early-exit on `invocationNum > 0` | Correct | Standard pattern to run briefing only on session start. |
| `skills/<name>/SKILL.md` structure | Correct | Matches skills.md directory structure exactly. |
| `rules/AGENTS.md` location inside plugin | Correct | plugins.md explicitly recommends `rules/AGENTS.md`. |
| AGY ignoring `.claude-plugin/` | Correct | Safe coexistence — AGY only reads its own files. |

---

## Recommended AGY Install Layout

Based strictly on the docs, the unified repo should map directly to a plugin folder. The entire repo is the `adhd-focus/` plugin:

```
adhd-focus/                     ← placed into .agents/plugins/ or ~/.gemini/config/plugins/
├── plugin.json                 ← AGY manifest
├── hooks.json                  ← AGY PreInvocation hook
├── rules/
│   └── AGENTS.md
├── skills/
│   ├── micro-plan/SKILL.md
│   ├── simplify/SKILL.md
│   ├── trace-workflow/SKILL.md
│   └── unblock/SKILL.md
├── scripts/
│   ├── session-briefing.ps1
│   └── session-briefing.sh
└── .claude-plugin/             ← Claude Code manifest (AGY ignores this)
    └── plugin.json
```

`hooks/hooks.json` (Claude Code hooks) coexists safely — AGY ignores it, Claude Code ignores the root `hooks.json`.
