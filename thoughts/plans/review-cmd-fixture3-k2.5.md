# Review Command Fixture 3 (K2.5)

## Goal
- Add feature-flag-aware retry logic to outbound webhooks.
[REVIEW:Kimi Reviewer] GAP: The goal explicitly states "feature-flag-aware" retry logic, but there is absolutely no mention of feature flags in any phase. How will feature flags be checked? Where is the configuration? How does the retry logic toggle based on flag state? This is a critical omission that makes the plan unexecutable as written. [/REVIEW]

## Non-goals
- Do not redesign webhook payload schema.

## Acceptance Criteria
- Retries occur up to 3 times for transient 5xx errors.
- Permanent 4xx errors are not retried.

## Phase 1: Discovery
### End State
- Existing retry behavior and call sites are documented.
### Work
- Inspect webhook sender and queue worker modules.
[REVIEW:Kimi Reviewer] WRONG REFERENCE: Codebase exploration found no webhook sender or queue worker modules. Before proceeding, verify these modules exist or update the plan with correct paths. [/REVIEW]
### Verify
- `echo "discovery verified"`
[REVIEW:Kimi Reviewer] RISK: Verification step is just an echo statement - it cannot verify that discovery was actually completed or that documentation exists. Need concrete verification criteria. [/REVIEW]

## Phase 2: Implementation
### End State
- Retry policy integrated into sender path.
### Work
- Add backoff helper and update sender retry loop.
[REVIEW:Kimi Reviewer] GAP: Phase 2 work mentions adding backoff helper and retry loop, but still no mention of the feature flag integration that was promised in the goal. The End State claims "Retry policy integrated" but omits the feature flag aspect entirely. This is scope drift from the stated goal. [/REVIEW]
- Add tests for 4xx and 5xx behavior.
### Verify
- `echo "implementation verified"`
[REVIEW:Kimi Reviewer] RISK: Verification step uses a meaningless echo statement that cannot actually verify implementation correctness. Need real verification: run tests, check logs, or validate retry behavior. [/REVIEW]

## Progress
- [ ] phase-1-discovery
- [ ] phase-2-implementation

Resume Instructions (Agent):
Continue from first incomplete phase and keep progress checkboxes updated.
[REVIEW:Kimi Reviewer] AMBIGUITY: Resume instructions mention continuing from "first incomplete phase" but don't specify how to determine incompleteness (checkbox state? file existence?). Clarify the decision logic for resumption. [/REVIEW]
