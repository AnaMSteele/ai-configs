# Pi plan reviewer subagents regression

## Status

execution-ready

## Goal

[REVIEW:Adversarial Opus 4.6] INCORRECT: This plan is filed under slug `pi-plan-review-subagents-adversarial-combined` but its goal, acceptance criteria, every phase, and every verify step target the **standard** reviewers (`reviewer-plan-gpt5.4` and `reviewer-plan-kimi`). The adversarial reviewer agents that `_pi/prompts/review:plan-adversarial.md` actually dispatches — `reviewer-plan-adversarial-gpt5.4` and `reviewer-plan-adversarial-opus` — are never mentioned in any executable part of this plan. An implementer who follows this plan literally will regression-test the standard reviewers a second time (duplicating `pi-plan-review-subagents-standard-combined.md`) and produce a misleading "adversarial regression passed" record. This is a plan-level identity error, not a typo. [/REVIEW]
Regression-test the repo's Pi plan reviewer subagents with a tiny, self-contained fixture plan so we can confirm they still:
- resolve a plan under `thoughts/plans/`,
- insert inline `[REVIEW:...]` comments instead of rewriting the plan, and
- return usable review summaries.

## Non-goals

- Fixing reviewer behavior or changing prompt/agent implementation.
- Exercising the full `/review:plan` integration flow.
[REVIEW:Adversarial GPT5.4] GAP: `_pi/README.md` and `_pi/prompts/review:plan.md` make `/review:plan` the canonical shipped path, but this plan explicitly excludes that wrapper. A direct-subagent-only regression can pass while the real operator workflow is broken at prompt dispatch, parallel coordination, or Claude integration. [/REVIEW]
- Reviewing plans outside `thoughts/`.
- Producing a broad compatibility matrix beyond the reviewer runs covered here.

## Current State (Validated)

[REVIEW:Adversarial Opus 4.6] INCORRECT: This section validates the **standard** review prompt (`review:plan.md`) and its standard subagents, but the adversarial review path is `_pi/prompts/review:plan-adversarial.md`, which dispatches `reviewer-plan-adversarial-gpt5.4` and `reviewer-plan-adversarial-opus` — plus a synthesis reviewer (`reviewer-plan-synthesis`). None of those agents or the adversarial prompt are validated here. The entire Current State section describes a different product surface than the one the slug implies. [/REVIEW]
- `_pi/prompts/review:plan.md` defines the standard Pi plan review flow and currently runs two parallel reviewer subagents: `reviewer-plan-gpt5.4` and `reviewer-plan-kimi`, followed by a separate Claude Code integration pass.
- `_pi/agents/reviewer-plan-gpt5.4.md` and `_pi/agents/reviewer-plan-kimi.md` are the concrete standard-review subagents for the Pi flow.
- `_pi/agents/reviewer-plan-opus.md` still exists in the repo, so this regression should explicitly distinguish the standard Pi reviewer pair from the extra reviewer agent that is not part of the current `_pi/prompts/review:plan.md` path.
- `thoughts/specs/product_intent.md` is absent, and `thoughts/plans/AGENTS.md` is absent. This plan therefore aligns to the user request, root `AGENTS.md`, and the validated Pi review files above.

## Acceptance Criteria

1. A minimal temporary fixture plan exists at `thoughts/plans/pi-plan-review-subagents-regression-fixture.md`.
2. The fixture is intentionally reviewable and small enough that reviewer comments are easy to inspect manually.
3. The standard Pi reviewer subagents are each run directly against the fixture:
   - `reviewer-plan-gpt5.4`
   - `reviewer-plan-kimi`
[REVIEW:Adversarial GPT5.4] GAP: The validated Pi flow runs these reviewers independently in parallel on the same input, but this acceptance criterion never locks whether the regression must preserve that isolation. A competent implementer could run GPT first, then run Kimi against an already-mutated fixture, and still claim success even though the real parallel path or reviewer independence is broken. [/REVIEW]
[REVIEW:Adversarial Opus 4.6] INCORRECT: These are the standard reviewers, not the adversarial reviewers. For an adversarial-combined regression, this criterion should list `reviewer-plan-adversarial-gpt5.4` and `reviewer-plan-adversarial-opus`. As written, the acceptance criteria are achievable by running the standard regression a second time. [/REVIEW]
4. The regression record captures, in this file:
   - whether each reviewer completed,
   - whether each reviewer inserted `[REVIEW:...]` comments into the fixture,
   - whether each reviewer summary was returned,
   - any notable failures, drift, or unexpected behavior.
5. All artifacts created by this regression remain under `thoughts/`.

## Verification Strategy

Use a tiny purpose-built fixture that is deliberately under-specified so both reviewers have something concrete to flag. Run each reviewer subagent directly against that fixture, then inspect the fixture file for inline review tags and record the observed outcomes back into this plan.
[REVIEW:Adversarial GPT5.4] RISK: The goal says reviewers must insert inline comments instead of rewriting the plan, but neither the acceptance criteria nor this verification strategy require checking that the original fixture content survived unchanged apart from review tags. A reviewer could clobber sections, append a replacement plan, or otherwise rewrite the artifact and still satisfy the current checks by leaving at least one `[REVIEW:...]` tag behind. [/REVIEW]
[REVIEW:Adversarial Opus 4.6] GAP: The adversarial reviewer agents have materially different instructions from the standard reviewers — they require reading `AGENTS.md`, `PRODUCT_INTENT.md`, and architecture docs before commenting, and they apply a five-lens adversarial method (intent vs incentives, architectural blind spots, recovery truthfulness, verification realism, execution contract quality). A "deliberately under-specified" fixture designed for standard reviewer gaps may not exercise the adversarial-specific review behavior at all. The verification strategy needs to account for whether the adversarial review comments reflect product-intent analysis, not just generic plan structure feedback. [/REVIEW]

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

