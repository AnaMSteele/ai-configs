# Pi plan reviewer subagents regression

## Status

execution-ready

## Goal

[REVIEW:Kimi K2.5] GAP: The goal requires "usable review summaries," but the acceptance criteria and later verification only check whether a summary was returned at all. Without defining what makes the summary usable enough to support regression confidence, this can pass on low-value or malformed summaries. [/REVIEW]

Regression-test the repo's Pi plan reviewer subagents with a tiny, self-contained fixture plan so we can confirm they still:
- resolve a plan under `thoughts/plans/`,
- insert inline `[REVIEW:...]` comments instead of rewriting the plan, and
- return usable review summaries.

[REVIEW:GPT5.4] GAP: The goal requires “usable review summaries,” but the acceptance criteria and later verification only check whether a summary was returned at all. Without defining what makes the summary usable enough to support regression confidence, this can pass on low-value or malformed summaries. [/REVIEW]

[REVIEW:Synthesis] Consensus blocker from GPT5.4 and Kimi: the plan depends on “usable review summaries,” but no section defines a measurable quality bar. Add one explicit standard and reuse it in acceptance + verification (for example: each successful reviewer summary must report at least one concrete finding and identify where it was found in the fixture). [/REVIEW]

## Non-goals

- Fixing reviewer behavior or changing prompt/agent implementation.
- Exercising the full `/review:plan` integration flow.
- Reviewing plans outside `thoughts/`.
- Producing a broad compatibility matrix beyond the reviewer runs covered here.

## Current State (Validated)

[REVIEW:Kimi K2.5] RISK: The validated production path uses parallel reviewers with fresh context, but this plan later has both reviewers operate on the same fixture artifact in sequence. That changes the behavior under test because the second reviewer will see the first reviewer's inline comments, so the regression no longer matches the standard flow described here. [/REVIEW]

- `_pi/prompts/review:plan.md` defines the standard Pi plan review flow and currently runs two parallel reviewer subagents: `reviewer-plan-gpt5.4` and `reviewer-plan-kimi`, followed by a separate Claude Code integration pass.
- `_pi/agents/reviewer-plan-gpt5.4.md` and `_pi/agents/reviewer-plan-kimi.md` are the concrete standard-review subagents for the Pi flow.
- `_pi/agents/reviewer-plan-opus.md` still exists in the repo, so this regression should explicitly distinguish the standard Pi reviewer pair from the extra reviewer agent that is not part of the current `_pi/prompts/review:plan.md` path.
- `thoughts/specs/product_intent.md` is absent, and `thoughts/plans/AGENTS.md` is absent. This plan therefore aligns to the user request, root `AGENTS.md`, and the validated Pi review files above.

[REVIEW:GPT5.4] RISK: The validated production path is two reviewers running in parallel with fresh context, but this plan later has both reviewers operate on the same fixture artifact in sequence. That changes the behavior under test because the second reviewer will see the first reviewer’s inline comments, so the regression no longer matches the standard flow described here. [/REVIEW]

[REVIEW:Synthesis] Consensus blocker from GPT5.4 and Kimi: the plan claims to regression-test the standard Pi reviewer path, but Phase 2 currently validates a different behavior model (sequential review of a shared mutated artifact). This needs an explicit decision: either preserve production fidelity via parallel/isolated runs, or narrow the claim to a simpler operability check. [/REVIEW]

## Acceptance Criteria

[REVIEW:Kimi K2.5] GAP: Criterion #4 requires capturing "whether each reviewer summary was returned" but doesn't specify how to validate the *content* of those summaries. A malformed or vacuous summary (e.g., "Plan looks good") would satisfy the current criteria while failing the stated goal of "usable review summaries." Add a quality threshold like "summary must list at least one specific finding with location." [/REVIEW]

1. A minimal temporary fixture plan exists at `thoughts/plans/pi-plan-review-subagents-regression-fixture.md`.
2. The fixture is intentionally reviewable and small enough that reviewer comments are easy to inspect manually.
3. The standard Pi reviewer subagents are each run directly against the fixture:
   - `reviewer-plan-gpt5.4`
   - `reviewer-plan-kimi`
