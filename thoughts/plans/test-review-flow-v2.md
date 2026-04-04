# Test Review Flow Plan v2

Status: draft

Authority: test fixture for validating /review:plan runtime behavior after prompt fix

[REVIEW:GPT5.4] AMBIGUITY: This still does not name the exact `/review:plan` surface under test. The repo has both `_pi/prompts/review:plan.md` and `_omp/commands/review:plan.md`, and they use different reviewer/integration flows with different expected end states. Until the fixture points at one concrete runtime, "end-to-end" and "clean final file" are not objectively verifiable. [/REVIEW]

## Goal
Validate that the reviewed-plan workflow can run end-to-end and leave a clean plan file.

## Non-goals
- Shipping product changes

## Acceptance Criteria
- AC1. The review command can analyze this plan and leave a clean final file.
- AC2. The final file preserves plan structure.

[REVIEW:Kimi K2.5] GAP: Critical success factor "Plan structure preservation" (AC2) is only weakly covered by tasks. Only the Phase 1 "Tests first" tangentially relates to structure. Consider adding explicit verification steps for: (1) all original phase headers preserved, (2) Progress section intact, (3) Decisions Log maintained. [/REVIEW]

[REVIEW:GPT5.4] GAP: AC1 and AC2 still do not prove the intended two-step workflow actually happened. A run that skips the review phase entirely, or one that simply deletes all review comments at the end, can still satisfy "clean final file" plus "preserves plan structure." Add criteria that require observable Phase 1 review artifacts first and Phase 2 integration cleanup second. [/REVIEW]

## Progress
[REVIEW:Kimi K2.5] INCORRECT: Progress item IDs (P1, P2) don't match phase header text ("Phase 1", "Phase 2"). Per plan requirements, Progress items should correspond to phase headers with stable IDs. Consider using "Phase 1" and "Phase 2" as IDs or rename phases to match P1/P2 convention. [/REVIEW]

- [ ] P1. Review plan structure
- [ ] P2. Integrate review feedback

## Phase 1: Review plan structure

### End State
The plan has enough structure to be reviewed.

### Tests first
A reviewer can identify obvious gaps in plan detail.

[REVIEW:GPT5.4] GAP: For a runtime-validation fixture, this is not a strong enough Phase 1 contract. It describes what a reviewer notices, but not the observable artifact that proves the review pass executed correctly. Phase 1 should state what must appear in the file after review (for example, inline feedback from each expected reviewer while the surrounding plan text remains intact). [/REVIEW]

### Work
- Review the plan content.
- Check whether verification is specific enough.

[REVIEW:Kimi K2.5] AMBIGUITY: Phase 1 "Verify" says "Inspect the resulting plan file" but doesn't specify what to inspect for. Add explicit criteria: check for review markers, verify structure preserved, confirm no syntax errors. [/REVIEW]

### Verify
- Inspect the resulting plan file.

## Phase 2: Integrate review feedback

### End State
The plan reflects accepted review feedback.

### Tests first
The file should end without unresolved review markers.

[REVIEW:GPT5.4] AMBIGUITY: This is only a cleanup assertion, not a behavior-first test for integration quality. It does not say which accepted feedback must be reflected in the final file, how rejected feedback is handled, or how AC2 structure preservation is rechecked after integration. [/REVIEW]

[REVIEW:Kimi K2.5] RISK: Phase 2 "Work" says "Apply accepted fixes" but doesn't define a mechanism for distinguishing accepted vs rejected feedback. Without clear acceptance criteria, agents may inadvertently apply all review comments or miss legitimate ones. Consider adding: how to identify accepted feedback, how to remove review markers, when to reject feedback. [/REVIEW]

### Work
- Apply accepted fixes.
- Keep the file resumable.

### Verify
- Confirm the final file has no unresolved review tags.

[REVIEW:GPT5.4] RISK: This verify step can pass even if the executor removed comments without integrating anything substantive. It also still does not verify AC2. Add an explicit check that accepted edits are present and that required sections/phase headers survived the integration pass unchanged. [/REVIEW]

Resume Instructions (Agent)
[REVIEW:Kimi K2.5] INCORRECT: Resume Instructions placement is inconsistent with standard plan format. Typically this should be a proper section header (## Resume Instructions) and include more specific guidance: which phase to resume from, how to identify the first unfinished Progress item, what to do if review markers are present. [/REVIEW]
- Continue from the first unfinished Progress item.

[REVIEW:GPT5.4] GAP: These instructions are still too thin for an interrupted multi-pass review flow. They need to tell the next agent how to recognize that Phase 1 already completed, how to avoid rerunning reviewers and duplicating inline comments, and when to record integration outcomes in `## Decisions / Deviations Log` before stopping. [/REVIEW]

## Decisions / Deviations Log
[REVIEW:Kimi K2.5] GAP: Decisions Log exists but has no structured format for entries. For a test fixture validating review workflows, this section should demonstrate the expected format for decisions. Consider adding a template entry showing: decision ID, timestamp, context, choice made, rationale. [/REVIEW]
- None yet.
