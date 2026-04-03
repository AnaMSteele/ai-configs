# Pi plan reviewer subagents regression

## Status

execution-ready

[REVIEW:Opus 4.6] AMBIGUITY: The filename is `pi-plan-review-subagents-opus.md` but the plan content exclusively tests the standard reviewer pair (gpt5.4 + kimi) — not the opus reviewer. A sibling file `pi-plan-review-subagents-regression.md` exists with near-identical content. The naming implies this plan exercises the opus reviewer, but it doesn't. Either rename the file to match its actual scope or clarify in the Goal section why the "-opus" suffix is used (e.g., "plan authored/owned by opus"). [/REVIEW]

## Goal

Regression-test the repo's Pi plan reviewer subagents with a tiny, self-contained fixture plan so we can confirm they still:
- resolve a plan under `thoughts/plans/`,
- insert inline `[REVIEW:...]` comments instead of rewriting the plan, and
- return usable review summaries.

## Non-goals

- Fixing reviewer behavior or changing prompt/agent implementation.
- Exercising the full `/review:plan` integration flow.
- Reviewing plans outside `thoughts/`.
- Producing a broad compatibility matrix beyond the reviewer runs covered here.

## Current State (Validated)

- `_pi/prompts/review:plan.md` defines the standard Pi plan review flow and currently runs two parallel reviewer subagents: `reviewer-plan-gpt5.4` and `reviewer-plan-kimi`, followed by a separate Claude Code integration pass.
- `_pi/agents/reviewer-plan-gpt5.4.md` and `_pi/agents/reviewer-plan-kimi.md` are the concrete standard-review subagents for the Pi flow.
- `_pi/agents/reviewer-plan-opus.md` still exists in the repo, so this regression should explicitly distinguish the standard Pi reviewer pair from the extra reviewer agent that is not part of the current `_pi/prompts/review:plan.md` path.

[REVIEW:Opus 4.6] GAP: The plan notes the opus reviewer exists and should be "explicitly distinguished" but never acts on this. No phase tests the opus reviewer, and no acceptance criterion captures whether the opus reviewer works or differs from the standard pair. If the goal is only to test the standard pair, drop this sentence — it sets an expectation the plan doesn't fulfill. If opus should also be regression-tested, add a phase or acceptance criterion for it. [/REVIEW]
- `thoughts/specs/product_intent.md` is absent, and `thoughts/plans/AGENTS.md` is absent. This plan therefore aligns to the user request, root `AGENTS.md`, and the validated Pi review files above.

## Acceptance Criteria

1. A minimal temporary fixture plan exists at `thoughts/plans/pi-plan-review-subagents-regression-fixture.md`.
2. The fixture is intentionally reviewable and small enough that reviewer comments are easy to inspect manually.
3. The standard Pi reviewer subagents are each run directly against the fixture:
   - `reviewer-plan-gpt5.4`
   - `reviewer-plan-kimi`

[REVIEW:Opus 4.6] GAP: Acceptance criterion 3 says "run directly" but never specifies the invocation mechanism. Is this a `subagent` tool call, a Pi slash command, or a manual CLI invocation? The executing agent needs to know the exact tool/command to use. Phase 2 Work has the same gap — it says "Run `reviewer-plan-gpt5.4` directly" without concrete syntax. Add the expected invocation method (e.g., `subagent({ agent: "reviewer-plan-gpt5.4", task: "..." })` or equivalent Pi command). [/REVIEW]
4. The regression record captures, in this file:
   - whether each reviewer completed,
   - whether each reviewer inserted `[REVIEW:...]` comments into the fixture,
   - whether each reviewer summary was returned,
   - any notable failures, drift, or unexpected behavior.
5. All artifacts created by this regression remain under `thoughts/`.

## Verification Strategy

Use a tiny purpose-built fixture that is deliberately under-specified so both reviewers have something concrete to flag. Run each reviewer subagent directly against that fixture, then inspect the fixture file for inline review tags and record the observed outcomes back into this plan.

[REVIEW:Opus 4.6] GAP: The verification strategy doesn't define what "success" vs "failure" looks like in concrete terms. What's the minimum bar? If one reviewer inserts comments but the other crashes, is the regression a pass or fail? The plan should state a clear pass/fail threshold (e.g., "both reviewers must insert at least one `[REVIEW:...]` tag and return a summary; if either fails entirely, the regression fails"). [/REVIEW]

## Resume Instructions (Agent)

- Read this file fully before making changes.
- Start with the first unchecked item in `## Progress`.
- Keep all created artifacts under `thoughts/`, with fixture files in `thoughts/plans/`.
- Update `## Progress` immediately after each phase completes.
- Record execution-time outcomes and deviations in `## Decisions / Deviations Log` before stopping.

## Progress

- [ ] P1 - Create the temporary reviewer-fixture plan under `thoughts/plans/`.
- [ ] P2 - Run the standard Pi plan reviewer subagents against the fixture.
- [ ] P3 - Inspect the fixture and record regression outcomes in this file.

## Phase 1: Create the temporary reviewer fixture

### End State

- `thoughts/plans/pi-plan-review-subagents-regression-fixture.md` exists.
- The fixture uses the repo's single-file plan shape at a minimal scale.
- The fixture contains enough intentional gaps to trigger reviewer comments.

