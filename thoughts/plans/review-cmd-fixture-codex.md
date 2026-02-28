# Review Command Fixture (Codex)

## Goal
- Add feature-flag-aware retry logic to outbound webhooks.

## Non-goals
- Do not redesign webhook payload schema.

## Acceptance Criteria
- Retries occur up to 3 times for transient 5xx errors.
- Permanent 4xx errors are not retried.

[REVIEW:CODEX] GAP: The goal requires *feature-flag-aware* retry behavior, but acceptance criteria only cover 4xx/5xx outcomes. Add explicit success criteria for flag OFF (no retry path) and flag ON (retry path enabled) so implementation cannot skip the flag integration. [/REVIEW]
## Phase 1: Discovery
### End State
- Existing retry behavior and call sites are documented.
### Work
[REVIEW:CODEX] WRONG REFERENCE: "Inspect webhook sender and queue worker modules" is not executable as written because no concrete file paths or symbols are identified. Name exact files/functions to make the phase runnable and resumable by another agent. [/REVIEW]
- Inspect webhook sender and queue worker modules.
### Verify
[REVIEW:CODEX] INCORRECT: `echo "discovery verified"` does not validate any discovery output. Replace with concrete checks (for example, grep/assertions against documented call sites or a captured artifact) that prove Phase 1 end state was actually reached. [/REVIEW]
- `echo "discovery verified"`

## Phase 2: Implementation
### End State
- Retry policy integrated into sender path.
### Work
[REVIEW:CODEX] RISK: Retrying outbound webhooks can cause duplicate side effects downstream. The plan should explicitly state idempotency expectations and whether retries apply to network timeouts/connection failures in addition to 5xx responses. [/REVIEW]
- Add backoff helper and invoke from webhook sender.
- Add unit tests for 4xx/5xx behavior.
### Verify
[REVIEW:CODEX] GAP: Phase 2 verification is a placeholder and does not prove acceptance criteria. Add explicit test commands and assertions for: retry ceiling behavior, 4xx non-retry behavior, and feature-flag ON/OFF branching. [/REVIEW]
- `echo "implementation verified"`

## Progress
- [ ] phase-1 Discovery
- [ ] phase-2 Implementation

## Resume Instructions (Agent)
- Start at the first unchecked phase and continue until all phases are complete.

## Plan Changelog
- 2026-02-27: Initial fixture for review command testing.
