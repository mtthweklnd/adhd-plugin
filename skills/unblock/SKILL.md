---
name: unblock
description: >-
  Use when the user is stuck, paralyzed, or doesn't know where to start on a
  task. Diagnoses the exact blocker (ambiguous interface, unknown return shape,
  vague business rule), then carves out a single 15-minute micro-task with a
  concrete first step and a stub test to give an immediate sandbox.
  Trigger phrases: "I'm stuck", "I don't know where to start", "unblock me",
  "this feels too big", "I can't start this".
---

# Unblock

## Purpose

Break task paralysis by shrinking the horizon to a single, verifiable 15-minute action.

## Steps

1. **Diagnose the blocker.** Ask the user (or inspect the current file/ticket) to identify which of these is the actual problem:
   - The interface or input contract is undefined
   - The expected output shape is unknown
   - The business rule is ambiguous
   - The task feels too large to have a clear entry point

2. **Carve a micro-task.** State one thing — and only one thing — the user should do in the next 15 minutes. Be hyper-specific:
   - [DO] "Define only the TypeScript interface for the API response in `src/types/reports.ts`. Do not write any logic yet."
   - [DON'T] "Start working on the feature"

3. **Scaffold a stub.** Create or propose a minimal stub (a failing test, an empty function signature, a schema placeholder) so there is an immediate, runnable sandbox. The stub should be small enough to exist in under 5 minutes.

4. **State the done condition.** Tell the user exactly what "done" looks like for this micro-task so they know when to stop and move on:
   - "Done when the interface compiles with no TypeScript errors."
   - "Done when the stub test file runs (even though the test fails)."

## Rules

- Never propose more than one micro-task. If more work is needed, the next micro-task comes after this one is done.
- Never suggest "plan first" as a micro-task. Planning is not a deliverable — code or a concrete artifact is.
- If the blocker is ambiguity in a business rule, surface it to the user as a question to answer before writing any code.
