---
description: Execute a plan with quality-gated phases — each phase loops until the quality reviewer finds zero issues
argument-hint: '<slug | thoughts/plans/<slug>.md | path/to/plan.md>'
---

# Run Plan (Quality-Gated Loop)

Execute a plan document phase-by-phase, where each phase is quality-gated: implementation is followed by iterative quality review until the reviewer finds zero issues before moving to the next phase.

## Inputs

`$ARGUMENTS` may be:

- A slug (resolves to `thoughts/plans/<slug>.md`)
- A direct path to a plan file (`.md`)

## Process

### 0) Autopilot Rules

- Execute continuously; do not pause between phases or loop iterations.
- Do not stop after a status update (e.g., "I'm starting Phase 1" or "reviewing implementation").
- Every response must either (a) take the next concrete action by invoking a tool (read/search/edit/run), (b) update the plan file, or (c) ask for user input due to an unresolvable decision. Narration alone is not an action.
- If unsure, investigate and retry until evidence supports a decision; do not ask the user just for uncertainty.
- Use `question` only when a decision between viable options requires user input due to insufficient evidence.
- Do NOT stop to summarize what you just did or what you plan to do next. Act.

Unresolvable decision examples:

- Conflicting requirements in the plan with no priority rule.
- A security/billing/production-risk choice that materially changes behavior and is not specified.
- Multiple viable interpretations that change external behavior and cannot be resolved by existing code patterns.

### 1) Resolve Plan Path

Resolve to `plan_path`:

- If `$ARGUMENTS` starts with `@`, treat it as a workspace-relative path and strip the leading `@`.
- If `$ARGUMENTS` is a path to an existing file, use it as `plan_path`.
- If `$ARGUMENTS` is a slug, use `thoughts/plans/<slug>.md`.

### 2) Read Plan

Read `plan_path` fully.

Identify the first unchecked item in `## Progress` and begin execution immediately — do not pause to recap the plan.

### 3) Execute Phase-by-Phase with Quality Gate

For each phase (tracked by `## Progress`), run the following loop:

#### Iteration 1: Implement

Delegate to the `developer` agent with this prompt:

> Implement phase N of this plan: `<plan_path>`
>
> Read the plan file fully. Find phase N and implement everything described in its `### Work` section. Follow the plan precisely — implement what is specified, nothing more. When you encounter ambiguity, resolve it by examining existing code patterns. Only ask the user if the decision is truly unresolvable.
>
> After implementation, run the phase's `### Verify` steps if they exist.

After the developer agent completes, proceed immediately to the review iteration — do not pause.

#### Iteration 2+: Review and Fix

Delegate to the `quality-reviewer` agent with this prompt:

> Review the implementation of phase N of this plan: `<plan_path>`
>
> Read the plan file fully. Find phase N and its `### Work` and `### End State` sections. Review the implementation for:
>
> 1. Gaps — anything described in the plan that was not implemented or was implemented incorrectly
> 2. Quality issues — bugs, logic errors, missing error handling, broken integrations
> 3. Problems — regressions, inconsistencies with the rest of the codebase, violations of existing patterns
>
> Do NOT flag:
> - Style preferences or subjective improvements
> - Features or enhancements not in the plan
> - Test coverage beyond what the plan specifies
>
> For each real issue found, fix it directly. Do not just report issues — fix them.
>
> At the end, output a summary. If you found and fixed issues, list them. If you found zero issues, state clearly: "No issues found."

**Loop termination:** After the quality-reviewer completes, check its output:

- If it found and fixed issues → run another review iteration (back to Iteration 2+)
- If it found zero issues → the phase quality gate is passed

#### Phase Completion

Once the quality gate passes (zero issues found):

1. Flip the phase's checkbox from `- [ ]` to `- [x]` in `## Progress`.
2. If implementation required a decision or revealed a constraint, append a structured entry to `## Decisions / Deviations Log` in the plan file.
3. Proceed immediately to the next phase — do not pause.

### 4) Tests Policy

- You MAY add/update tests when behavior changes.
- You MAY refactor for testability.
- You MUST NOT change product code merely to satisfy a failing test if acceptance criteria + observed behavior indicate the code is correct.
  - In that case, fix the test or update the test assumptions (and log the decision).

### 5) Completion

When all items in `## Progress` are complete:

- Ensure the plan file reflects completion accurately.
- Run any verification commands listed in the plan's `Verification Strategy` and/or phase `### Verify` sections.
- Report the final state to the user.
