---
name: dev-plan
description: Materialize or update a single-file execution plan after discovery. Planning-only work - synthesizes validated research into an actual execution plan without modifying product code.
---

# Materialize Plan

You are leaving read-only discovery mode and entering plan-materialization mode. This is still non-execution work: synthesize validated research into the actual execution plan file.

Treat this command as planning-only work even though normal file writes are available. You may inspect the repo and write the plan artifact, but you must not change product code, tests, app config, docs, generated files, or environment files.

Your job ends after writing or updating the single plan file and reporting the result. Do not create execution todos, do not begin implementation, and do not run execution-oriented verification once the plan file is complete.

## Usage

```
/skill:dev-plan <slug | "short description" | thoughts/plans/<slug>.md>
```

## Output

This command produces (or updates): `thoughts/plans/<slug>.md`

## Process

### 1) Resolve Plan Path

1. If arguments look like a path to an existing `.md` file, treat it as `plan_path`.
2. Otherwise derive `slug` from arguments (lowercase, digits, hyphens only).
3. Set `plan_path` to `thoughts/plans/<slug>.md`.
4. Ensure `thoughts/plans/` exists (create it if missing).

### 2) Re-establish Planning Context

Before writing the plan:

1. Read the repo root `AGENTS.md`.
2. Read `thoughts/specs/product_intent.md` if the repo uses it.
3. Read `thoughts/plans/AGENTS.md` only if it exists for local planning overrides.
4. Load relevant skills:
   - `tdd-test-writer` when phases will depend on tests-first delivery
   - `dependency-selection` when introducing non-trivial functionality
   - Domain-specific skills (frontend, React/Next, Rust, etc.)

If required planning guidance is missing, ask the user instead of guessing.

### 3) Read Existing Plan (If Present)

If `plan_path` exists, read it fully.

Preserve existing state:
- Any completed checkboxes (`[x]`) in `## Progress` and their IDs
- Existing entries in `## Decisions / Deviations Log`
- Existing entries in `## Plan Changelog` (append when regenerating)

Legacy migration (read-only; do not delete):
- If `thoughts/plans/<slug>/spec.md` and/or `thoughts/plans/<slug>/tasks.md` exist, read them.
- Prefer the legacy spec as the source of intent.

### 4) Validate Repo Reality

Validate key claims by directly inspecting the codebase:
- Locate relevant files and existing patterns
- Confirm APIs, data shapes, configuration, and constraints
- Identify integration points and risks
- Verify actual commands, targets, package names, and paths

Use `bash` with `find`, `rg`, and `read` for targeted research. Use `subagent` with exploration agents only for broad searches.

Do not run side-effecting commands while doing this validation.

### 5) Write plan_path

Write (or update) `plan_path` following shared planning workflow and repo-specific guidance.

Non-negotiable requirements:
- Write exactly one plan file at `plan_path`
- Preserve prior progress and append-only logs when regenerating
- `## Progress` contains the only checkboxes with stable IDs (`P1`, `P2`, ...)
- Each phase includes `### End State`, `### Tests first`, `### Expected files`, `### Work`, and `### Verify`
- Ready plans have no unresolved `Open Questions`
- `### Verify` steps are copy/paste ready and match actual repo reality
- The plan is resumable by another agent without inventing missing semantics

### 6) Consistency Pass

Before finishing:
- Every acceptance criterion has at least one phase `### Verify` item
- Every progress checkbox corresponds to a phase header
- Phase ordering and naming is consistent
- Every phase has a `### Tests first` section describing user-visible outcomes
- `### Verify` commands are copy/paste ready and match current repo/package/target names
- No non-plan file was modified

## Forbidden Actions

- Do not create a new execution todo list after the plan is complete
- Do not switch into build, run, or implementation mode
- Do not edit any file except `plan_path` unless scope is explicitly broadened
- Do not run lint, tests, build, e2e, migrations, or other execution-oriented verification
- Do not invoke other skills as part of this command; only suggest them

## Suggested Next Steps

After this skill completes, the user may:
- Review the plan: `/skill:review-change thoughts/plans/<slug>.md`
- Execute: Run implementation commands or use task processing skills
