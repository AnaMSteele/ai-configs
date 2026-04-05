---
description: Run comprehensive PRD review using seven parallel specialized reviewers, integrate their findings into the PRD, and record review status for handoff
argument-hint: '<path to prd.md | prd slug | legacy: <spec> <tasks> | legacy: <directory containing spec.md and tasks.md>'
---

# Multi-Reviewer PRD Review Process

This command runs seven independent PRD reviewers in parallel, stores each reviewer’s output in its own file, integrates the combined feedback back into the PRD, and leaves a machine-readable review status artifact for `/dev:plan-from-prd`.

Use it only after the PRD intent has been clarified and a wider review is actually worthwhile.

Reviewers:

1. PRD Intent
2. PRD Product Principles
3. PRD No Stubs
4. PRD Security Privacy Reliability
5. PRD BDD Flows
6. PRD Scope Stage Fit
7. PRD Dependencies

Documents to review: $ARGUMENTS

## Phase 0: Resolve Inputs

Preferred input:

- A single PRD file: `thoughts/plans/prd-<slug>.md`

Resolution rules:

- If `$ARGUMENTS` starts with `@`, strip the leading `@` and treat it as workspace-relative.
- If a single argument is an existing `.md` file, treat it as `prd_path`.
- If a single argument is a slug that already starts with `prd-`, resolve to `thoughts/plans/<slug>.md`.
- Otherwise resolve the slug to `thoughts/plans/prd-<slug>.md`.
- If the PRD file does not exist or multiple candidates match, ask for an explicit PRD file path.

Derive:

- `prd_slug` = PRD filename without `.md` (for example `prd-auth-hardening`)
- `review_dir` = `thoughts/validation/prd-reviews/<prd_slug>/`
- `ledger_path` = `thoughts/validation/prd-reviews/<prd_slug>/integration-ledger.md`
- `status_path` = `thoughts/validation/prd-reviews/<prd_slug>/review-status.json`

Reviewer output files:

- `01-prd-intent.md`
- `02-prd-product-principles.md`
- `03-prd-no-stubs.md`
- `04-prd-security-privacy-reliability.md`
- `05-prd-bdd-flows.md`
- `06-prd-scope-stage-fit.md`
- `07-prd-dependencies.md`

## Execution Mode

- Use the actual Pi subagent tool surface: launch seven background agents with `Agent`.
- All seven reviewers must be launched before waiting for any of them to finish.
- Each reviewer must read the PRD and write only to its own output file.
- Reviewers must **not** edit the PRD directly.
- The primary agent is the integrator. Do **not** launch an eighth reviewer or synthesis subagent.
- The final integration step must:
  1. read the PRD,
  2. read all seven reviewer files,
  3. update the integration ledger,
  4. integrate the combined findings into the PRD,
  5. write `review-status.json`,
  6. remove the seven reviewer files after integration is complete.

## Phase 1: Initialize Review Artifacts

Before launching reviewers:

1. Create or overwrite `integration-ledger.md` with one row per reviewer.
2. Mark every reviewer as `pending`.
3. Create or overwrite `review-status.json` with an in-progress status so any prior approval is invalidated immediately.

Use this JSON shape:

```json
{
  "schemaVersion": 1,
  "prdPath": "thoughts/plans/prd-<slug>.md",
  "reviewDir": "thoughts/validation/prd-reviews/<prd-slug>",
  "status": "in_progress",
  "reviewersExpected": 7,
  "reviewersCompleted": 0,
  "integratedCount": 0,
  "pendingCount": 7,
  "reviewerFilesRemoved": false,
  "generatedAt": "<ISO-8601 timestamp>"
}
```

Use this ledger shape:

```markdown
# PRD Review Integration Ledger

- PRD: `thoughts/plans/prd-<slug>.md`
- Review dir: `thoughts/validation/prd-reviews/<prd-slug>/`
- Status file: `thoughts/validation/prd-reviews/<prd-slug>/review-status.json`

| Reviewer | Output File | Status | Integration Note |
| --- | --- | --- | --- |
| PRD Intent | `01-prd-intent.md` | pending | Awaiting reviewer output |
| PRD Product Principles | `02-prd-product-principles.md` | pending | Awaiting reviewer output |
| PRD No Stubs | `03-prd-no-stubs.md` | pending | Awaiting reviewer output |
| PRD Security Privacy Reliability | `04-prd-security-privacy-reliability.md` | pending | Awaiting reviewer output |
| PRD BDD Flows | `05-prd-bdd-flows.md` | pending | Awaiting reviewer output |
| PRD Scope Stage Fit | `06-prd-scope-stage-fit.md` | pending | Awaiting reviewer output |
| PRD Dependencies | `07-prd-dependencies.md` | pending | Awaiting reviewer output |
```

