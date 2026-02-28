# Review Command Fixture 3 (Gemini)

## Goal
- Add feature-flag-aware retry logic to outbound webhooks.

## Non-goals
- Do not redesign webhook payload schema.

## Acceptance Criteria
- Retries occur up to 3 times for transient 5xx errors.
- Permanent 4xx errors are not retried.

[REVIEW:GEMINI] GAP: The acceptance criteria doesn't explicitly mention the feature flag requirement from the goal. What should happen when the feature flag is disabled? [/REVIEW]

## Phase 1: Discovery
### End State
- Existing retry behavior and call sites are documented.
### Work
- Inspect webhook sender and queue worker modules.
### Verify
- `echo "discovery verified"`

[REVIEW:GEMINI] AMBIGUITY: Phase 1 Verify is a placeholder. It should verify the discovery output (e.g., checking if the documentation file exists or printing the discovered call sites). [/REVIEW]

## Phase 2: Implementation
### End State
- Retry policy integrated into sender path.
### Work
- Add backoff helper and update sender retry loop.
- Add tests for 4xx and 5xx behavior.

[REVIEW:GEMINI] GAP: The goal mentions "feature-flag-aware" retry logic, but there is no mention of implementing or checking feature flags in the Phase 2 Work. [/REVIEW]
### Verify
- `echo "implementation verified"`

[REVIEW:GEMINI] RISK: The verify step is a placeholder `echo`. It must include actual test commands to verify the 3 retry limit, 4xx/5xx behavior, and feature-flag awareness required by the Acceptance Criteria. [/REVIEW]

## Progress
- [ ] phase-1-discovery
- [ ] phase-2-implementation

Resume Instructions (Agent):
Continue from first incomplete phase and keep progress checkboxes updated.
