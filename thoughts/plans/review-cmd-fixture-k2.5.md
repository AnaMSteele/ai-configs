# Review Command Fixture (K2.5)

## Goal
- Add feature-flag-aware retry logic to outbound webhooks.
[REVIEW:Kimi Reviewer] GAP: The goal requires feature-flag-aware behavior, but the plan does not define flag source, default state, or rollback expectations. Add explicit work and verification for flag-on and flag-off paths. [/REVIEW]

## Non-goals
- Do not redesign webhook payload schema.

## Acceptance Criteria
- Retries occur up to 3 times for transient 5xx errors.
- Permanent 4xx errors are not retried.
[REVIEW:Kimi Reviewer] AMBIGUITY: "transient 5xx errors" is underspecified. Define exactly which failures are retryable (status codes, timeouts, connection resets) so implementations do not diverge. [/REVIEW]

## Phase 1: Discovery
### End State
- Existing retry behavior and call sites are documented.
### Work
- Inspect webhook sender and queue worker modules.
[REVIEW:Kimi Reviewer] AMBIGUITY: "webhook sender and queue worker modules" lacks concrete file paths, making execution and resume behavior non-deterministic. [/REVIEW]
### Verify
- `echo "discovery verified"`
[REVIEW:Kimi Reviewer] INCORRECT: `echo "discovery verified"` does not verify discovery outcomes. Require an observable artifact proving retry behavior and call sites were actually documented. [/REVIEW]

## Phase 2: Implementation
### End State
- Retry policy integrated into sender path.
### Work
- Add backoff helper and invoke from webhook sender.
[REVIEW:Kimi Reviewer] RISK: Backoff policy is undefined (initial delay, cap, jitter). Without this, retries can create burst load and inconsistent latency impact. [/REVIEW]
- Add unit tests for 4xx/5xx behavior.
[REVIEW:Kimi Reviewer] GAP: Test scope mentions 4xx/5xx behavior but omits feature-flag gating. Add tests for both enabled and disabled flag states. [/REVIEW]
### Verify
- `echo "implementation verified"`
[REVIEW:Kimi Reviewer] INCORRECT: `echo "implementation verified"` cannot validate acceptance criteria. Verification must run concrete tests/assertions that prove retry and non-retry behavior. [/REVIEW]

## Progress
- [ ] phase-1 Discovery
- [ ] phase-2 Implementation

## Resume Instructions (Agent)
- Start at the first unchecked phase and continue until all phases are complete.

## Plan Changelog
- 2026-02-27: Initial fixture for review command testing.
