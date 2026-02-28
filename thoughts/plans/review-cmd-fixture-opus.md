# Review Command Fixture (Opus)

## Goal
- Add feature-flag-aware retry logic to outbound webhooks.
[REVIEW:CLAUDE] GAP: The goal requires feature-flag-aware retry logic, but acceptance criteria never verify behavior with the flag enabled versus disabled. Add explicit criteria for both flag states. [/REVIEW]

## Non-goals
- Do not redesign webhook payload schema.

## Acceptance Criteria
- Retries occur up to 3 times for transient 5xx errors.
- Permanent 4xx errors are not retried.
[REVIEW:CLAUDE] AMBIGUITY: "Permanent 4xx errors" is too broad for implementation consistency (for example, 429 is 4xx but often retried). Define exact retryable/non-retryable status codes and transport failures. [/REVIEW]

## Phase 1: Discovery
### End State
- Existing retry behavior and call sites are documented.
### Work
- Inspect webhook sender and queue worker modules.
[REVIEW:CLAUDE] WRONG REFERENCE: This workspace does not currently expose concrete "webhook sender" and "queue worker" modules at obvious paths; specify exact files/components so Phase 1 is executable. [/REVIEW]
### Verify
- `echo "discovery verified"`
[REVIEW:CLAUDE] GAP: `echo "discovery verified"` does not validate that retry behavior and call-site mapping were actually documented. Replace with an observable check tied to a concrete artifact/output. [/REVIEW]

## Phase 2: Implementation
### End State
- Retry policy integrated into sender path.
### Work
- Add backoff helper and invoke from webhook sender.
[REVIEW:CLAUDE] RISK: "Add backoff helper" is underspecified; missing jitter/cap policy and delay progression can cause synchronized retry bursts or divergent implementations. [/REVIEW]
- Add unit tests for 4xx/5xx behavior.
### Verify
- `echo "implementation verified"`
[REVIEW:CLAUDE] GAP: Implementation verification is non-executable as written; acceptance criteria require explicit test command(s) proving 5xx retries stop at 3 attempts and 4xx are not retried. [/REVIEW]

## Progress
- [ ] phase-1 Discovery
- [ ] phase-2 Implementation

## Resume Instructions (Agent)
- Start at the first unchecked phase and continue until all phases are complete.

## Plan Changelog
- 2026-02-27: Initial fixture for review command testing.
