# Review Command Fixture 3 (Codex)

## Goal
- Add feature-flag-aware retry logic to outbound webhooks.
[REVIEW:CODEX] GAP: Plan work does not state where the feature flag is defined or how the sender path should gate retries when the flag is disabled; add explicit discovery/implementation steps to avoid ambiguous behavior. [/REVIEW]

## Non-goals
- Do not redesign webhook payload schema.

## Acceptance Criteria
- Retries occur up to 3 times for transient 5xx errors.
- Permanent 4xx errors are not retried.
[REVIEW:CODEX] GAP: Acceptance criteria omit the expected behavior when the feature flag is disabled (and which flag controls it), leaving success criteria ambiguous. [/REVIEW]

## Phase 1: Discovery
### End State
- Existing retry behavior and call sites are documented.
### Work
- Inspect webhook sender and queue worker modules.
### Verify
- `echo "discovery verified"`
[REVIEW:CODEX] INCORRECT: `echo` is not verification of discovery; define a concrete artifact to confirm (e.g., documented modules/paths or a short summary in the plan). [/REVIEW]

## Phase 2: Implementation
### End State
- Retry policy integrated into sender path.
### Work
- Add backoff helper and update sender retry loop.
[REVIEW:CODEX] AMBIGUITY: This step does not explicitly constrain retries to 3 attempts or 5xx-only and does not mention feature-flag gating; risk of implementing the wrong policy. [/REVIEW]
- Add tests for 4xx and 5xx behavior.
[REVIEW:CODEX] GAP: Tests listed only cover 4xx/5xx; missing cases for feature-flag disabled and enforcement of max retry attempts/backoff behavior. [/REVIEW]
### Verify
- `echo "implementation verified"`
[REVIEW:CODEX] INCORRECT: `echo` does not validate behavior; verification should run the tests that exercise retries and flag gating. [/REVIEW]

## Progress
- [ ] phase-1-discovery
- [ ] phase-2-implementation

Resume Instructions (Agent):
Continue from first incomplete phase and keep progress checkboxes updated.
