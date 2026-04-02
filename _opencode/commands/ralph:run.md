---
description: Execute a plan with quality-gated phases - each phase gets 1 implementation pass and repeated review/fix passes until only low-risk items remain
argument-hint: '<slug | thoughts/plans/<slug>.md | path/to/plan.md>'
---

# Run Plan (Quality-Gated Loop)

Execute a plan document phase-by-phase. For each phase, do 1 implementation pass, then repeat review/fix passes until the reviewer finds zero issues or explicitly confirms that only low-risk deferred items remain. Do not advance with unresolved substantive issues. Capture low-risk deferred discoveries and out-of-scope follow-up opportunities in a discovery ledger so they can be triaged later without derailing execution.

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
- Each active phase's `### Verify` steps are concrete and current for the repository's actual targets, package names, paths, and commands.
- If a phase spans multiple required public surfaces (for example HTTP/CLI/MCP/UI), the plan makes parity expectations explicit in `### Tests first`, `### Work`, or `### Expected files`.

If important questions remain unresolved, do not start implementation. Ask the user for the missing decision or direct them to update the plan first.

If a `### Verify` command or obvious plan reference is stale but the correction is clear from repo reality, update the plan before execution and log the correction in `## Decisions / Deviations Log`.

Identify the first unchecked item in `## Progress` and begin execution immediately - do not pause to recap the plan.

### 2.5) Discovery Protocol

Use this protocol whenever implementation or review reveals work beyond the current phase's required outcome:

- **Bucket A - Consequential work**
  - Required to satisfy the current phase's `### End State`, pass its planned tests, complete `### Verify`, or preserve correctness/invariants in touched code.
  - Do it now.
- **Bucket B - Beneficial local improvement**
  - Behavior-preserving cleanup, refactor, or consistency improvement tightly related to the touched area.
  - You may do it now if it is small, clear, and does not materially expand external behavior.
- **Bucket C - Deferred discovery**
  - Valuable, but not required to finish the current phase.
  - Do not implement it now. Append it to `discovery_path`, add a short reference in the plan's `## Decisions / Deviations Log`, and continue immediately.
- **Bucket D - Blocking decision**
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
- Risk: low
- Evidence:
  - <file/path or review finding>
- Why not now: <why it is outside Bucket A/B>
- Recommended follow-up: <next step>
- External scope impact: none | internal only | user-visible | unclear
```

### 2.6) Low-Risk Deferral Bar

A phase may advance with deferred items only if every remaining item is low risk.

Low-risk means all of the following are true:

- It does not leave an acceptance criterion partially implemented or incorrectly implemented.
- It does not undermine correctness, data integrity, security, concurrency safety, performance viability, or required observability.
- It is not a broken or missing required-surface parity item.
- It is not stale or invalid `### Verify` guidance.
- It is not schema, fixture, response-contract, or evidence-source drift that would mislead later phases.
- It can be safely deferred without changing the truthfulness of the current phase's tests, verification, or end state.

If any remaining issue fails this bar, it is not deferrable - keep iterating or ask the user if the disagreement is truly a blocking decision.

### 3) Execute Phase-by-Phase with Quality Gate

For each phase (tracked by `## Progress`), run 1 implementation pass followed by as many review/fix passes as needed. A phase advances only when a review pass finds zero issues or explicitly confirms that only low-risk deferred items remain.

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
> Use the `tdd-test-writer` skill when available to pressure-test the RED-phase contract before changing production code.
>
> Confirm that the tests represent the intended user-visible behavior before changing production code. Strengthen them when needed so they cover the planned happy path, failure/guardrail behavior, counterexample or ambiguity cases, boundary/scale behavior when applicable, and required cross-surface parity or contract-drift checks.
>
> If implementation evidence or later review findings show the original test scope in this phase was too narrow, revisit the planned tests, widen coverage, and update the phase work instead of stopping at a narrow patch.
>
> If you widen tests or phase work because implementation evidence shows the original test scope or original plan was too narrow, treat that as a reassessment, update `## Decisions / Deviations Log` in the plan immediately with what changed, and keep that entry current before the next review pass.
>
> If the phase spans multiple required surfaces (for example HTTP/CLI/MCP/UI), treat parity work and missing registry/dispatcher/wrapper wiring as in-scope Bucket A work unless the plan explicitly says otherwise.
>
> If locked schemas, payloads, response shapes, or evidence sources have changed since earlier phases, update stale fixtures/tests in the touched scope during this phase and log the adjustment.
>
> Validate the phase's `### Verify` targets against repo reality before relying on them. If a correction is obvious, update the plan and log it.
>
> When you encounter ambiguity, resolve it by examining existing code patterns and the source documents referenced by the plan. Only ask the user if the decision is truly unresolvable.
>
> After implementation, run the phase's `### Verify` steps if they exist.

