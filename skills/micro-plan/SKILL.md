---
name: micro-plan
description: >-
  Create an ADHD-friendly, single living task plan in _dev/ with a hyper-focused
  entry point, ordered Task List, and Acceptance Criteria. Triggers on: "/micro-plan",
  "/plan", "create plan", "break this down", or when an Azure DevOps work item number
  or card details are provided. Sniffs git branch for work item IDs and enforces
  in-line [Discovered] tasks instead of secondary plan files.
---

# Micro-Plan

## Purpose

Break down ambiguous features or Azure DevOps work items into an actionable, single living document in `_dev/`. Protects working memory by establishing a sequential Task List, explicit Acceptance Criteria, and a dedicated Roadmap for deferred thoughts.

## Workflow Steps

1. **Sniff Branch & Work Item Context:**
   - Inspect the current git branch name using `git branch --show-current`.
   - Check for a work item ID using regex `(?:^|[/_-])([0-9]{3,8})(?:[/_-]|$)`.
   - If present on the branch or specified by the user, record the work item ID (e.g. `10425`).

2. **Define Acceptance Criteria & Goal:**
   - Summarize the goal in 1-2 direct sentences.
   - List concrete Acceptance Criteria based on the ticket or user requirements. Avoid vague goals like "make it work".

3. **Construct the Task List:**
   - Keep steps strictly linear.
   - **Step 1 must be a low-friction 5-minute warm-up** (e.g., create a file stub, add a single test case, define a type interface).
   - Each subsequent step should represent a single verifiable increment.

4. **Scaffold the Living Document:**
   - Write to `_dev/<id>-<slug>.md` (or `_dev/<slug>.md` if no work item ID exists).
   - Use the standard template below.

5. **Maintain the Living Document During Execution:**
   - Check off items as they complete: `- [x] Step name`.
   - If an unexpected blocker, dependency, or edge case emerges, **do not create a new plan file**.
   - Slot the new work directly beneath the active step in the Task List as `[Discovered]`:
     ```markdown
     - [ ] 2. Implement authentication handler
       - [ ] [Discovered] Add token refresh helper in auth-utils.ts
       - [ ] [Discovered] Handle expired token redirect error
     ```
   - If an out-of-scope idea or nice-to-have improvement occurs, add it to `## Roadmap` immediately so it doesn't distract from current flow.

## Document Template

Use this format when generating or updating `_dev/<id>-<slug>.md`:

```markdown
# [AB#<id>: ]<Task Title>

- **Work Item:** AB#<id> (or N/A)
- **Branch:** <branch-name>
- **Status:** In Progress
- **Created:** <YYYY-MM-DD>

## Goal

<One or two sentences summarizing the exact objective.>

## Acceptance Criteria

- [ ] <Criterion 1 - verifiable condition>
- [ ] <Criterion 2 - verifiable condition>
- [ ] <Criterion 3 - tests pass / builds cleanly>

## Task List

- [ ] 1. <Ultra-low friction warm-up step - 5 minutes>
- [ ] 2. <Core implementation step>
  - [ ] [Discovered] <Slot intermediate sub-steps found during work directly here>
- [ ] 3. <Verification and test step>

## Roadmap

- <Deferred idea or future enhancement that should not distract current work>
```
