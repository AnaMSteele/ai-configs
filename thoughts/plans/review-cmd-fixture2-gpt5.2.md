# Review Command Fixture 2 (GPT5.2)

## Goal
- Add feature-flag-aware retry logic to outbound webhooks.

[REVIEW:GPT5.2] GAP: Goal requires feature-flag-aware behavior, but the plan never defines flag name, default state, or expected behavior when the flag is off vs on; implementation and verification cannot be judged correct without this contract. [/REVIEW]
## Non-goals
- Do not redesign webhook payload schema.

## Acceptance Criteria
- Retries occur up to 3 times for transient 5xx errors.
- Permanent 4xx errors are not retried.

[REVIEW:GPT5.2] GAP: Acceptance criteria omit feature-flag outcomes entirely and do not state retry timing/backoff expectations, leaving room for materially different implementations that all appear to "pass." [/REVIEW]
## Phase 1: Discovery
### End State
- Existing retry behavior and call sites are documented.
### Work
- Inspect webhook sender and queue worker modules.
[REVIEW:GPT5.2] AMBIGUITY: "Inspect webhook sender and queue worker modules" lacks concrete file paths or ownership boundaries, which makes discovery non-reproducible and hard to resume across agents. [/REVIEW]
### Verify
- `echo "discovery verified"`

[REVIEW:GPT5.2] RISK: Phase 1 verification uses `echo` only; it does not prove that retry behavior/call sites were actually documented, so later implementation can proceed on incomplete discovery. [/REVIEW]
## Phase 2: Implementation
### End State
- Retry policy integrated into sender path.
### Work
- Add backoff helper and update sender retry loop.
- Add tests for 4xx and 5xx behavior.
[REVIEW:GPT5.2] GAP: Implementation work does not define the transient-failure taxonomy (e.g., only HTTP 5xx vs network timeouts/connection resets), creating inconsistent retry behavior and potential production regressions. [/REVIEW]
### Verify
- `echo "implementation verified"`

[REVIEW:GPT5.2] RISK: Phase 2 verification again uses an `echo` placeholder; no required test command or scenario is specified to prove 4xx no-retry, 5xx capped retries, and flag-gated behavior. [/REVIEW]
## Progress
- [ ] phase-1-discovery
- [ ] phase-2-implementation

Resume Instructions (Agent):
Continue from first incomplete phase and keep progress checkboxes updated.
