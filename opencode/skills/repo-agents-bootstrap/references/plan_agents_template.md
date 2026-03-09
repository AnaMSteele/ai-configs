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
- at least one edge or boundary case
- at least one failure/guardrail case
- at least one counterexample or ambiguity case when matching, parsing, identity, refs, policy, or routing could produce misleading passes
- at least one scale or fan-out case when query shape, aggregation, or volume could change correctness or viability
- cross-surface parity scenarios when the same behavior must hold across multiple interfaces (for example HTTP/CLI/MCP/UI)

Add IDs so scenarios can be referenced from tests (for example `BDD-AC3-1`).

## Phase template

Every phase must include:

### End state

What is true when this phase is complete.

### Tests first (TDD)

- List failing tests to write first.
- Map each test to acceptance criteria and BDD scenarios.
- Include counterexample, boundary/scale, parity, and contract-drift checks whenever the phase can fail in those ways.
- Use the `tdd-test-writer` skill when available to pressure-test the RED-phase contract before implementation.
- If TDD is skipped, explain why and define compensating verification.

### Work

- Ordered implementation steps.
- Keep scope bounded to the phase.

### Expected files

- Likely files/modules touched to improve resumability.
- If the phase spans multiple required surfaces, include the parity inventory (for example route/handler, CLI entrypoint, MCP tool wrapper, registry/dispatcher, docs/tests).
- Treat this list as guidance for resumability, not as an exhaustive constraint on necessary edits.

### Verify

- Exact commands and/or manual checks proving completion.
- Commands must be copy/paste ready and validated against current repo/package/target names.
- Prefer targeted automated checks first, then broader quality gates; manual checks are supplemental rather than the sole proof when automation is practical.

## Execution loop

For each phase:

1. Write/refine tests first (RED) and harden them against misleading partial passes.
2. Run targeted tests and confirm expected failure.
3. Implement minimal behavior slice (GREEN).
4. Run reviewer loop until it reports `No issues found.` or only explicitly logged low-risk deferred items remain.
5. Run required quality gates.
6. Update progress and decision/deviation log.

## Low-risk deferral bar

A phase may advance with deferred items only if every remaining item is low risk.

Not low risk:

- acceptance criteria gaps or incorrect behavior,
- correctness, data integrity, security, concurrency, observability, or performance viability issues,
- missing required-surface parity,
- stale or invalid `### Verify` guidance,
- schema, fixture, payload, response-contract, or evidence-source drift that would mislead later phases.

Every low-risk deferred item must be logged with evidence, rationale, and a recommended follow-up.

## Ready/Done bars

### Definition of ready

- No unresolved critical decisions.
- Acceptance criteria and BDD scenarios are concrete.
- Phase verify steps are executable and current for real repo targets.
- Progress and resume instructions are present.
- Multi-surface phases make parity expectations explicit.
- Canonical contracts or evidence sources are locked when later phases depend on them.
- If `Status: ready`, no `Open Questions` remain.

### Definition of done

- Behavioral tests pass and represent genuine user-visible correctness.
- Quality gates pass for the scoped change.
- Deviations are logged with rationale.
- Any remaining deferred items are explicitly low risk and logged.
- Downstream phases reviewed if decisions changed.
