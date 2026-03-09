---
description: Execute a plan with quality-gated phases — each phase gets 1 implementation pass and up to 3 review/fix passes before advancing
argument-hint: '<slug | thoughts/plans/<slug>.md | path/to/plan.md>'
---

# Run Plan (Quality-Gated Loop)

Execute a plan document phase-by-phase, where each phase is quality-gated: do 1 implementation pass, then run up to 3 review/fix passes, stopping early if the reviewer finds zero issues. If pass 3 still finds issues, treat the review budget as exhausted, record that outcome, and continue to the next phase without pausing. Capture non-blocking discoveries and out-of-scope follow-up opportunities in a discovery ledger so they can be triaged later without derailing execution.

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

Derive:

- `plan_slug` = the basename of `plan_path` without `.md`
- `discovery_path` = `thoughts/discoveries/<plan_slug>.md`

### 2) Read Plan

Read `plan_path` fully.

Before execution, confirm the plan is actually executable:

- `## Progress` exists and has at least one unchecked item or all items are already complete.
- `Resume Instructions (Agent)` exists.
- Each active phase includes `### End State`, `### Tests first`, `### Work`, and `### Verify`.
- The plan does not contain unresolved `Open Questions`, `Decision Points`, or equivalent unresolved-decision sections.

If important questions remain unresolved, do not start implementation. Ask the user for the missing decision or direct them to update the plan first.

Identify the first unchecked item in `## Progress` and begin execution immediately — do not pause to recap the plan.

### 2.5) Discovery Protocol

Use this protocol whenever implementation or review reveals work beyond the current phase's required outcome:

- **Bucket A — Consequential work**
  - Required to satisfy the current phase's `### End State`, pass its planned tests, complete `### Verify`, or preserve correctness/invariants in touched code.
  - Do it now.
- **Bucket B — Beneficial local improvement**
  - Behavior-preserving cleanup, refactor, or consistency improvement tightly related to the touched area.
  - You may do it now if it is small, clear, and does not materially expand external behavior.
- **Bucket C — Deferred discovery**
  - Valuable, but not required to finish the current phase.
  - Do not implement it now. Append it to `discovery_path`, add a short reference in the plan's `## Decisions / Deviations Log`, and continue immediately.
- **Bucket D — Blocking decision**
  - Requires a material product, architecture, security, billing, or scope decision, or conflicts with a locked plan constraint.
  - Stop and ask the user.

When you create `discovery_path`, initialize it with:

```md
# Discovery Ledger: <plan_slug>

- Source plan: <plan_path>
- Status: Open
```

Record each deferred discovery as:

```md
## D-YYYYMMDD-<phase>-<index>
- Phase: <phase number or progress item>
- Title: <short title>
- Type: cleanup | bug | refactor | perf | docs | follow-up feature | other
- Status: deferred
- Evidence:
  - <file/path or review finding>
- Why not now: <why it is outside Bucket A/B>
- Recommended follow-up: <next step>
- External scope impact: none | internal only | user-visible | unclear
```

### 3) Execute Phase-by-Phase with Quality Gate

For each phase (tracked by `## Progress`), run 1 implementation pass followed by up to 3 review/fix passes. A phase advances either when a review pass finds zero issues or when the 3-pass review budget is exhausted.

#### Iteration 1: Implement

Delegate to the `developer` agent with this prompt:

> Implement phase N of this plan: `<plan_path>`
>
> Read the plan file fully. Find phase N and implement the behavior described in its `### Tests first`, `### Work`, and `### End State` sections.
>
> Treat the plan as the source of truth for intended outcomes, locked constraints, and external scope. Do not treat it as an exhaustive list of every file edit.
>
> You may make the smallest adjacent implementation changes that are necessary or clearly beneficial while doing the work, including wiring, refactors, cleanup, consistency fixes, and testability improvements.
>
> These adjacent changes must stay tightly related to the phase and must not materially expand external functional behavior beyond what the plan specifies or clearly implies.
>
> If you discover worthwhile work that is not required to complete the current phase, classify it using the Discovery Protocol. Record Deferred Discoveries in `<discovery_path>` instead of implementing them now. Only ask the user if the discovery is a true Blocking Decision.
>
> Start from the behavioral tests described in `### Tests first`. If those tests do not yet exist, write them first unless the plan explicitly explains why TDD is not practical for this phase.
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
> - Behavior-preserving cleanup, refactors, or consistency improvements that are tightly related to the phase
> - Speculative enhancements or broader external behavior changes that are not required by the plan or concrete discoveries needed to complete the phase
> - Test coverage beyond what the plan specifies
>
> For each real issue found, fix it directly. Do not just report issues — fix them.
>
> If you find a worthwhile issue or opportunity that should not be fixed in the current phase, record it in `<discovery_path>` as a Deferred Discovery instead of expanding scope. Mention each deferred item in your summary.
>
> At the end, output a summary. If you found and fixed issues, list them. If you found zero issues, state clearly: "No issues found."

**Loop termination:** After each quality-reviewer pass, check its output:

- If it found zero issues → the phase quality gate is passed
- If it found and fixed issues and fewer than 3 review passes have run → run another review pass
- If it found and fixed issues on review pass 3 → accept that the phase hit the review-pass limit, record that outcome in the plan's `## Decisions / Deviations Log`, append any unresolved or deferred follow-up items to `discovery_path`, and proceed immediately to phase completion without asking the user for permission or pausing the run

#### Phase Completion

Once the phase is ready to advance (either zero issues found, or review pass 3 completed with remaining issues):

1. Flip the phase's checkbox from `- [ ]` to `- [x]` in `## Progress`.
2. If implementation required a decision, revealed a constraint, created a Deferred Discovery, or exhausted the 3-pass review budget without reaching "No issues found.", append a structured entry to `## Decisions / Deviations Log` in the plan file.
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
- Include an `Unresolved Issues / Deferred Discoveries` summary in the final readout.
  - If `discovery_path` exists, summarize each open deferred discovery and reference `discovery_path`.
  - Summarize any phases that exhausted the 3-pass review budget without reaching "No issues found." and reference the plan's `## Decisions / Deviations Log`.
  - If no unresolved issues or deferred discoveries remain, state that explicitly.
