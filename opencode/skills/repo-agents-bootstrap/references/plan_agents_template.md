# Plan Standards AGENTS Template

Use this template for `thoughts/plans/AGENTS.md` (or the repo's plan-standards equivalent).

## Objective

- Plans are execution artifacts, not brainstorming docs.
- A ready plan must be executable by another agent without inventing missing semantics.

## Status semantics

- `draft`: discovery is allowed; open questions may exist.
- `ready`: no unresolved critical decisions; executable now.
- `in_progress`: execution underway; progress and deviations must be updated.
- `done`: verification complete and handoff evidence recorded.

## Required plan sections (in order)

1. Title
2. Status
3. Goal
4. Why this plan exists
5. Authority and inputs
6. Current implementation reality
7. Progress (stable checkbox IDs)
8. Resume instructions (agent)
9. Product intent alignment
10. Locked decisions
11. Acceptance criteria
12. BDD scenarios
13. Phase-by-phase execution plan
14. Verification strategy
15. Delivery order
16. Non-goals
17. Decisions / Deviations log (append-only)

Legacy heading aliases may appear in old plans (`Objective`, `Metadata`, `Current State`), but new plans should use canonical headings above.

## Product intent alignment

Every plan must reference `thoughts/specs/product_intent.md` and state:

- which intent outcomes this plan advances,
- what constraints from product intent cannot be violated,
- which non-goals are intentionally deferred.

If product intent is missing, create it before executing implementation phases.

## Acceptance criteria + BDD requirements

Define acceptance as observable user/system behavior.

For each acceptance criterion, include at least one scenario:

```md
Given <starting context>
When <actor action or event>
Then <observable outcome>
And <important invariant>
```

Include:

- happy path
- at least one edge case
- at least one failure/guardrail case

Add IDs so scenarios can be referenced from tests (for example `BDD-AC3-1`).

## Phase template

Every phase must include:

### End state

What is true when this phase is complete.

### Tests first (TDD)

- List failing tests to write first.
- Map each test to acceptance criteria and BDD scenarios.
- If TDD is skipped, explain why and define compensating verification.

### Work

- Ordered implementation steps.
- Keep scope bounded to the phase.

### Expected files

- Likely files/modules touched to improve resumability.

### Verify

- Exact commands and/or manual checks proving completion.
- Prefer targeted checks first, then broader quality gates.

## Execution loop

For each phase:

1. Write/refine tests first (RED).
2. Run targeted tests and confirm expected failure.
3. Implement minimal behavior slice (GREEN).
4. Run reviewer loop; close critical issues before proceeding.
5. Run required quality gates.
6. Update progress and decision/deviation log.

## Ready/Done bars

### Definition of ready

- No unresolved critical decisions.
- Acceptance criteria and BDD scenarios are concrete.
- Phase verify steps are executable.
- Progress and resume instructions are present.
- If `Status: ready`, no `Open Questions` remain.

### Definition of done

- Behavioral tests pass and represent genuine user-visible correctness.
- Quality gates pass for the scoped change.
- Deviations are logged with rationale.
- Downstream phases reviewed if decisions changed.
