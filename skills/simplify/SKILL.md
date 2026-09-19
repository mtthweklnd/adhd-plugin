---
name: simplify
description: >-
  Understand and simplify complex code to reduce cognitive load and eliminate
  dense branch nesting while strictly preserving behavior. Triggers on:
  "simplify this", "explain this code", "make this cleaner", "reduce cognitive load",
  "this code is overwhelming".
---

# Simplify

## Purpose

De-densify complex logic and eliminate nested control flow to minimize working memory overhead, without altering runtime behavior or external API contracts.

## Triggers

- Trigger phrases: "simplify this", "explain this code", "make this cleaner", "reduce cognitive load", "this code is overwhelming", "clean up this function"

## Workflow Steps

1. **Comprehend Without Noise:**
   Before presenting or proposing any code changes, state a 3-bullet plain-English executive summary:
   - **Input Contract:** What data comes in, required types, and prerequisites.
   - **Core Transformation:** The primary business logic or computation performed.
   - **Output / Side Effects:** What is returned, modified in external state, or emitted.

2. **Cognitive Audit:**
   Analyze the target code for working memory friction:
   - Nesting depth exceeding 2 levels (nested `if`/`else`, nested callbacks, deep loops).
   - Dense or chained ternary expressions.
   - Cryptic single-letter or abbreviated variable names.
   - Mixed responsibilities (e.g., validation, business calculation, and response formatting intertwined in one block).

3. **Behavior-Preserving Refactor:**
   Apply AST and control-flow hygiene while strictly preserving existing behavior:
   - **Guard Clauses & Early Returns:** Invert conditions to exit early on edge cases and error states, flattening the happy path to base indentation.
   - **Extract Helper Units:** Break blocks exceeding 30 lines or containing separate concerns into dedicated single-purpose functions with explicit input/output parameters.
   - **Domain Naming:** Replace cryptic identifiers with descriptive domain nouns and verbs.
   - **Unpack Dense Expressions:** Expand compound ternaries into explicit conditional branches or lookup dictionaries/maps.

4. **Cognitive Diff & Rationale:**
   Show the refactored code and conclude with a brief, bulleted explanation of how working memory demand was reduced:
   - Specific nesting levels eliminated.
   - Clarified invariants or flattened execution paths.

## Rules

- Strictly no emojis in summaries, explanations, or code comments.
- Never change observable behavior, function signatures, or return contracts unless explicitly requested.
- Keep refactoring local and incremental; avoid introducing unrequested architectural abstractions.
- Never output raw refactored code without the initial 3-bullet comprehension summary.
