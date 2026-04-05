---
description: Execute a plan with quality-gated phases - each phase gets 1 implementation pass and repeated review/fix passes until only low-risk items remain
argument-hint: '<slug | thoughts/plans/<slug>.md | path/to/plan.md>'
---

# Run Plan (Quality-Gated Loop)

Execute a plan document phase-by-phase: do 1 implementation pass, then repeat review/fix passes until the reviewer finds zero issues or explicitly confirms that only low-risk deferred items remain. Do not advance with unresolved substantive issues.

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
- Each active phase's `### Verify` steps are concrete and current for the repository's actual targets, package names, paths, and commands.

If important questions remain unresolved, do not start implementation. Ask the user for the missing decision or direct them to update the plan first.

Identify the first unchecked item in `## Progress` and begin execution immediately - do not pause to recap the plan.

### 2.5) Low-Risk Deferral Bar

A phase may advance with deferred items only if every remaining item is low risk.

Not low risk:

- acceptance criteria gaps or incorrect behavior,
- correctness, data integrity, security, concurrency, observability, or performance viability issues,
- missing required-surface parity,
- stale or invalid `### Verify` guidance,
- schema, fixture, payload, response-contract, or evidence-source drift that would mislead later phases.

### 3) Execute Phase-by-Phase with Quality Gate

For each phase (tracked by `## Progress`), run 1 implementation pass followed by as many review/fix passes as needed. A phase advances only when a review pass finds zero issues or explicitly confirms that only low-risk deferred items remain.

#### Iteration 1: Implement

Delegate to the `developer-mid` agent with this prompt:

> Implement phase N of this plan: `<plan_path>`
>
> Read the plan file fully. Find phase N and implement the behavior described in its `### Tests first`, `### Work`, and `### End State` sections.
>
> Treat the plan as the source of truth for intended outcomes, locked constraints, and external scope. Do not treat it as an exhaustive list of every file edit.
>
> Start from the behavioral tests described in `### Tests first`. If those tests do not yet exist, write them first unless the plan explicitly explains why TDD is not practical for this phase.
>
> Use the `tdd-test-writer` skill when available to pressure-test the RED-phase contract before changing production code.
>
> Confirm that the tests represent the intended user-visible behavior before changing production code. Strengthen them when needed so they cover the planned happy path, failure/guardrail behavior, counterexample or ambiguity cases, boundary/scale behavior when applicable, and required cross-surface parity or contract-drift checks.
>
> If the phase spans multiple required surfaces (for example HTTP/CLI/MCP/UI), treat parity work and missing registry/dispatcher/wrapper wiring as in-scope work unless the plan explicitly says otherwise.
>
> If locked schemas, payloads, response shapes, or evidence sources have changed since earlier phases, update stale fixtures/tests in the touched scope during this phase and log the adjustment.
>
> Validate the phase's `### Verify` targets against repo reality before relying on them. If a correction is obvious, update the plan and log it.
>
> When you encounter ambiguity, resolve it by examining existing code patterns and the source documents referenced by the plan. Only ask the user if the decision is truly unresolvable.
>
> After implementation, run the phase's `### Verify` steps if they exist.

After the developer-mid agent completes, proceed immediately to the first review pass - do not pause.

#### Review Passes: Review and Fix

Delegate to the `quality-reviewer` agent with this prompt:

> Review the implementation of phase N of this plan: `<plan_path>`
>
> Read the plan file fully. Find phase N and its `### Tests first`, `### Work`, `### End State`, and `### Verify` sections. Review the implementation for gaps, quality issues, regressions, TDD/plan fidelity issues, missing counterexample/boundary/parity coverage, stale verify commands, missing required-surface parity, stale fixtures/contracts, or unresolved evidence-source mismatches that would make the phase unsafe to advance.
>
> Do NOT flag style preferences, speculative enhancements, or test coverage beyond what the plan specifies or clearly implies.
>
> Fix every non-low-risk issue directly. Do not just report issues - fix them.
>
> At the end, output one of these exact lead sentences:
> - `No issues found.`
> - `Only low-risk items remain.`

**Loop termination:** After each quality-reviewer pass, check its output:

- If it found zero issues -> the phase quality gate is passed
- If it explicitly says only low-risk items remain -> the phase quality gate is passed only after each low-risk item is logged in the plan's `## Decisions / Deviations Log`
- If it found and fixed any substantive issue -> run another review pass
- There is no fixed review-pass limit. Keep iterating until the gate passes or a true Blocking Decision is reached.

#### Phase Completion

Once the phase is ready to advance (either zero issues found, or only low-risk deferred items remain):

1. Flip the phase's checkbox from `- [ ]` to `- [x]` in `## Progress`.
2. If implementation required a decision, revealed a constraint, corrected stale verify guidance, or required contract/evidence-source drift cleanup, append a structured entry to `## Decisions / Deviations Log` in the plan file.
3. Proceed immediately to the next phase - do not pause.

### 4) Tests Policy

- You SHOULD write or update the planned behavioral tests first when behavior changes, unless the plan explicitly explains why TDD is not practical for that phase.
- You SHOULD harden tests enough to catch partial, misleading, or parity-incomplete implementations for the scoped behavior.
- You MAY refactor for testability.
- You MUST NOT change product code merely to satisfy a failing test if acceptance criteria + observed behavior indicate the code is correct.
  - In that case, fix the test or update the test assumptions (and log the decision).

### 5) Completion

When all items in `## Progress` are complete:

- Ensure the plan file reflects completion accurately.
- Run any verification commands listed in the plan's `Verification Strategy` and/or phase `### Verify` sections.
- Report the final state to the user.