## Phase 2: Parallel Review (7 Reviewers)

Launch all seven reviews before waiting for any of them to finish.

Each reviewer prompt must:

- read `prd_path`
- write findings only to its assigned output file under `review_dir`
- include actionable findings with exact PRD section references when possible
- end with a short verdict: `no issues`, `needs changes`, or `blocked`
- not edit the PRD
- not read or modify other reviewer files

### Reviewer assignments

1. **Agent:** `reviewer-prd-intent`
   - **Output:** `01-prd-intent.md`
2. **Agent:** `reviewer-prd-product-principles`
   - **Output:** `02-prd-product-principles.md`
3. **Agent:** `reviewer-prd-no-stubs`
   - **Output:** `03-prd-no-stubs.md`
4. **Agent:** `reviewer-prd-security-privacy-reliability`
   - **Output:** `04-prd-security-privacy-reliability.md`
5. **Agent:** `reviewer-prd-bdd-flows`
   - **Output:** `05-prd-bdd-flows.md`
6. **Agent:** `reviewer-prd-scope-stage-fit`
   - **Output:** `06-prd-scope-stage-fit.md`
7. **Agent:** `reviewer-prd-dependencies`
   - **Output:** `07-prd-dependencies.md`

### Parallel execution pattern

```javascript
const reviewers = [
  {
    name: "PRD Intent",
    file: "thoughts/validation/prd-reviews/<prd-slug>/01-prd-intent.md",
    subagent_type: "reviewer-prd-intent",
    description: "Review PRD intent alignment",
  },
  {
    name: "PRD Product Principles",
    file: "thoughts/validation/prd-reviews/<prd-slug>/02-prd-product-principles.md",
    subagent_type: "reviewer-prd-product-principles",
    description: "Review PRD product principles",
  },
  {
    name: "PRD No Stubs",
    file: "thoughts/validation/prd-reviews/<prd-slug>/03-prd-no-stubs.md",
    subagent_type: "reviewer-prd-no-stubs",
    description: "Review PRD completeness",
  },
  {
    name: "PRD Security Privacy Reliability",
    file: "thoughts/validation/prd-reviews/<prd-slug>/04-prd-security-privacy-reliability.md",
    subagent_type: "reviewer-prd-security-privacy-reliability",
    description: "Review PRD security and reliability",
  },
  {
    name: "PRD BDD Flows",
    file: "thoughts/validation/prd-reviews/<prd-slug>/05-prd-bdd-flows.md",
    subagent_type: "reviewer-prd-bdd-flows",
    description: "Review PRD flow completeness",
  },
  {
    name: "PRD Scope Stage Fit",
    file: "thoughts/validation/prd-reviews/<prd-slug>/06-prd-scope-stage-fit.md",
    subagent_type: "reviewer-prd-scope-stage-fit",
    description: "Review PRD scope fit",
  },
  {
    name: "PRD Dependencies",
    file: "thoughts/validation/prd-reviews/<prd-slug>/07-prd-dependencies.md",
    subagent_type: "reviewer-prd-dependencies",
    description: "Review PRD dependency choices",
  },
];

const launched = reviewers.map((reviewer) =>
  Agent({
    subagent_type: reviewer.subagent_type,
    description: reviewer.description,
    prompt: `Review the PRD at ${prd_path}. Follow your agent instructions exactly. Respect the selected functional spec paths and unchanged constraints as hard scope boundaries. For docs-only PRDs, only flag issues that would make the docs materially misleading, contradictory, or insufficient for the stated operator path. Do not invent broader product changes, internal runtime contracts, or implementation-detail test requirements unless the PRD explicitly changes those behaviors. Write findings only to ${reviewer.file}. Do not edit the PRD. End with one of: no issues / needs changes / blocked.`,
    run_in_background: true,
  }),
);

const results = await Promise.all(
  launched.map((job) => get_subagent_result({ agent_id: job.agent_id ?? job.id, wait: true })),
);
```

Wait for all seven `get_subagent_result(..., wait: true)` calls to finish before doing any integration.

If a reviewer fails or does not produce its file:

- update that reviewer’s ledger row to `blocked`
- write `review-status.json` with `status: "review_failed"`
- stop without approving the PRD
- do not hand off to `/dev:plan-from-prd`

## Phase 3: Integration Ledger Update

After all seven reviewer files exist:

1. Read all seven files.
2. Update each ledger row from `pending` to one of:
   - `integrated` — reviewer raised actionable in-scope findings that were integrated into the PRD
   - `skipped` — reviewer reported no actionable issues, or raised findings that were reviewed and intentionally not integrated because they were out of scope, contradicted the selected functional spec, or expanded beyond the PRD's unchanged constraints
   - `blocked` — reviewer output was unusable or incomplete
