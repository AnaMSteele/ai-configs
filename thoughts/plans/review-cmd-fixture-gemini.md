# Review Command Fixture (Gemini)

## Goal
- Add feature-flag-aware retry logic to outbound webhooks.
[REVIEW:GEMINI] GAP: The goal requires feature-flag-aware behavior, but no acceptance criterion defines flag-on vs flag-off outcomes, default state, or rollback behavior. Add explicit criteria proving retries are gated by the flag. [/REVIEW]

## Non-goals
- Do not redesign webhook payload schema.

## Acceptance Criteria
- Retries occur up to 3 times for transient 5xx errors.
- Permanent 4xx errors are not retried.
[REVIEW:GEMINI] AMBIGUITY: Error classification is underspecified. "Transient 5xx" needs a concrete mapping (which statuses/timeouts/network failures qualify) or implementation and tests may diverge. [/REVIEW]

## Phase 1: Discovery
### End State
- Existing retry behavior and call sites are documented.
### Work
- Inspect webhook sender and queue worker modules.
[REVIEW:GEMINI] WRONG REFERENCE: This repository scan did not surface concrete "webhook sender" or "queue worker" modules, so these targets are not currently grounded to real paths. Add explicit file/module paths to make execution runnable. [/REVIEW]
### Verify
- `echo "discovery verified"`
[REVIEW:GEMINI] GAP: `echo "discovery verified"` does not verify discovery outcomes. Replace with observable checks (for example, documented call-site inventory artifact or grep/inspection commands that prove coverage). [/REVIEW]

## Phase 2: Implementation
### End State
- Retry policy integrated into sender path.
### Work
- Add backoff helper and invoke from webhook sender.
- Add unit tests for 4xx/5xx behavior.
[REVIEW:GEMINI] RISK: Work items do not specify backoff policy details (delay schedule, jitter, max retry window) or idempotency safeguards; retry logic without these constraints can amplify duplicate deliveries under failure. [/REVIEW]
### Verify
- `echo "implementation verified"`
[REVIEW:GEMINI] INCORRECT: `echo "implementation verified"` provides no behavioral proof. Verification must run concrete tests/assertions demonstrating 3-attempt 5xx retry behavior and 4xx no-retry behavior under both flag states. [/REVIEW]

## Progress
- [ ] phase-1 Discovery
- [ ] phase-2 Implementation

## Resume Instructions (Agent)
- Start at the first unchecked phase and continue until all phases are complete.

## Plan Changelog
- 2026-02-27: Initial fixture for review command testing.