[REVIEW:Adversarial Opus 4.6] INCORRECT: Phase 1's pre-checks confirm the standard reviewer files, not the adversarial ones. For this slug the checks should be `_pi/prompts/review:plan-adversarial.md`, `_pi/agents/reviewer-plan-adversarial-gpt5.4.md`, and `_pi/agents/reviewer-plan-adversarial-opus.md`. [/REVIEW]
- Confirm the target reviewer prompt and agent files still exist:
  - `read _pi/prompts/review:plan.md`
  - `read _pi/agents/reviewer-plan-gpt5.4.md`
  - `read _pi/agents/reviewer-plan-kimi.md`
- Confirm the fixture path does not already exist or is safe to overwrite for this regression:
  - `ls thoughts/plans`
[REVIEW:Adversarial GPT5.4] AMBIGUITY: "safe to overwrite" is undefined for a regression whose evidence lives in the file itself. Because the fixture path is fixed, reruns can inherit stale `[REVIEW:...]` tags or destroy the prior baseline, producing false positives when Phase 2 only checks for tag presence. [/REVIEW]

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

[REVIEW:Adversarial Opus 4.6] INCORRECT: The phase title and end state both say "standard Pi reviewer subagents" and list the standard agents. In an adversarial-combined regression this entire phase should dispatch the adversarial agents instead. This is not a naming issue — it changes which model, which system prompt, and which review method is exercised. [/REVIEW]

### End State

- `reviewer-plan-gpt5.4` has been run against the fixture.
- `reviewer-plan-kimi` has been run against the fixture.
- The resulting fixture contains reviewer-added inline comments or the failure mode has been captured.

### Tests first

Because this is a reviewer regression, the primary test is the reviewer invocation itself: each subagent should be able to open the fixture, review it, and stop after leaving comments plus a summary.

### Work

- Run `reviewer-plan-gpt5.4` directly against `thoughts/plans/pi-plan-review-subagents-regression-fixture.md`.
- Run `reviewer-plan-kimi` directly against the same fixture.
- Preserve the fixture as the evidence artifact; do not clean out review comments afterward.
[REVIEW:Adversarial GPT5.4] GAP: "Run ... directly" does not identify the execution surface or whether this must exercise the installed Pi runtime under `~/.pi/agent/agents/` versus repo-local source files. `install.sh` and `_pi/README.md` treat the installed runtime as the shipped product, so a repo-local invocation can pass while the installed reviewer path is stale or broken. [/REVIEW]
[REVIEW:Adversarial Opus 4.6] GAP: The `/review:plan-adversarial` prompt also includes a Phase 2 synthesis reviewer (`reviewer-plan-synthesis`) and a Phase 3 auto-integration pass. Even if this regression is scoped to the two adversarial subagents, the plan should state whether excluding the synthesis reviewer is an intentional scope cut or an oversight, because the synthesis reviewer can fail independently of the two challengers. [/REVIEW]

### Verify

- `read thoughts/plans/pi-plan-review-subagents-regression-fixture.md`
- Confirm `[REVIEW:GPT5.4]` appears if the GPT reviewer succeeded.
- Confirm `[REVIEW:Kimi K2.5]` appears if the Kimi reviewer succeeded.
- Capture each reviewer summary/output in the execution notes for Phase 3.
[REVIEW:Adversarial GPT5.4] GAP: The plan never defines what makes a summary "usable." The reviewer instructions require a structured outcome with plan status, critical issues, and recommendation, but this verify step would also pass if the subagent returned arbitrary trailing text that happened to mention the fixture. [/REVIEW]
[REVIEW:Adversarial Opus 4.6] INCORRECT: For an adversarial-combined regression, the verify tags to look for are `[REVIEW:Adversarial GPT5.4]` and `[REVIEW:Adversarial Opus 4.6]`, not `[REVIEW:GPT5.4]` and `[REVIEW:Kimi K2.5]`. These tag prefixes are how we distinguish which reviewer population was actually exercised. Finding standard tags here would prove the plan ran the wrong agents. [/REVIEW]

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
[REVIEW:Adversarial GPT5.4] WRONG REFERENCE: This verify step points at `thoughts/plans/pi-plan-review-subagents-regression.md`, which is a different plan file that already exists in the repo. An implementer could satisfy this check by inspecting or updating the wrong artifact while this plan remains incomplete. [/REVIEW]
[REVIEW:Adversarial Opus 4.6] WRONG REFERENCE: Confirming the GPT5.4 finding and adding: the correct self-reference for this plan is `thoughts/plans/pi-plan-review-subagents-adversarial-combined.md`. Additionally, the verify text says "both standard reviewers" which is doubly wrong — both the file reference and the reviewer population are incorrect for the adversarial-combined slug. [/REVIEW]
- Confirm the log includes outcomes for both standard reviewers.
- Confirm the acceptance criteria can be checked from this plan plus the fixture artifact alone.

## Decisions / Deviations Log

- No execution notes yet.

[REVIEW:Adversarial Opus 4.6] GAP: The plan shares a fixture path (`pi-plan-review-subagents-regression-fixture.md`) with the standard regression plan, but neither plan specifies who owns that file or what happens when both regressions run. If the standard regression ran first and left `[REVIEW:GPT5.4]` and `[REVIEW:Kimi K2.5]` tags in the fixture, the adversarial regression's Phase 2 verify step would find those pre-existing standard tags and falsely pass even if the adversarial agents were never invoked. A shared mutable fixture is a test-isolation hazard. [/REVIEW]

## Plan Changelog

- 2026-04-03: Initial small regression plan for Pi plan reviewer subagents.