# Review Command Fixture 2 (Gemini)

## Goal
- Add feature-flag-aware retry logic to outbound webhooks.

## Non-goals
- Do not redesign webhook payload schema.

## Acceptance Criteria
[REVIEW:GEMINI] AMBIGUITY: "transient 5xx" is underspecified; define exact retryable conditions (HTTP statuses, network timeouts, connection resets) so implementation and tests cannot diverge. [/REVIEW]
- Retries occur up to 3 times for transient 5xx errors.
[REVIEW:GEMINI] GAP: This says permanent 4xx errors are not retried, but does not classify 429. If 429 should retry (common), this criterion is currently incorrect; if it should not, state that explicitly. [/REVIEW]
- Permanent 4xx errors are not retried.

## Phase 1: Discovery
### End State
- Existing retry behavior and call sites are documented.
### Work
[REVIEW:GEMINI] WRONG REFERENCE: "webhook sender and queue worker modules" are not mapped to concrete repository paths, so this phase is not executable as written. Name exact files/symbols. [/REVIEW]
- Inspect webhook sender and queue worker modules.
### Verify
[REVIEW:GEMINI] GAP: `echo "discovery verified"` does not verify anything observable about discovered callsites or retry behavior. Replace with concrete checks (e.g., grep targets or documented artifact output). [/REVIEW]
- `echo "discovery verified"`

## Phase 2: Implementation
### End State
- Retry policy integrated into sender path.
### Work
[REVIEW:GEMINI] AMBIGUITY: Goal is feature-flag-aware retry logic, but the work item does not specify flag source, default value, or behavior when the flag is disabled. [/REVIEW]
- Add backoff helper and update sender retry loop.
[REVIEW:GEMINI] GAP: Test scope omits flag-on/off behavior, max-attempt boundary (exactly 3), and backoff timing policy. Current tests may pass while missing acceptance intent. [/REVIEW]
- Add tests for 4xx and 5xx behavior.
### Verify
[REVIEW:GEMINI] GAP: `echo "implementation verified"` is non-evidentiary. Verification must run real tests/commands tied to acceptance criteria. [/REVIEW]
- `echo "implementation verified"`

## Progress
- [ ] phase-1-discovery
- [ ] phase-2-implementation

Resume Instructions (Agent):
Continue from first incomplete phase and keep progress checkboxes updated.
