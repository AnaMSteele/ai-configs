# Review Command Fixture 3 (Opus)

## Goal
- Add feature-flag-aware retry logic to outbound webhooks.
[REVIEW:CLAUDE] INCORRECT: The goal states "feature-flag-aware retry logic" but no subsequent section — acceptance criteria, phase work, end states, or verification — addresses the feature-flag dimension. Either the goal is wrong (should just say "retry logic") or the entire plan is incomplete. As written, the plan delivers retry logic without any feature-flag awareness, which fails the stated goal. [/REVIEW]

## Non-goals
- Do not redesign webhook payload schema.
[REVIEW:CLAUDE] GAP: Non-goals should explicitly state that the feature-flag system itself is not being built or redesigned (only consumed). Without this, scope could creep into building a new flag infrastructure. Also missing: no changes to webhook delivery ordering guarantees, no changes to dead-letter queue behavior (if one exists). [/REVIEW]

## Acceptance Criteria
- Retries occur up to 3 times for transient 5xx errors.
- Permanent 4xx errors are not retried.
[REVIEW:CLAUDE] GAP: Acceptance criteria are silent on feature-flag behavior. The goal says "feature-flag-aware" but no criterion specifies: (a) what happens when the flag is off (no retries? old behavior?), (b) how the flag is identified or toggled, (c) that flag state is tested. This is the most critical gap — the defining characteristic of the goal has zero acceptance coverage. [/REVIEW]
[REVIEW:CLAUDE] AMBIGUITY: "transient 5xx errors" is not defined. Does this mean all 5xx status codes, or a specific subset (e.g., 502, 503, 504 but not 501)? Some 5xx codes like 501 (Not Implemented) are not transient. The criteria should enumerate which codes qualify or define "transient" precisely. [/REVIEW]

## Phase 1: Discovery
### End State
- Existing retry behavior and call sites are documented.
### Work
- Inspect webhook sender and queue worker modules.
[REVIEW:CLAUDE] GAP: Discovery work does not include investigating the feature-flag infrastructure. The goal requires "feature-flag-aware" behavior, so this phase must also discover: what feature-flag system exists (LaunchDarkly, env vars, config-based), how flags are currently used, and whether a new flag needs to be created. Without this, Phase 2 cannot implement feature-flag gating. [/REVIEW]
[REVIEW:CLAUDE] AMBIGUITY: "webhook sender and queue worker modules" are not identified by file path or module name. Discovery should name the specific files or packages to inspect, or at minimum describe how to locate them. A vague target leads to incomplete discovery. [/REVIEW]
### Verify
- `echo "discovery verified"`
[REVIEW:CLAUDE] RISK: Verification is a dummy `echo` command. Discovery phase should verify by producing a concrete artifact — a list of files, call sites, and current retry behavior — that Phase 2 depends on. An echo proves nothing and allows an empty discovery to pass. [/REVIEW]

## Phase 2: Implementation
### End State
- Retry policy integrated into sender path.
[REVIEW:CLAUDE] GAP: End state says "retry policy integrated into sender path" but does not mention feature-flag gating. If the goal is feature-flag-aware retry, the end state must include: retry behavior is toggleable via a feature flag, and the flag-off code path is unchanged from current behavior. [/REVIEW]
### Work
- Add backoff helper and update sender retry loop.
[REVIEW:CLAUDE] AMBIGUITY: "backoff helper" is unspecified. What backoff strategy — exponential, linear, constant? With jitter? What are the delay intervals? Without these details, two implementers would produce incompatible solutions. The acceptance criteria should specify the strategy or this work item should name the chosen approach. [/REVIEW]
- Add tests for 4xx and 5xx behavior.
[REVIEW:CLAUDE] GAP: Phase 2 work does not include any feature-flag integration task. The goal explicitly requires "feature-flag-aware" retry logic, but no work item addresses: (a) selecting or creating a feature flag, (b) gating the retry path behind it, or (c) testing the flag-off path. This is a critical omission — the delivered work would not satisfy the stated goal. A Phase 3 or additional work items are needed. [/REVIEW]
### Verify
- `echo "implementation verified"`
[REVIEW:CLAUDE] RISK: Verification command is a no-op `echo` that proves nothing. Phase 2 adds tests (line 26) but the verify step does not run them. This should invoke the actual test runner targeting the new 4xx/5xx retry tests; otherwise there is no gate preventing a broken implementation from being marked complete. [/REVIEW]

## Progress
- [ ] phase-1-discovery
- [ ] phase-2-implementation

Resume Instructions (Agent):
Continue from first incomplete phase and keep progress checkboxes updated.
[REVIEW:CLAUDE] AMBIGUITY: Resume instructions are minimal. They do not specify how to handle partial phase completion (e.g., discovery half-done), nor do they instruct the agent on what to do if the feature flag system is missing or not yet chosen. This leaves the resuming agent without enough context to make good decisions. [/REVIEW]
