# ADHD Focus Plugin - Rules

## Communication & Formatting

- Strictly no emojis. Do not use emojis in responses, summaries, code comments, or markdown documents.
- Keep responses concise, clear, and direct.

## Session Briefing

At the start of every session, after reading the injected briefing:
- Always produce the 3-point summary leading with the single recommended next action:
  - `[Next Action]` - The single recommended next action to resume flow (put this first).
  - `[Completed]` - What was just completed (from git log).
  - `[In Progress]` - What is currently in-progress or unfinished (from git status + _dev/ tasks).
- Keep the summary to bullet points. Do not pad it with context the user didn't ask for.

## Single Living Document Pattern

- Maintain a single living document in `_dev/<id>-<slug>.md` (or `_dev/<slug>.md`) as the authoritative plan.
- Never create secondary, fragmented, or separate plan files for an ongoing task when blockers, edge cases, or intermediate steps arise.
- Insert newly discovered tasks directly into the active file's Task List inline, marked with `[Discovered]`, beneath the blocking or parent step.
- Align terminology to standard development concepts:
  - Use "Acceptance Criteria" to define requirements and completion targets.
  - Use "Task List" for the ordered sequence of actionable steps.
  - Use "Roadmap" for capturing deferred ideas, scope expansions, and future enhancements without derailing current focus.

## Azure DevOps & Commit Hygiene

- When an Azure DevOps work item ID is detected (on the active branch, in the session briefing, or provided by the user), prepend `AB#<id>:` to all suggested git commit messages (e.g., `git commit -m "AB#10425: add login validation"`).
- Cross-reference work item IDs with `_dev/*<id>*.md` task files.

## Task Discipline

- Never propose more than one next action at a time unless explicitly asked.
- When a task is ambiguous, name the ambiguity explicitly before proposing a solution.
- Prefer small, completable steps over comprehensive plans. A done task beats a perfect plan.

## Working Memory Hygiene

- When introducing a new concept or variable mid-task, define it in one sentence before using it.
- Avoid nested parenthetical explanations mid-sentence. Break them into separate sentences.
- If a code block exceeds 30 lines, summarize what it does in a comment at the top.

## Code Complexity & AST Hygiene

- Avoid custom call chains deeper than 2 hops (`A() -> B() -> C()`) unless writing recursive algorithms.
- Inline intermediate passthrough functions that only exist to pass arguments down another hop.
- Structure multi-step workflows as flat sequential pipelines where the coordinator invokes steps linearly with named intermediate variables, rather than having Step 1 delegate internally to Step 2.
- Cap indentation depth to 2 levels using guard clauses and early returns over nested conditionals.
- When explaining or presenting complex logic, provide a 2-3 bullet plain-English summary of inputs, transformations, and outputs before outputting the code block.
