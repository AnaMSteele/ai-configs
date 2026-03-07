# Review Command Fixture (GPT5.4)

## Goal
- Add feature-flag-aware retry logic to outbound webhooks.
[REVIEW:GPT5.4] GAP: The goal is feature-flag-aware retry logic, but no phase or acceptance item defines flag source, default/off behavior, or verification for enabled vs disabled states. Add explicit rollout behavior and tests for both flag states. [/REVIEW]

## Non-goals
- Do not redesign webhook payload schema.

## Acceptance Criteria
- Retries occur up to 3 times for transient 5xx errors.
- Permanent 4xx errors are not retried.
[REVIEW:GPT5.4] GAP: Acceptance criteria define retry eligibility but omit backoff/jitter expectations even though implementation introduces a backoff helper. Add bounded delay expectations to avoid throughput and downstream-pressure regressions. [/REVIEW]

## Phase 1: Discovery
### End State
- Existing retry behavior and call sites are documented.
### Work
- Inspect webhook sender and queue worker modules.
[REVIEW:GPT5.4] WRONG REFERENCE: "webhook sender and queue worker modules" are not mapped to concrete file paths/symbols. Repository evidence indicates webhook mentions are largely fixture/documentation text, so execution is currently non-actionable. Name exact targets. [/REVIEW]
### Verify
- `echo "discovery verified"`
[REVIEW:GPT5.4] INCORRECT: `echo "discovery verified"` is not a verification of discovery outcomes. Replace with observable checks (for example, committed module/callsite inventory with concrete paths). [/REVIEW]

## Phase 2: Implementation
### End State
- Retry policy integrated into sender path.
[REVIEW:GPT5.4] AMBIGUITY: "integrated into sender path" does not define retry ownership boundaries between sender and queue worker. Specify the single retry owner and guardrails to prevent nested/double retries. [/REVIEW]
### Work
- Add backoff helper and invoke from webhook sender.
- Add unit tests for 4xx/5xx behavior.
### Verify
- `echo "implementation verified"`
[REVIEW:GPT5.4] RISK: `echo "implementation verified"` does not validate acceptance criteria. Add explicit test command(s) that assert max-3 retries for transient 5xx and zero retries for permanent 4xx, plus feature-flag behavior. [/REVIEW]

## Progress
- [ ] phase-1 Discovery
- [ ] phase-2 Implementation

## Resume Instructions (Agent)
- Start at the first unchecked phase and continue until all phases are complete.
[REVIEW:GPT5.4] GAP: Resume instructions should explicitly require updating `## Progress` checkboxes immediately after each phase to keep the plan resumable after interruption. [/REVIEW]

## Plan Changelog
- 2026-02-27: Initial fixture for review command testing.
