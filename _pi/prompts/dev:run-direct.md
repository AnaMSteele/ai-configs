---
description: Execute a single-file plan with resumable progress tracking
argument-hint: '<slug | thoughts/plans/<slug>.md | path/to/plan.md>'
---

# Run Plan (Single File)

Execute a single plan document (spec + phases + progress) in a straightforward, single-agent way:

- Follow the plan, but keep implementation flexibility.
- Track progress by updating `## Progress` in the plan file.

## Inputs

`$ARGUMENTS` may be:

- A slug
- A direct path to a plan file (`.md`)

## Process

### 0) Autopilot Rules

- Execute continuously; do not pause between phases.
- A phase boundary is not a stopping point; if unchecked `## Progress` items remain, immediately continue to the next one.
- Interpret repo guidance like "advance one phase at a time" as serial execution order within this run: complete one phase, then start the next. It does **not** mean stop and wait after each phase.
- Do not stop after a status update (e.g., "I'm starting Phase 1" or "gathering context").
- Do not stop after completing a phase unless you are genuinely blocked.
- Do not hand control back merely because the plan is now in a resumable state; keep executing until all `## Progress` items are complete or a real blocker requires one targeted question.
- Every response must either (a) take the next concrete action by actually invoking a tool (read/search/edit/run) or updating the plan file, or (b) ask for user input due to an unresolvable decision. Narration is not an action.
- If unsure, investigate and retry until evidence supports a decision; do not ask the user just for uncertainty.
- Use `question` only when a decision between viable options requires user input due to insufficient evidence.

Unresolvable decision examples:

- Conflicting requirements in the plan with no priority rule.
- A security/billing/production-risk choice that materially changes behavior and is not specified.
- Multiple viable interpretations that change external behavior and cannot be resolved by existing code patterns.

### 1) Resolve Plan Path

Resolve to:

- `plan_path`

Rules:

- If `$ARGUMENTS` starts with `@`, treat it as a workspace-relative path and strip the leading `@`.
- If `$ARGUMENTS` is a path to an existing file, use it as `plan_path`.
- If `$ARGUMENTS` is a slug, use `thoughts/plans/<slug>.md`.

Legacy migration support (do not delete legacy files):

- If `thoughts/plans/<slug>.md` does not exist but `thoughts/plans/<slug>/spec.md` exists, migrate by creating `thoughts/plans/<slug>.md` from the legacy bundle (spec is authoritative; convert task completion into coarse `## Progress`). Then proceed.

### 2) Read Plan

Read `plan_path` fully.

Immediately begin execution:

- Identify the first unchecked item in `## Progress`.
- Find the corresponding phase section and start implementing it right away; do not pause to recap the plan.
- After each phase, loop back to `## Progress` and continue until no unchecked items remain.

### 3) Execute Phase-by-Phase

For each phase in order (as tracked by `## Progress`):

1. Implement the phase as written.
2. Run the phase `### Verify` steps.
3. After the phase is complete (including verification), immediately flip its checkbox from `- [ ]` to `- [x]` in `## Progress`.
4. If implementation required a decision or revealed a constraint, append a structured entry to `## Decisions / Deviations Log` in the plan file.
5. Re-read `## Progress`; if another unchecked item remains and you are not blocked, immediately start the next phase instead of returning a progress summary.

#### Autonomy / Do Not Pause

- Proceed autonomously through phases.
- If you are not blocked, do not hand control back to the user; take the next concrete action (run commands, edit files, update progress) until you either finish or hit an unresolvable decision.
- Do not stop after announcing intent, listing next steps, or completing "context gathering".
- Only stop to ask the user when you hit an unresolvable decision that cannot be answered from the plan or codebase.

When you must ask:

- Ask exactly one targeted question (batch sub-choices into that one question).
- Provide a recommended default and say what would change with each option.

When you do not need to ask:

- Choose the most conservative, plan-aligned default.
- Log the decision in `## Decisions / Deviations Log` with evidence (files/commands) and proceed.

#### Tests Policy

- You MAY add/update tests when behavior changes.
- You MAY refactor for testability.
- You MUST NOT change product code merely to satisfy a failing test if acceptance criteria + observed behavior indicate the code is correct.
  - In that case, fix the test or update the test assumptions (and log the decision).

### 4) Completion

Only enter this section when all items in `## Progress` are complete.

- Ensure the plan file reflects completion accurately.
- Run any verification commands listed in the plan's `Verification Strategy` and/or phase `### Verify` sections.
- Only now return a final summary of completed phases, final verification, and any logged deviations.