After the developer agent completes, proceed immediately to the first review pass - do not pause.

#### Review Passes: Review and Fix

Before each review pass after the first, summarize the immediately prior review pass into `<prior_review_memory>` with the substantive issue class, affected surface(s), and whether test scope or plan scope was widened. For the first review pass, set `<prior_review_memory>` to `none`.

Delegate to the `quality-reviewer` agent with this prompt:

> Review the implementation of phase N of this plan: `<plan_path>`
>
> Read the plan file fully. Find phase N and its `### Tests first`, `### Work`, `### End State`, and `### Verify` sections. Review the implementation for:
>
> Prior review memory for this phase: `<prior_review_memory>`
>
> Use `<prior_review_memory>` as the authoritative summary of the immediately prior review pass when comparing current findings against prior findings. Do not rely on unstated conversation memory.
>
> 1. Gaps - anything described in the plan that was not implemented or was implemented incorrectly
> 2. Quality issues - bugs, logic errors, missing error handling, broken integrations
> 3. Problems - regressions, inconsistencies with the rest of the codebase, violations of existing patterns
> 4. TDD/plan fidelity issues - cases where the implementation skipped the planned tests-first approach without justification, or where the passing tests do not actually prove the intended behavior
> 5. Test-strength issues - missing counterexamples, ambiguity checks, boundary checks, parity checks, or contract-drift coverage that the phase clearly needs to prevent misleading passes
> 6. Phase-gate issues - stale verify commands, missing required-surface parity, stale fixtures/contracts, or unresolved evidence-source mismatches that would make the phase unsafe to advance
> 7. Feedback-loop issues - whether a substantive miss shows the original test scope or original plan was too narrow, including same-class reappearing findings or cross-surface recurrences compared with the prior review pass in this phase
>
> Do NOT flag:
> - Style preferences or subjective improvements
> - Behavior-preserving cleanup, refactors, or consistency improvements that are tightly related to the phase
> - Speculative enhancements or broader external behavior changes that are not required by the plan or concrete discoveries needed to complete the phase
> - Test coverage beyond what the plan specifies or clearly implies
>
> Fix every non-low-risk issue directly. Do not just report issues - fix them.
>
> If you find an item that is truly low risk under the phase gate rules and should not be fixed in the current phase, record it in `<discovery_path>` as a Deferred Discovery instead of expanding scope. Mention each deferred item in your summary.
>
> For every substantive miss you fix, explicitly reassess the original test scope and the original plan assumptions for this phase.
>
> If that reassessment widens test scope or plan scope during review, update `## Decisions / Deviations Log` in the plan immediately so a mid-phase resume preserves the widened scope.
>
> Compare each current substantive finding against the immediately prior review-pass findings for this phase.
>
> If the same class of substantive issue is reappearing, or a related miss recurs on another required surface compared with the prior review pass in this phase, treat that as evidence that the original tests or original plan were too narrow.
>
> Escalate those repeated or cross-surface misses beyond a local patch: broaden coverage, update the plan when the phase assumptions were incomplete, and record the reassessment in `## Decisions / Deviations Log` immediately rather than waiting for phase completion.
>
> At the very top of your final response, output exactly one of these lines:
> - `VERDICT: PASS_NO_ISSUES`
> - `VERDICT: PASS_LOW_RISK_ONLY`
> - `VERDICT: RE_REVIEW_REQUIRED`
> - `VERDICT: BLOCKED`
>
> Verdict rules:
> - Use `VERDICT: PASS_NO_ISSUES` only if you found no issues and made no code or plan changes.
> - Use `VERDICT: PASS_LOW_RISK_ONLY` only if no substantive issues remain and every deferred item is low risk under the phase-gate rules.
> - Use `VERDICT: RE_REVIEW_REQUIRED` if you found and fixed any substantive issue during this pass. Do not use a pass verdict in the same response.
> - Use `VERDICT: BLOCKED` only if progress now depends on a true Blocking Decision that cannot be resolved from the codebase, plan, or source documents.
>
> After the verdict line, include:
> - A short `Status:` line.
> - If you used `VERDICT: RE_REVIEW_REQUIRED`, a `Fixed substantive issues:` section listing each fix clearly.
> - If you used `VERDICT: PASS_LOW_RISK_ONLY`, a `Deferred low-risk items:` section listing each deferred item and why it is low risk.
> - If you used `VERDICT: BLOCKED`, a `Blocking decision:` section with the exact question that must be answered.
> - If you widened tests or plan scope, a `Reassessment:` section stating how the original test scope or original plan changed and whether it was logged in `## Decisions / Deviations Log`.