4. The regression record captures, in this file:
   - whether each reviewer completed,
   - whether each reviewer inserted `[REVIEW:...]` comments into the fixture,
   - whether each reviewer summary was returned,
   - any notable failures, drift, or unexpected behavior.
5. All artifacts created by this regression remain under `thoughts/`.

## Verification Strategy

[REVIEW:Kimi K2.5] AMBIGUITY: The strategy says to use a "deliberately under-specified" fixture, but there's no guidance on what specific gaps to include or how many. Without examples (e.g., "missing error handling in Phase 2", "ambiguous success criteria"), the fixture creator has no repeatable standard, leading to inconsistent regression results. [/REVIEW]

Use a tiny purpose-built fixture that is deliberately under-specified so both reviewers have something concrete to flag. Run each reviewer subagent directly against that fixture, then inspect the fixture file for inline review tags and record the observed outcomes back into this plan.

## Resume Instructions (Agent)

- Read this file fully before making changes.
- Start with the first unchecked item in `## Progress`.
- Keep all created artifacts under `thoughts/`, with fixture files in `thoughts/plans/`.
- Update `## Progress` immediately after each phase completes.
- Record execution-time outcomes and deviations in `## Decisions / Deviations Log` before stopping.

## Progress

[REVIEW:Kimi K2.5] GAP: Task audit against critical success factors reveals under-coverage:
- **Fixture quality (#1)**: Only P1 addresses this, but without specific gap criteria (e.g., "include 1 missing error handling, 1 ambiguous criterion"). A second distinct task validating fixture quality before reviewer execution is missing.
- **Parallel behavior fidelity (#2)**: The Current State states production uses "parallel reviewers with fresh context," but P2 runs them sequentially on the same file. This isn't coverage—it's a deviation that needs an explicit decision or correction.
- **Regression recording (#3)**: Only P3 addresses this, but with a wrong file reference in the Verify step. A second verification task (e.g., "re-read this plan to confirm outcomes recorded") would provide the required redundancy.

Recommendation: Add explicit gap criteria to P1, decide/fix the parallel vs sequential issue, and add a second verification task to P3. [/REVIEW]

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

[REVIEW:Kimi K2.5] AMBIGUITY: "A few deliberate review targets" is too vague. Without specifying exactly how many gaps to create and what types (e.g., "1 missing error handling step", "1 ambiguous success criterion", "1 weak verification command"), the fixture creator has no repeatable standard. This leads to inconsistent regression results where some runs have rich targets and others have none. [/REVIEW]

[REVIEW:Synthesis] High-value Kimi-only point: the fixture itself needs a fixed seeded-defect recipe or the regression will be noisy across runs. Locking a small set of intentional defects would make future pass/fail comparisons far more trustworthy than “a few” unspecified targets. [/REVIEW]

### Verify

[REVIEW:Kimi K2.5] GAP: This verification only checks for the *existence* of review tags, not their *quality* or *accuracy*. A reviewer could insert `[REVIEW:GPT5.4] Looks good[/REVIEW]` on every line and satisfy this check while failing the actual regression goal of detecting real issues. Add criteria like "comments must reference specific plan elements" and "comments must identify actual gaps/risks." [/REVIEW]

- `read thoughts/plans/pi-plan-review-subagents-regression-fixture.md`
- Confirm the fixture is a single self-contained plan file under `thoughts/plans/`.
- Confirm the fixture includes at least one likely reviewable gap.

## Phase 2: Run the standard Pi reviewer subagents

### End State

- `reviewer-plan-gpt5.4` has been run against the fixture.
- `reviewer-plan-kimi` has been run against the fixture.
- The resulting fixture contains reviewer-added inline comments or the failure mode has been captured.

### Tests first

[REVIEW:Kimi K2.5] GAP: This is not a strong enough "Tests first" contract for an execution-ready plan. It does not define observable failure cases such as "summary returned but no inline edits," "inline edits made but the agent rewrote unrelated text," or "the agent kept running past the requested stop point." [/REVIEW]

Because this is a reviewer regression, the primary test is the reviewer invocation itself: each subagent should be able to open the fixture, review it, and stop after leaving comments plus a summary.

[REVIEW:GPT5.4] GAP: This is not a strong enough “Tests first” contract for an execution-ready plan. It does not define observable failure cases such as “summary returned but no inline edits,” “inline edits made but the agent rewrote unrelated text,” or “the agent kept running past the requested stop point.” [/REVIEW]

### Work

[REVIEW:Kimi K2.5] AMBIGUITY: "Run ... directly" is not reproducible guidance by itself. The plan should name the exact invocation surface to use here (for example the `subagent` call shape or the precise Pi command) so another agent can execute and resume Phase 2 without guessing. [/REVIEW]

- Run `reviewer-plan-gpt5.4` directly against `thoughts/plans/pi-plan-review-subagents-regression-fixture.md`.
- Run `reviewer-plan-kimi` directly against the same fixture.
- Preserve the fixture as the evidence artifact; do not clean out review comments afterward.

[REVIEW:GPT5.4] AMBIGUITY: “Run ... directly” is not reproducible guidance by itself. The plan should name the exact invocation surface to use here (for example the `subagent` call shape or the precise Pi command) so another agent can execute and resume Phase 2 without guessing. [/REVIEW]

[REVIEW:Synthesis] Consensus from GPT5.4 and Kimi: Phase 2 is not yet reproducible or falsifiable enough. The plan should name the exact reviewer invocation surface and define the failure signatures this regression is meant to catch, especially summary-without-inline-edits, destructive rewrite of the fixture, and failure to stop after review. [/REVIEW]

### Verify

[REVIEW:Kimi K2.5] GAP: This verification only confirms review tags are present, but doesn't verify the *content quality* of the reviews. A reviewer could insert `[REVIEW:GPT5.4] No issues found[/REVIEW]` everywhere and pass this check. Add criteria like "comments must identify specific plan weaknesses" and "summaries must list at least one concrete finding with location." [/REVIEW]

- `read thoughts/plans/pi-plan-review-subagents-regression-fixture.md`
- Confirm `[REVIEW:GPT5.4]` appears if the GPT reviewer succeeded.
- Confirm `[REVIEW:Kimi K2.5]` appears if the Kimi reviewer succeeded.
- Capture each reviewer summary/output in the execution notes for Phase 3.

[REVIEW:GPT5.4] GAP: This verification only proves that review tags exist somewhere in the file. It does not verify the other stated regression goal that reviewers inserted comments instead of rewriting the fixture, so a destructive rewrite could still satisfy this phase as written. [/REVIEW]

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

[REVIEW:Kimi K2.5] WRONG REFERENCE: This verify command points at `thoughts/plans/pi-plan-review-subagents-regression.md`, but this plan file is `thoughts/plans/pi-plan-review-subagents-standard-combined.md`. Following this command as written checks the wrong document and can falsely validate or miss Phase 3 updates. [/REVIEW]

- `read thoughts/plans/pi-plan-review-subagents-regression.md`
- Confirm the log includes outcomes for both standard reviewers.
- Confirm the acceptance criteria can be checked from this plan plus the fixture artifact alone.

[REVIEW:GPT5.4] WRONG REFERENCE: This verify command points at `thoughts/plans/pi-plan-review-subagents-regression.md`, but this plan file is `thoughts/plans/pi-plan-review-subagents-standard-combined.md`. Following the command as written checks the wrong document and can falsely validate or miss Phase 3 updates. [/REVIEW]

[REVIEW:Synthesis] Consensus blocker from GPT5.4 and Kimi: this verify step inspects the wrong file, so Phase 3 cannot reliably prove that the regression record was captured here. This path mismatch is small to fix but material to the plan’s execution-readiness. [/REVIEW]

## Decisions / Deviations Log

- No execution notes yet.

## Plan Changelog

- 2026-04-03: Initial small regression plan for Pi plan reviewer subagents.