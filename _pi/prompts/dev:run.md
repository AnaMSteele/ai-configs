---
description: Execute a single-file plan with resumable progress tracking using developer-mid subagent
argument-hint: '<slug | thoughts/plans/<slug>.md | path/to/plan.md>'
---

# Run Plan (Single File with Subagent)

Execute a single plan document (spec + phases + progress) using the `developer-mid` subagent.

- Follow the plan, but keep implementation flexibility.
- Track progress by updating `## Progress` in the plan file.
- Use the cost-effective `developer-mid` (gpt-5.4-mini) subagent for implementation.

## Inputs

`$ARGUMENTS` may be:

- A slug
- A direct path to a plan file (`.md`)

## Process

### 0) Autopilot Rules

- Execute continuously; do not pause between phases.
- A phase boundary is not a stopping point; if unchecked `## Progress` items remain, immediately continue to the next one.
- Interpret repo guidance like "advance one phase at a time" as serial execution order within this run: complete one phase, then start the next. It does **not** mean stop and wait after each phase.
- Do not stop after a status update.
- Do not stop after completing a phase unless you are genuinely blocked.
- Do not hand control back merely because the plan is now in a resumable state; keep executing until all `## Progress` items are complete or a real blocker requires one targeted question.
- Every response must either take the next concrete action or ask exactly one blocking question.
- If unsure, investigate and retry until evidence supports a decision.
- Use `question` only when a decision between viable options requires user input.

Unresolvable decision examples:

- Conflicting requirements in the plan with no priority rule.
- A security/billing/production-risk choice that materially changes behavior and is not specified.
- Multiple viable interpretations that change external behavior and cannot be resolved by existing code patterns.

### 1) Resolve Plan Path

Resolve to `plan_path`.

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
- Find the corresponding phase section.
- Delegate that phase to `developer-mid`.
- After each phase, loop back to `## Progress` and continue until no unchecked items remain.

### 3) Execute Phase-by-Phase

For each phase in order:

1. Launch the phase implementation with `Agent` using `subagent_type: "developer-mid"`.
2. Wait for the result with `get_subagent_result(..., wait: true)`.
3. Inspect the returned summary and verification evidence before changing the plan file.
4. Run the phase `### Verify` steps yourself if the subagent did not clearly complete them.
5. Mark the phase complete only after implementation and verification are both actually complete.
6. After handling that phase, re-read `## Progress`; if another unchecked item remains and you are not blocked, immediately start the next phase instead of returning a progress summary.

Use a prompt in this shape:

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
> Run the phase's `### Verify` steps if they exist.
>
> Return a structured summary with:
> - files changed
> - tests written or updated
> - verification commands run
> - result: `complete`, `partial`, or `blocked`
> - blockers or failed verification, if any

#### Required subagent handling

Treat the subagent result as one of three cases:

##### Case A: `complete`

If the subagent completed the phase and verification passed:

- run any missing verification yourself
- immediately flip that phase checkbox from `- [ ]` to `- [x]` in `## Progress`
- append any material decision or deviation to `## Decisions / Deviations Log`
- continue to the next phase without pausing

##### Case B: `partial`

If the subagent reports partial implementation, incomplete verification, or “tests still failing”:

- **do not** mark the phase complete
- inspect the returned evidence
- perform one focused retry/fix pass using the failure details as input
- rerun verification
- only mark the phase complete if the retry actually succeeds

##### Case C: `blocked`

If the subagent reports a blocker or an unresolvable decision:

- **do not** mark the phase complete
- first verify whether the blocker can be resolved from the repo or plan by doing your own quick investigation
- if you can resolve it, redelegate once with the new evidence
- otherwise ask exactly one blocking question to the user

#### Hard rule: never mark a failed phase complete

If any of the following is true, the checkbox must stay unchecked:

- verification failed
- the subagent reported `partial`
- the subagent reported `blocked`
- you do not have evidence that the plan’s `### End State` was reached

#### Autonomy / Do Not Pause

- Proceed autonomously through phases.
- If you are not blocked, do not hand control back to the user.
- If a phase fails once, prefer one focused repair/retry cycle before asking the user.
- Ask the user only when the remaining blocker is genuinely unresolvable from the plan and codebase.

When you must ask:

- Ask exactly one targeted question.
- Provide a recommended default and say what would change with each option.

When you do not need to ask:

- Choose the most conservative, plan-aligned default.
- Log the decision in `## Decisions / Deviations Log` with evidence and proceed.

### 4) Completion

Only enter this section when all items in `## Progress` are complete.

- Ensure the plan file reflects completion accurately.
- Run any verification commands listed in the plan’s `Verification Strategy` and/or phase `### Verify` sections.
- Only now return a final summary of completed phases, final verification, and any logged deviations.
