---
description: Execute a single-file plan with resumable progress tracking using developer-high subagent for complex work
argument-hint: '<slug | thoughts/plans/<slug>.md | path/to/plan.md>'
---

# Run Plan with High-Capability Developer (Single File)

Execute a single plan document (spec + phases + progress) using the `developer-high` subagent:

- Follow the plan with high-capability implementation.
- Track progress by updating `## Progress` in the plan file.
- Use the high-capability `developer-high` (gpt-5.4) subagent for complex implementations.
- Allow same-scope dynamic re-chunking when a phase is too large to execute safely in one pass.

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
- Do not stop after a status update.
- Do not stop after completing a phase unless you are genuinely blocked.
- Do not hand control back merely because the plan is now in a resumable state; keep executing until all `## Progress` items are complete or a real blocker requires one targeted question.
- Every response must either take the next concrete action or ask exactly one blocking question.
- If unsure, investigate and retry until evidence supports a decision.
- Use `question` only when a decision between viable options requires user input.
- You may re-chunk work only when the split preserves the plan's scope, acceptance criteria, locked decisions, and overall end state.

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

Before execution, confirm the plan is actually executable:

- `## Progress` exists and has at least one unchecked item or all items are already complete.
- `Resume Instructions (Agent)` exists.
- Each active phase includes `### Tests first`, `### End State`, `### Work`, and `### Verify`.
- If the plan declares `Status: research-ready` or equivalent non-ready status, do not start implementation.
- The plan does not contain unresolved `Open Questions`, `Decision Points`, or equivalent unresolved-decision sections when it is intended for execution.

Immediately begin execution:

- Identify the first unchecked item in `## Progress`.
- Find the corresponding phase section.
- If that phase is obviously too large for one safe execution pass, re-chunk it before delegating.
- Otherwise delegate that phase to `developer-high`.
- After each phase, loop back to `## Progress` and continue until no unchecked items remain.

### 2.5) Same-Scope Re-Chunking Protocol

A phase may be re-chunked only when the split preserves:

- scope,
- acceptance criteria,
- locked decisions and externally visible semantics,
- and the parent phase's overall end state.

Use same-scope re-chunking when a phase shows one or more of these signals:

- multiple independently verifiable outcomes are bundled into one checkbox,
- materially different verification stories are mixed together,
- the likely work spans too many loosely related files, surfaces, or contracts for one safe pass,
- execution would require broad rediscovery just to decide how to proceed,
- a prior implementation pass returned `partial` because the slice was too large rather than because of one specific local blocker.

When re-chunking:

1. Change only the current unchecked phase and the unchecked progress bookkeeping that must correspond to it.
2. Replace the current progress item with smaller child items using stable suffixes such as `P2a`, `P2b`, `P2c`.
3. Replace the parent phase with matching child phases, each with `### Tests first`, `### End State`, `### Work`, and `### Verify`.
4. Preserve completed phase IDs and append a structured note to `## Decisions / Deviations Log` explaining why the split was needed.
5. Continue immediately with the first new child phase.

If a safe split would require changing scope, acceptance criteria, or missing semantics, do not re-chunk. Ask exactly one blocking question instead.

### 3) Execute Phase-by-Phase

For each phase in order:

1. Launch the phase implementation with `Agent` using `subagent_type: "developer-high"`.
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
> If the phase proves too large for one safe pass but can be subdivided without changing scope or semantics, do not invent new behavior. Return `result: partial` together with a concise same-scope chunking recommendation.
>
> Run the phase's `### Verify` steps if they exist.
>
> Return a structured summary with:
> - files changed
> - tests written or updated
> - verification commands run
> - result: `complete`, `partial`, or `blocked`
> - phase sizing: `bounded`, `needs-same-scope-split`, or `blocked-on-semantics`
> - recommended same-scope chunks, if any
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
- if the evidence shows the phase should be split into smaller same-scope slices, update the plan accordingly, log the split, and continue with the first new child phase
- otherwise perform one focused retry/fix pass using the failure details as input
- rerun verification
- only mark the phase complete if the retry actually succeeds

##### Case C: `blocked`

If the subagent reports a blocker or an unresolvable decision:

- **do not** mark the phase complete
- first verify whether the blocker can be resolved from the repo or plan by doing your own quick investigation
- if you can resolve it, redelegate once with the new evidence
- if you cannot resolve it but a same-scope split would solve the problem without changing semantics, re-chunk and continue
- otherwise ask exactly one blocking question to the user

#### Hard rule: never mark a failed phase complete

If any of the following is true, the checkbox must stay unchecked:

- verification failed
- the subagent reported `partial`
- the subagent reported `blocked`
- you do not have evidence that the plan's `### End State` was reached

#### Autonomy / Do Not Pause

- Proceed autonomously through phases.
- If you are not blocked, do not hand control back to the user.
- If a phase fails once, prefer one focused repair/retry cycle or a same-scope split before asking the user.
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
