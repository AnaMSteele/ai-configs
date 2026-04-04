# Test Review Flow Plan

Status: draft

Authority: test fixture for validating /review:plan runtime behavior

[REVIEW:GPT5.4] AMBIGUITY: "/review:plan runtime behavior" is not a single implementation in this repo. `_pi/prompts/review:plan.md` runs GPT5.4 + Kimi + Claude integration, while `_omp/commands/review:plan.md` runs GPT5.4 + Kimi + Opus + synthesis and produces a different review artifact pattern. This fixture needs to name the exact surface under test, or the expected end state (especially a "clean" final file) is not objectively verifiable. [/REVIEW]

## Goal
Validate that the reviewed-plan workflow can run end-to-end and leave a clean plan file.

## Non-goals
- Shipping product changes

## Acceptance Criteria
- AC1. The review command can analyze this plan and leave a clean final file.
- AC2. The final file preserves plan structure.

[REVIEW:GPT5.4] GAP: AC1 and AC2 are too weak to prove the end-to-end workflow actually ran. A no-op that leaves the file untouched could satisfy both. Add acceptance criteria that require evidence of the review phase occurring first and the integration phase cleaning up only after that review output exists. [/REVIEW]

[REVIEW:Kimi K2.5] ACCEPTANCE CRITERIA MAPPING: AC1 "clean final file" maps to Phase 2's verify step. Good. AC2 "preserves plan structure"—no explicit verify covers this; Phase 1 "Inspect" is too vague. Consider adding structure preservation check. [/REVIEW]

## Progress
- [ ] P1. Review plan structure
- [ ] P2. Integrate review feedback

[REVIEW:Kimi K2.5] RISK: Progress shows `[ ]` unchecked boxes but plan is "draft" status. The relationship between Status and Progress checkboxes is ambiguous—should draft plans have unchecked boxes, or should status reflect actual progress? [/REVIEW]

## Phase 1: Review plan structure

### End State
The plan has enough structure to be reviewed.

### Tests first
A reviewer can identify obvious gaps in plan detail.

[REVIEW:GPT5.4] GAP: This is not a strong behavioral test. It does not specify what observable artifact proves Phase 1 succeeded — for example, which inline review tags should appear, whether multiple reviewers must contribute, or what non-review content must remain unchanged. As written, a shallow or partial review still passes. [/REVIEW]

### Work
- Review the plan content.
- Check whether verification is specific enough.

### Verify
- Inspect the resulting plan file.

[REVIEW:GPT5.4] GAP: This verify step is too vague for a runnable plan. The review standard requires explicit commands and/or manual checks; this should name concrete verification steps such as checking for the expected review tags and confirming the surrounding plan text was not otherwise rewritten. [/REVIEW]

[REVIEW:Kimi K2.5] GAP: Phase 1 "Verify" command is too vague ("Inspect the resulting plan file"). Needs a concrete command like `grep -c "REVIEW:" thoughts/plans/test-review-flow.md` or similar. [/REVIEW]

## Phase 2: Integrate review feedback

### End State
The plan reflects accepted review feedback.

### Tests first
The file should end without unresolved review markers.

### Work
- Apply accepted fixes.
- Keep the file resumable.

[REVIEW:GPT5.4] AMBIGUITY: "Apply accepted fixes" is not deterministic because the plan never defines who decides which review findings are accepted or rejected. That matters here because the repo has different review/integration flows depending on surface. Without an explicit decision-maker and mechanism, two executors could produce different final files and both claim success. [/REVIEW]

### Verify
- Confirm the final file has no unresolved review tags.

[REVIEW:GPT5.4] RISK: Verifying only that review tags disappeared allows a false positive where comments are deleted without integrating any substantive feedback. Add a second check that the accepted changes were actually incorporated and that the original plan structure is still intact. [/REVIEW]

[REVIEW:Kimi K2.5] POSITIVE: Phase 2 "Verify" correctly specifies checking for unresolved review tags—this directly validates AC1's "clean" requirement. Strong verification step. [/REVIEW]

Resume Instructions (Agent)
- Continue from the first unfinished Progress item.

[REVIEW:GPT5.4] GAP: These resume instructions are too thin for an interrupted two-stage review flow. If execution stops after Phase 1 has already inserted inline review comments, the next agent needs to know whether to resume from the commented file, how to avoid duplicating reviewer passes, and what evidence marks Phase 1 as already complete. [/REVIEW]

[REVIEW:Kimi K2.5] AMBIGUITY: "Resume Instructions (Agent)" are generic ("Continue from the first unfinished Progress item"). For a test fixture validating review workflows, should specify what "clean" means—no `[REVIEW:` tags? No unchecked boxes? Both? [/REVIEW]

## Decisions / Deviations Log
- None yet.

[REVIEW:Kimi K2.5] NOTE: As a test fixture, this plan is intentionally minimal. However, if this were a real plan, missing: dependency/library evaluation checkpoint (though trivial here), explicit AC-to-Verify mapping, and Decisions/Deviations content. Acceptable for test fixture scope. [/REVIEW]
