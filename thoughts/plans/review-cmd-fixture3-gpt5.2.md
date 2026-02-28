# Review Command Fixture 3 (GPT5.2)

## Goal
- Add feature-flag-aware retry logic to outbound webhooks.
[REVIEW:GPT5.2] GAP/AMBIGUITY: Goal requires "feature-flag-aware" retry logic, but the plan never defines the flag name/source, default behavior, rollout/kill-switch expectations, or how behavior changes when the flag is off. Add explicit acceptance criteria and implementation steps for flag evaluation and safe rollback. [/REVIEW]

## Non-goals
- Do not redesign webhook payload schema.

## Acceptance Criteria
- Retries occur up to 3 times for transient 5xx errors.
- Permanent 4xx errors are not retried.
[REVIEW:GPT5.2] AMBIGUITY/RISK: "Retries occur up to 3 times" is unclear (3 retries vs 3 total attempts). "Transient 5xx" is underspecified (all 5xx? exclude 501/505? what about 429/408/timeouts/DNS/TLS errors). Specify the exact retryable conditions and backoff/jitter constraints to avoid thundering herds. [/REVIEW]

## Phase 1: Discovery
### End State
- Existing retry behavior and call sites are documented.
### Work
- Inspect webhook sender and queue worker modules.
### Verify
- `echo "discovery verified"`
[REVIEW:GPT5.2] NEEDS REWORK: Phase 1 Verify is a placeholder (`echo ...`) and does not prove discovery happened. Define concrete discovery outputs (files/functions identified, current retry semantics, where errors are classified) and a verification step that checks those artifacts exist (e.g., captured notes in the plan or a checklist), not a no-op shell command. [/REVIEW]

## Phase 2: Implementation
### End State
- Retry policy integrated into sender path.
### Work
- Add backoff helper and update sender retry loop.
- Add tests for 4xx and 5xx behavior.
### Verify
- `echo "implementation verified"`
[REVIEW:GPT5.2] GAP/RISK: Phase 2 Work is too high-level: it doesn't say whether retries happen in the sender, queue worker, or both, nor how to prevent duplicate deliveries (idempotency keys? at-least-once semantics) when retrying. Also, the tests section should name the test harness and include cases for attempt counting, non-retryable 4xx, retryable 5xx, and flag on/off behavior. Phase 2 Verify is also a placeholder (`echo ...`)—it should run the relevant unit/integration tests and ideally a local simulation of 4xx/5xx responses. [/REVIEW]

## Progress
- [ ] phase-1-discovery
- [ ] phase-2-implementation

Resume Instructions (Agent):
Continue from first incomplete phase and keep progress checkboxes updated.
[REVIEW:GPT5.2] AMBIGUITY: Resume Instructions are underspecified. Clarify how to determine "complete" for a phase (must finish Work + Verify), and remind that checkboxes live only in `## Progress` and should be toggled only after Verify passes. [/REVIEW]
