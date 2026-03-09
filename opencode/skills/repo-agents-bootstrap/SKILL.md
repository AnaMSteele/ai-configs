---
name: repo-agents-bootstrap
description: Bootstrap or refactor repository AGENTS guidance and planning standards into a reusable, quality-gated delivery workflow. Use when creating/updating `AGENTS.md`, creating `thoughts/plans/AGENTS.md` (or equivalent plan standards), codifying plan-then-build execution rules, adding TDD/BDD acceptance criteria, or aligning multiple repos to one engineering operating model.
---

# Repo Agents Bootstrap

## Overview

Create two aligned guidance layers for any repo:

1. Root `AGENTS.md` for repository-specific commands, safety rails, and quality gates.
2. Plan standards file (usually `thoughts/plans/AGENTS.md`) for how plans are written and executed.

This skill encodes a shared operating model observed across ccore and doct* work: quality-gated phase execution, resumable plans, explicit decision logs, and test-first delivery centered on user-visible behavior.

## Modes

Pick one mode before editing files:

- `audit_only`: analyze repo alignment and propose deltas without modifying repo files.
- `bootstrap_new`: create root `AGENTS.md` + plan standards for repos with little/no prior guidance.
- `migrate_existing` (recommended default): preserve strong existing guidance, patch only misalignments, and avoid broad rewrites.

For mature repos (like doct/ccore), start in `audit_only` and present a delta plan first.

## Operating Model To Codify

Capture these behaviors as defaults:

- Plan-first execution with phase checkpoints (`Implement phase N` -> `Review/Re-review` until zero critical issues).
- Phase advancement only when the latest review reports `No issues found.` or only explicitly logged low-risk deferred items remain.
- Resumability: `Progress` with stable IDs, explicit `Resume Instructions`, and append-only decision/deviation logs.
- Evidence-first validation: lint, unit, build, e2e (and contract tests if applicable) before claiming done.
- Review loops as gates: do not advance to next phase while reviewer still reports unresolved critical issues.
- Commit and push discipline with rationale, not just code diffs.
- Test-first posture: define behavior before implementation wherever practical.
- Product-intent anchored planning: every active plan must trace back to `thoughts/specs/product_intent.md`.
- Validate `### Verify` commands against real repo/package/target names before execution.
- Make multi-surface parity expectations explicit when phases span HTTP/CLI/MCP/UI or similar interfaces.
- Update stale fixtures/tests when locked contracts, payloads, schemas, or evidence sources change.

## TDD + BDD Rules

For every phase in a plan:

1. Define acceptance criteria in user outcomes, not implementation terms.
2. Add BDD scenarios (`Given/When/Then`) for happy path, edge path, and failure path.
3. Add counterexample/ambiguity, boundary/scale, and cross-surface parity scenarios whenever the phase can fail in those ways.
4. Write failing tests first (RED) where practical.
5. Implement the smallest real slice to pass tests (GREEN).
6. Refactor safely while preserving behavioral coverage (REFACTOR).

If strict TDD is skipped, require an explicit reason in the phase and add compensating checks.

Use the `tdd-test-writer` skill when available to harden the RED-phase contract.

## Bootstrap Workflow

### 1) Gather repository truth

- Read existing `AGENTS.md`, `.cursor/rules/*`, package/tool configs, and test scripts.
- Build an authoritative command list for:
  - install/dev/build,
  - lint/format,
  - unit tests (including single-test invocations),
  - e2e/contract tests,
  - full quality gate command.

Also detect whether a plan-standards AGENTS file already exists (for example `thoughts/plans/AGENTS.md`).
Also detect whether `thoughts/specs/product_intent.md` exists.

If `product_intent.md` is missing:

- mark it as a `critical` alignment gap,
- create it from `references/product_intent_template.md`,
- block plan-standard completion until the file exists.

### 2) Gather historical delivery patterns (optional but recommended)

When prior OpenCode sessions exist, review patterns with `opencode db`:

```bash
opencode db "select id, directory, title, time_created, summary_files, summary_additions, summary_deletions from session where directory = '/path/to/repo' or directory like '/path/to/repo/%' order by time_created desc limit 40;" --format tsv
```

Look for repeated titles like:

- `Implement phase ...`
- `Review phase ...` / `Re-review ...`
- `Run Plan (Quality-Gated Loop)`
- `AGENTS.md review ...`

Use those patterns to tune gate strictness, validation expectations, and handoff style.

### 2b) Audit current plan corpus against standards (required for `audit_only` and `migrate_existing`)

For repos with existing plan files, audit heading/structure coverage before proposing rewrites.

Minimum checks:

- `Progress`
- `Resume Instructions (Agent)`
- `Acceptance Criteria`
- `Tests first` under each phase
- `BDD scenarios` or explicit `Given/When/Then`
- `Decisions / Deviations Log`
- `Open Questions` present in execution-ready plans

Produce a short gap matrix (count + file examples) and then propose migration policy:

- Do not rewrite historical completed plans only for formatting.
- Require full standards for all new plans.
- For active plans, add missing sections before further execution.

### 3) Write/update root AGENTS.md

Use `references/root_agents_template.md` as the base. Keep it repository-specific and executable.

Required outcomes:

- Safety rails and repo reality checks (secrets, encrypted env files, production constraints).
- Canonical command set with copy-paste-ready commands.
- Explicit quality gates and ordering.
- Any repo-specific rules that override stale rule files.

### 4) Write/update plan standards AGENTS

Use `references/plan_agents_template.md` as the base.

Required outcomes:

- Required plan sections and ordering.
- Phase template that enforces `End state`, `Tests first`, `Work`, `Expected files`, `Verify`.
- Acceptance criteria and BDD scenarios as first-class plan artifacts.
- Deviation logging and downstream-phase revalidation rules.
- Product intent linkage requirement for every plan.

Migration rule for legacy repos:

- Allow heading aliases in old plans (`Objective` for `Goal`, `Metadata` for `Authority and inputs`, `Current State` for `Current implementation reality`) but require canonical headings in all new plans.
- Only allow `Open Questions` when plan status is explicitly `draft`/`discovery`; execution-ready plans must resolve them.

### 5) Validate coherence

Before finalizing, verify:

- Root `AGENTS.md` commands are real and current.
- Plan standards reference real quality gates from root `AGENTS.md`.
- TDD + BDD requirements are explicit and testable.
- No contradictory guidance between root and plan standards docs.

### 6) Deliver with change rationale

When presenting updates:

- Explain which behavioral patterns were codified.
- Call out any deliberate repo-specific deviations.
- List next steps to run a first plan through the new workflow.

## Output Expectations

For a bootstrap/refactor request, produce:

1. Updated root `AGENTS.md`.
2. Updated plan standards file (`thoughts/plans/AGENTS.md` or repo equivalent).
3. `thoughts/specs/product_intent.md` present (new or updated).
4. Short rationale mapping each major rule to observed delivery behavior.
5. Optional first-pass migration notes for existing plans.

For `audit_only`, produce instead:

1. Alignment scorecard (root AGENTS + plan corpus).
2. Misalignment list ordered by impact (`critical`, `important`, `nice-to-have`).
3. Proposed minimal patch set (no broad rewrite).
4. Adoption policy for existing plans (what must change now vs later).

## Resources

- `references/root_agents_template.md` - baseline structure for repo-root `AGENTS.md`.
- `references/plan_agents_template.md` - baseline structure for plan standards with TDD/BDD hooks.
- `references/product_intent_template.md` - baseline structure for `thoughts/specs/product_intent.md`.
