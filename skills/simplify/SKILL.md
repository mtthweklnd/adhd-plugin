---
name: simplify
description: >-
  Simplify or explain a single function or block: de-densify dense branch nesting
  and reduce working memory overhead while strictly preserving behavior. For a
  cross-function or multi-file delegation chain, use trace-workflow instead.
  Triggers on: "simplify this", "explain this code", "make this cleaner",
  "reduce cognitive load", "this code is overwhelming".
---

# Simplify

## Purpose

De-densify complex logic and eliminate nested control flow to minimize working memory overhead, without altering runtime behavior or external API contracts.

## Workflow Steps

1. **Comprehend Without Noise:**
   Before presenting or proposing any code changes, state a 3-bullet plain-English executive summary:
   - **Input Contract:** What data comes in, required types, and prerequisites.
   - **Core Transformation:** The primary business logic or computation performed.
   - **Output / Side Effects:** What is returned, modified in external state, or emitted.

   If the request was explanation-only ("explain this code") with no ask to change it, stop here — do not propose a refactor.

2. **Cognitive Audit:**
   Beyond the AST Hygiene standard in `rules/AGENTS.md` (2-level nesting cap, guard clauses — read the file if it isn't already in context, e.g. running as a subagent that skipped the session-start briefing), check for working memory friction the standard doesn't cover:
   - Dense or chained ternary expressions.
   - Cryptic single-letter or abbreviated variable names.
   - Mixed responsibilities (e.g., validation, business calculation, and response formatting intertwined in one block).

3. **Behavior-Preserving Refactor:**
   Apply the AST Hygiene standard from `rules/AGENTS.md` (read the file first if it isn't already in context), plus:
   - **Extract Helper Units:** Break blocks exceeding 30 lines or containing separate concerns into dedicated single-purpose functions with explicit input/output parameters.
   - **Domain Naming:** Replace cryptic identifiers with descriptive domain nouns and verbs.
   - **Unpack Dense Expressions:** Expand compound ternaries into explicit conditional branches or lookup dictionaries/maps.

4. **Cognitive Diff & Rationale:**
   Show the refactored code and conclude with a brief, bulleted explanation of how working memory demand was reduced:
   - Specific nesting levels eliminated.
   - Clarified invariants or flattened execution paths.

## Rules

- Never change observable behavior, function signatures, or return contracts unless explicitly requested.
- Keep refactoring local and incremental; avoid introducing unrequested architectural abstractions.
- Never output raw refactored code without the initial 3-bullet comprehension summary.