3. Fill `Integration Note` with a short truthful note per reviewer, including when a finding was skipped because it would broaden scope or require undocumented implementation detail.

`integratedCount` in `review-status.json` means: how many reviewer outputs the integrator accounted for in the final review decision. Count both:

- `integrated` reviewers whose findings were written back into the PRD
- `skipped` reviewers whose output was reviewed and intentionally resulted in no PRD change

Do not count `blocked` reviewers.

The ledger must make it obvious:

- which reviewers completed,
- which reviewers were integrated,
- which reviewers found no issues,
- whether any reviewer blocked the review cycle.

## Phase 4: Integrate Findings into the PRD

The primary agent now acts as the integrator.

Integration rules:

- Read the PRD plus all seven reviewer files before editing the PRD.
- Consolidate duplicated findings instead of pasting seven near-identical comments.
- Preserve reviewer-specific nuance when it materially changes the recommendation.
- Treat the selected functional spec paths and unchanged constraints as hard scope boundaries during integration.
- Do not integrate findings that would broaden scope, require undocumented implementation-detail behavior, or contradict the selected functional spec; mark those findings as `skipped` in the ledger with a truthful reason.
- For docs-only PRDs, only integrate findings about materially misleading, contradictory, or insufficient operator guidance for the stated path.
- If changes are required, write integrated `[REVIEW:...]` comments into the PRD at the most relevant sections.
- If the PRD is clean, leave the PRD unchanged.
- Do not silently discard a reviewer’s substantive finding; the ledger must say whether it was integrated or why it was not.

## Phase 5: Final Status + Cleanup

After integration is complete:

1. Write `review-status.json` with one of:
   - `approved` — no unresolved issues remain after integration and the PRD is ready for `/dev:plan-from-prd`
   - `needs_changes` — unresolved issues were integrated into the PRD as review comments
   - `review_failed` — one or more reviewer outputs were missing, blocked, or unusable
2. Required final fields:

```json
{
  "schemaVersion": 1,
  "prdPath": "thoughts/plans/prd-<slug>.md",
  "reviewDir": "thoughts/validation/prd-reviews/<prd-slug>",
  "status": "approved | needs_changes | review_failed",
  "reviewersExpected": 7,
  "reviewersCompleted": 7,
  "integratedCount": 0,
  "pendingCount": 0,
  "reviewerFilesRemoved": true,
  "generatedAt": "<ISO-8601 timestamp>"
}
```

`integratedCount` should be a number from `0` to `7`, counting reviewer outputs the integrator accounted for (`integrated` + `skipped`).

3. Remove the seven reviewer output files after the ledger and status file are finalized.
   - Keep `integration-ledger.md`.
   - Keep `review-status.json`.
   - Remove only the seven per-reviewer output files.

## Cleanup command restriction

When removing reviewer files, use an explicit file list under `thoughts/validation/prd-reviews/<prd-slug>/`. Do not use globs or broad directory deletion.

## Final Summary Format

After completion, provide:

```markdown
## Seven-Reviewer PRD Review Complete

### Review Status
- Status: approved | needs_changes | review_failed
- PRD: `<prd_path>`
- Ledger: `<ledger_path>`
- Status file: `<status_path>`

### Reviewer Ledger
- PRD Intent — integrated | skipped | blocked
- PRD Product Principles — integrated | skipped | blocked
- PRD No Stubs — integrated | skipped | blocked
- PRD Security Privacy Reliability — integrated | skipped | blocked
- PRD BDD Flows — integrated | skipped | blocked
- PRD Scope Stage Fit — integrated | skipped | blocked
- PRD Dependencies — integrated | skipped | blocked

### Integration Outcome
- `[REVIEW:...]` comments added to PRD: yes | no
- Reviewer files removed: yes | no

### Next Step
- If `approved`: `Ready to hand off to /dev:plan-from-prd`
- If `needs_changes`: `Resolve integrated PRD comments, then rerun /review:prd`
- If `review_failed`: `Repair the failed review cycle before handoff`
```

## Scope

This command is review plus integration:

- Phase 1: create review artifacts
- Phase 2: seven parallel reviewer passes
- Phase 3: update the integration ledger
- Phase 4: integrate combined feedback into the PRD
- Phase 5: write final review status and remove the seven reviewer files

The canonical durable artifacts are:

- the PRD itself
- `thoughts/validation/prd-reviews/<prd-slug>/integration-ledger.md`
- `thoughts/validation/prd-reviews/<prd-slug>/review-status.json`
