# Review Command Fixture 2 (Opus)

## Goal
- Add feature-flag-aware retry logic to outbound webhooks.
[REVIEW:CLAUDE] GAP: The goal requires feature-flag-aware behavior, but no phase defines the flag source, default state, or rollout checks; the plan is not executable as written. [/REVIEW]

## Non-goals
- Do not redesign webhook payload schema.

## Acceptance Criteria
- Retries occur up to 3 times for transient 5xx errors.
- Permanent 4xx errors are not retried.
[REVIEW:CLAUDE] GAP: Acceptance criteria cover HTTP status handling only; they do not verify behavior when the feature flag is OFF versus ON, so success can be claimed without delivering the stated goal. [/REVIEW]

## Phase 1: Discovery
### End State
- Existing retry behavior and call sites are documented.
### Work
- Inspect webhook sender and queue worker modules.
[REVIEW:CLAUDE] WRONG REFERENCE: Repository scan found no webhook sender/queue worker modules in this repo, so this work item lacks resolvable target paths. [/REVIEW]
### Verify
- `echo "discovery verified"`
[REVIEW:CLAUDE] INCORRECT: `echo "discovery verified"` does not validate discovery outcomes; verification should require observable artifacts (for example, documented callsites/paths). [/REVIEW]

## Phase 2: Implementation
### End State
- Retry policy integrated into sender path.
### Work
- Add backoff helper and update sender retry loop.
- Add tests for 4xx and 5xx behavior.
[REVIEW:CLAUDE] AMBIGUITY: "Add backoff helper" is underspecified (delay function, jitter, max attempts/timing, and ownership of retry state), which invites incompatible implementations. [/REVIEW]
[REVIEW:CLAUDE] RISK: Outbound webhook retries can create duplicate side effects; the plan does not state idempotency assumptions or duplicate-delivery safeguards. [/REVIEW]
### Verify
- `echo "implementation verified"`
[REVIEW:CLAUDE] INCORRECT: `echo "implementation verified"` is a placeholder and does not prove acceptance criteria; add concrete test/manual verification for 4xx/5xx and feature-flag ON/OFF behavior. [/REVIEW]

## Progress
- [ ] phase-1-discovery
- [ ] phase-2-implementation

Resume Instructions (Agent):
Continue from first incomplete phase and keep progress checkboxes updated.
[REVIEW:CLAUDE] GAP: Resume instructions do not specify where discovery output is stored, so a resumed agent cannot reliably pick up prior findings. [/REVIEW]