### Tests first

- Confirm the target reviewer prompt and agent files still exist:
  - `read _pi/prompts/review:plan.md`
  - `read _pi/agents/reviewer-plan-gpt5.4.md`
  - `read _pi/agents/reviewer-plan-kimi.md`
- Confirm the fixture path does not already exist or is safe to overwrite for this regression:
  - `ls thoughts/plans`

[REVIEW:Opus 4.6] GAP: These "Tests first" are prerequisite checks, not behavioral tests. They confirm files exist but don't describe what an operator/agent will be able to do after the phase. A behavioral test here would be: "The fixture file is valid markdown, follows the single-file plan shape, and contains at least one intentional gap that a reviewer can flag (e.g., a missing `### Verify` section, a vague acceptance criterion)." [/REVIEW]

### Work

- Create `thoughts/plans/pi-plan-review-subagents-regression-fixture.md`.
- Keep it intentionally small:
  - goal,
  - non-goals,
  - acceptance criteria,
  - 1-2 phases,
  - `## Progress`,
  - `## Resume Instructions (Agent)`,
  - `## Decisions / Deviations Log`.
- Leave a few deliberate review targets such as weak verification commands or an underspecified acceptance criterion so reviewer comments are likely.

### Verify

- `read thoughts/plans/pi-plan-review-subagents-regression-fixture.md`
- Confirm the fixture is a single self-contained plan file under `thoughts/plans/`.
- Confirm the fixture includes at least one likely reviewable gap.

## Phase 2: Run the standard Pi reviewer subagents

### End State

- `reviewer-plan-gpt5.4` has been run against the fixture.
- `reviewer-plan-kimi` has been run against the fixture.
- The resulting fixture contains reviewer-added inline comments or the failure mode has been captured.

### Tests first

Because this is a reviewer regression, the primary test is the reviewer invocation itself: each subagent should be able to open the fixture, review it, and stop after leaving comments plus a summary.

[REVIEW:Opus 4.6] AMBIGUITY: This hand-waves the behavioral expectation. Stronger "Tests first" would state: (a) each reviewer inserts at least one `[REVIEW:Name]` tag into the fixture file (observable via grep), (b) each reviewer returns a summary block containing "Plan status" and "Recommendation", (c) neither reviewer rewrites non-review content in the fixture. Without these concrete assertions, Phase 2 can pass even if the reviewers produce malformed output. [/REVIEW]

### Work

- Run `reviewer-plan-gpt5.4` directly against `thoughts/plans/pi-plan-review-subagents-regression-fixture.md`.
- Run `reviewer-plan-kimi` directly against the same fixture.
- Preserve the fixture as the evidence artifact; do not clean out review comments afterward.

[REVIEW:Opus 4.6] RISK: Running both reviewers sequentially against the same fixture file means the second reviewer will see the first reviewer's comments already in the file. This may alter the second reviewer's behavior (it might respond to existing comments instead of independently reviewing). The `review:plan.md` flow runs them in parallel precisely to avoid this cross-contamination. Consider either: (a) making two copies of the fixture so each reviewer gets a clean copy, or (b) acknowledging this is an intentional simplification and that cross-contamination is acceptable for this regression. [/REVIEW]

### Verify

- `read thoughts/plans/pi-plan-review-subagents-regression-fixture.md`
- Confirm `[REVIEW:GPT5.4]` appears if the GPT reviewer succeeded.
- Confirm `[REVIEW:Kimi K2.5]` appears if the Kimi reviewer succeeded.
- Capture each reviewer summary/output in the execution notes for Phase 3.

## Phase 3: Record the regression result

### End State

- This plan contains a concise regression record for the fixture and both reviewer runs.
- Any failures or unexpected behavior are noted clearly enough for follow-up.
- The plan remains self-contained as the final test record.

### Tests first

- Re-read this plan and the fixture side by side.
- Confirm the evidence needed for the acceptance criteria is present before marking the phase done.

### Work

- Add a dated execution note under `## Decisions / Deviations Log` covering:
  - fixture path used,
  - reviewer names run,
  - whether inline comments were inserted,
  - whether summaries were returned,
  - any errors or manual observations.
- If a reviewer fails, record the exact failure mode and stop short of claiming the regression passed.

### Verify

- `read thoughts/plans/pi-plan-review-subagents-regression.md`

[REVIEW:Opus 4.6] WRONG REFERENCE: This verify command reads `pi-plan-review-subagents-regression.md` — which is a different file. This plan is `pi-plan-review-subagents-opus.md`. The verify command should read this plan's own file. [/REVIEW]

- Confirm the log includes outcomes for both standard reviewers.
- Confirm the acceptance criteria can be checked from this plan plus the fixture artifact alone.

## Decisions / Deviations Log

- No execution notes yet.

[REVIEW:Opus 4.6] GAP: The plan has no cleanup or teardown guidance. The fixture is described as "temporary" (Phase 1 title) but nothing says when or how it should be removed after the regression is recorded. Either add a note that the fixture persists as a permanent test artifact, or add a cleanup step (even if manual). [/REVIEW]

## Plan Changelog

- 2026-04-03: Initial small regression plan for Pi plan reviewer subagents.