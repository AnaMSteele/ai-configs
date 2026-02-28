# Review Command Fixture 2 (Codex)

## Goal
- Add feature-flag-aware retry logic to outbound webhooks.

## Non-goals
- Do not redesign webhook payload schema.

## Acceptance Criteria
[REVIEW:CODEX] GAP: The goal requires feature-flag-aware behavior, but acceptance criteria do not define expected outcomes for flag OFF vs flag ON. Add explicit criteria for both states. [/REVIEW]
[REVIEW:CODEX] AMBIGUITY: "Transient 5xx errors" is underspecified; define retryable failure classes (HTTP status codes vs transport failures like timeouts/resets) so implementations do not diverge. [/REVIEW]
- Retries occur up to 3 times for transient 5xx errors.
- Permanent 4xx errors are not retried.

## Phase 1: Discovery
### End State
- Existing retry behavior and call sites are documented.
### Work
[REVIEW:CODEX] WRONG REFERENCE: "Inspect webhook sender and queue worker modules" is not executable without concrete file paths/symbols. Name exact modules/functions to make discovery runnable and resumable. [/REVIEW]
- Inspect webhook sender and queue worker modules.
### Verify
[REVIEW:CODEX] INCORRECT: `echo "discovery verified"` does not validate the documented discovery end state. Replace with concrete checks proving call-site/module inventory was produced. [/REVIEW]
- `echo "discovery verified"`

## Phase 2: Implementation
### End State
[REVIEW:CODEX] AMBIGUITY: "Retry policy integrated into sender path" does not define retry ownership boundaries. Specify the single retry owner to avoid nested/double retries. [/REVIEW]
- Retry policy integrated into sender path.
### Work
[REVIEW:CODEX] RISK: Retrying outbound webhooks can duplicate downstream side effects. Add explicit idempotency expectations and bounded backoff/jitter parameters. [/REVIEW]
- Add backoff helper and update sender retry loop.
[REVIEW:CODEX] GAP: Test scope omits feature-flag ON/OFF coverage even though feature-flag-aware behavior is the stated goal. Add tests for both branches. [/REVIEW]
- Add tests for 4xx and 5xx behavior.
### Verify
[REVIEW:CODEX] INCORRECT: `echo "implementation verified"` does not verify acceptance criteria. Replace with explicit test commands/assertions for max-3 retries on retryable failures, zero retries on 4xx, and flag-state behavior. [/REVIEW]
- `echo "implementation verified"`

## Progress
- [ ] phase-1-discovery
- [ ] phase-2-implementation

Resume Instructions (Agent):
Continue from first incomplete phase and keep progress checkboxes updated.
