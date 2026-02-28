# Review Command Fixture 2 (K2.5)

## Goal
- Add feature-flag-aware retry logic to outbound webhooks.
[REVIEW:Kimi Reviewer] GAP: The goal requires feature-flag-aware retries, but acceptance criteria and phase work never define flag OFF vs ON behavior, flag source, or rollout default. Add explicit acceptance and verification for both flag states. [/REVIEW]

## Non-goals
- Do not redesign webhook payload schema.

## Acceptance Criteria
- Retries occur up to 3 times for transient 5xx errors.
- Permanent 4xx errors are not retried.
[REVIEW:Kimi Reviewer] AMBIGUITY: "Permanent 4xx errors" is not implementable as written (for example, 429 is 4xx but often retriable). Enumerate exact non-retriable and retriable status codes. [/REVIEW]

## Phase 1: Discovery
### End State
- Existing retry behavior and call sites are documented.
### Work
- Inspect webhook sender and queue worker modules.
[REVIEW:Kimi Reviewer] WRONG REFERENCE: "webhook sender and queue worker modules" is not tied to concrete file paths/symbols, so the phase is not reliably executable or resumable by another agent. [/REVIEW]
### Verify
- `echo "discovery verified"`
[REVIEW:Kimi Reviewer] INCORRECT: `echo "discovery verified"` does not verify the End State. Require an observable artifact/check (for example, documented call-site inventory committed in the plan/task output). [/REVIEW]

## Phase 2: Implementation
### End State
- Retry policy integrated into sender path.
### Work
- Add backoff helper and update sender retry loop.
[REVIEW:Kimi Reviewer] RISK: Adding retries/backoff without idempotency constraints and ownership boundaries (sender vs worker) can create duplicate deliveries or nested retries. Define single retry owner and idempotency expectations. [/REVIEW]
- Add tests for 4xx and 5xx behavior.
### Verify
- `echo "implementation verified"`
[REVIEW:Kimi Reviewer] INCORRECT: `echo "implementation verified"` cannot prove acceptance criteria. Verification must run concrete tests/assertions for 5xx retry ceiling, 4xx non-retry behavior, and feature-flag OFF/ON branching. [/REVIEW]

## Progress
- [ ] phase-1-discovery
- [ ] phase-2-implementation

Resume Instructions (Agent):
Continue from first incomplete phase and keep progress checkboxes updated.
