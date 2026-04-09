---
description: Execute a single-file plan with resumable progress tracking using developer-high subagent for complex work
argument-hint: '<slug | thoughts/plans/<slug>.md | path/to/plan.md>'
---

# Run Plan with High-Capability Developer (Single File)

Execute a single plan document (spec + phases + progress) using the `developer-high` subagent:

- Follow the plan with high-capability implementation.
- Track progress by updating `## Progress` in the plan file.
- Uses the high-capability `developer-high` (gpt-5.4) subagent for complex implementations.

Use this for:
- Complex multi-file refactoring
- Algorithmic challenges requiring deep reasoning
- Performance-critical implementations
- Concurrent/distributed systems
- Complex domain logic with many edge cases

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
- Find the corresponding phase section and delegate to the subagent.
- After each phase, loop back to `## Progress` and continue until no unchecked items remain.

### 3) Execute Phase-by-Phase

For each phase in order (as tracked by `## Progress`):

1. Delegate to the `developer-high` agent with this prompt:

> Implement phase N of this plan: `<plan_path>`
>
> Read the plan file fully. Find phase N and implement the behavior described in its `### Tests first`, `### Work`, and `### End State` sections.
>
> Treat the plan as the source of truth for intended outcomes, locked constraints, and external scope.
>
> Start from the behavioral tests described in `### Tests first`. If those tests do not yet exist, write them first unless the plan explicitly explains why TDD is not practical for this phase.
>
> Confirm that the tests represent the intended user-visible behavior before changing production code.
>
> After implementation, run the phase's `### Verify` steps if they exist.
>
> Return a summary of what was implemented and the verification results.

2. After the subagent completes, run the phase `### Verify` steps if not already done.
3. After the phase is complete (including verification), immediately flip its checkbox from `- [ ]` to `- [x]` in `## Progress`.
4. If implementation required a decision or revealed a constraint, append a structured entry to `## Decisions / Deviations Log` in the plan file.
5. Re-read `## Progress`; if another unchecked item remains and you are not blocked, immediately start the next phase instead of returning a progress summary.

#### Autonomy / Do Not Pause

- Proceed autonomously through phases.
- If you are not blocked, do not hand control back to the user; take the next concrete action (delegate to next phase, update progress) until you either finish or hit an unresolvable decision.
- Only stop to ask the user when you hit an unresolvable decision that cannot be answered from the plan or codebase.

When you must ask:

- Ask exactly one targeted question (batch sub-choices into that one question).
- Provide a recommended default and say what would change with each option.

When you do not need to ask:

- Choose the most conservative, plan-aligned default.
- Log the decision in `## Decisions / Deviations Log` with evidence (files/commands) and proceed.

### 4) Completion

Only enter this section when all items in `## Progress` are complete.

- Ensure the plan file reflects completion accurately.
- Run any verification commands listed in the plan's `Verification Strategy` and/or phase `### Verify` sections.
- Only now return a final summary of completed phases, final verification, and any logged deviations.