**Loop termination:** After each quality-reviewer pass, check the first verdict line in its output:

- `VERDICT: PASS_NO_ISSUES` -> the phase quality gate is passed
- `VERDICT: PASS_LOW_RISK_ONLY` -> the phase quality gate is passed only after each low-risk item is recorded in `discovery_path` and referenced in the plan's `## Decisions / Deviations Log`
- `VERDICT: RE_REVIEW_REQUIRED` -> run another review pass
- `VERDICT: BLOCKED` -> stop and ask the user the blocking decision question
- Any missing, malformed, or contradictory verdict -> treat as `VERDICT: RE_REVIEW_REQUIRED` and run another review pass with an instruction to follow the verdict format exactly
- There is no fixed review-pass limit. Keep iterating until the gate passes or a true Blocking Decision is reached.

Within a phase, use the immediately prior review pass as loop memory for substantive findings.

If the same class of substantive miss is reappearing or a related miss recurs on another required surface, do not treat it as an isolated fix; first widen the original test scope and update the original plan/deviation log as needed.

Only after that reassessment still fails to converge should the loop treat the issue as potentially blocked.

If the loop stops converging because the same substantive issue keeps reappearing and the conflict cannot be resolved from the codebase or plan, treat that as a Blocking Decision and ask the user.

#### Phase Completion

Once the phase is ready to advance (either zero issues found, or only low-risk deferred items remain):

1. Flip the phase's checkbox from `- [ ]` to `- [x]` in `## Progress`.
2. If implementation required a decision, revealed a constraint, created a Deferred Discovery, corrected stale verify guidance, required contract/evidence-source drift cleanup, or triggered any test-scope or plan-scope reassessment during implementation or review, ensure `## Decisions / Deviations Log` already contains a structured entry recorded when the event happened; if it does not, append one now, including any test-scope or plan-scope reassessment triggered during implementation or review.
3. Proceed immediately to the next phase - do not pause.

### 4) Tests Policy

- You SHOULD write or update the planned behavioral tests first when behavior changes, unless the plan explicitly explains why TDD is not practical for that phase.
- You SHOULD harden tests enough to catch partial, misleading, or parity-incomplete implementations for the scoped behavior.
- Substantive review findings must trigger explicit reassessment of the original test scope and, when needed, the original plan for the current phase.
- If a miss is reappearing or recurs across required surfaces compared with the prior review pass, treat it as evidence to widen tests or plan scope rather than only patching locally.
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
  - Summarize any low-risk deferred items that remained at phase completion and reference the plan's `## Decisions / Deviations Log`.
  - If no unresolved issues or deferred discoveries remain, state that explicitly.
