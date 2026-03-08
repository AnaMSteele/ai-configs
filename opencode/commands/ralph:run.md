---
description: Execute a plan with quality-gated phases — each phase gets 1 implementation pass and up to 3 review/fix passes
argument-hint: '<slug | thoughts/plans/<slug>.md | path/to/plan.md>'
---

# Run Plan (Quality-Gated Loop)

Execute a plan document phase-by-phase, where each phase is quality-gated: do 1 implementation pass, then run up to 3 review/fix passes, stopping early if the reviewer finds zero issues.

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

Before execution, confirm the plan is actually executable:

- `## Progress` exists and has at least one unchecked item or all items are already complete.
- `Resume Instructions (Agent)` exists.
- Each active phase includes `### End State`, `### Tests first`, `### Work`, and `### Verify`.
- The plan does not contain unresolved `Open Questions`, `Decision Points`, or equivalent unresolved-decision sections.

If important questions remain unresolved, do not start implementation. Ask the user for the missing decision or direct them to update the plan first.

Identify the first unchecked item in `## Progress` and begin execution immediately — do not pause to recap the plan.

### 3) Execute Phase-by-Phase with Quality Gate

For each phase (tracked by `## Progress`), run 1 implementation pass followed by up to 3 review/fix passes:

#### Iteration 1: Implement

Delegate to the `developer` agent with this prompt:

> Implement phase N of this plan: `<plan_path>`
>
> Read the plan file fully. Find phase N and implement everything described in its `### Tests first` and `### Work` sections.
>
> Follow the plan precisely — implement what is specified, nothing more. Start from the behavioral tests described in `### Tests first`. If those tests do not yet exist, write them first unless the plan explicitly explains why TDD is not practical for this phase.
>
> Confirm that the tests represent the intended user-visible behavior before changing production code. Then make the smallest real code changes needed to make those tests pass.
>
> When you encounter ambiguity, resolve it by examining existing code patterns and the source documents referenced by the plan. Only ask the user if the decision is truly unresolvable.
>
> After implementation, run the phase's `### Verify` steps if they exist.

After the developer agent completes, proceed immediately to the first review pass — do not pause.

#### Review Passes 1-3: Review and Fix

Delegate to the `quality-reviewer` agent with this prompt:

> Review the implementation of phase N of this plan: `<plan_path>`
>
> Read the plan file fully. Find phase N and its `### Work` and `### End State` sections. Review the implementation for:
>
> 1. Gaps — anything described in the plan that was not implemented or was implemented incorrectly
> 2. Quality issues — bugs, logic errors, missing error handling, broken integrations
> 3. Problems — regressions, inconsistencies with the rest of the codebase, violations of existing patterns
> 4. TDD/plan fidelity issues — cases where the implementation skipped the planned tests-first approach without justification, or where the passing tests do not actually prove the intended behavior
>
> Do NOT flag:
> - Style preferences or subjective improvements
> - Features or enhancements not in the plan
> - Test coverage beyond what the plan specifies
>
> For each real issue found, fix it directly. Do not just report issues — fix them.
>
> At the end, output a summary. If you found and fixed issues, list them. If you found zero issues, state clearly: "No issues found."

**Loop termination:** After each quality-reviewer pass, check its output:

- If it found zero issues → the phase quality gate is passed
- If it found and fixed issues and fewer than 3 review passes have run → run another review pass
- If it found and fixed issues on review pass 3 → stop the run and report that the phase hit the review-pass limit without reaching "No issues found."

#### Phase Completion

Once the quality gate passes (zero issues found):

1. Flip the phase's checkbox from `- [ ]` to `- [x]` in `## Progress`.
2. If implementation required a decision or revealed a constraint, append a structured entry to `## Decisions / Deviations Log` in the plan file.
3. Proceed immediately to the next phase — do not pause.

### 4) Tests Policy

- You SHOULD write or update the planned behavioral tests first when behavior changes, unless the plan explicitly explains why TDD is not practical for that phase.
- You MAY refactor for testability.
- You MUST NOT change product code merely to satisfy a failing test if acceptance criteria + observed behavior indicate the code is correct.
  - In that case, fix the test or update the test assumptions (and log the decision).

### 5) Completion

When all items in `## Progress` are complete:

- Ensure the plan file reflects completion accurately.
- Run any verification commands listed in the plan's `Verification Strategy` and/or phase `### Verify` sections.
- Report the final state to the user.
