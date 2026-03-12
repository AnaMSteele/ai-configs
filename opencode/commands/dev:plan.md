---
description: Materialize or update the actual single-file execution plan after discovery, using shared planning doctrine plus repo-specific guidance
argument-hint: '<slug | "short description" | thoughts/plans/<slug>.md>'
---

# Materialize Plan

You are leaving read-only discovery mode and entering plan-materialization mode. This is still non-execution work: synthesize validated research into the actual execution plan file.

Treat this command as planning-only work even though normal file writes are available. You may inspect the repo and write the plan artifact, but you must not change product code, tests, app config, docs, generated files, or environment files.

Your job ends after writing or updating the single plan file and reporting the result. Do not create execution todos, do not begin implementation, and do not run execution-oriented verification once the plan file is complete.

This command produces (or updates):

- `thoughts/plans/<slug>.md`

## Inputs

Argument (`$ARGUMENTS`) is either:

- A slug (recommended), e.g. `worktree-cleanup`
- A short description (derive a slug)
- A path to an existing `.md` plan file (treat it as the plan path)

## Output Contract

Write exactly one file:

- `thoughts/plans/<slug>.md`

Do not create `spec.md`, `tasks.md`, per-plan directories, or any non-plan file unless the user explicitly asks.

Completion condition for this command:

- Exactly one plan file at `plan_path` is written or updated.
- No non-plan file is modified.
- The final response reports the plan path and suggests follow-up commands without running them.
- Then stop and wait for a new user instruction.

Forbidden transitions for this command:

- Do not create a new execution todo list after the plan is complete.
- Do not switch into build, run, or implementation mode.
- Do not edit any file except `plan_path` unless the user explicitly broadens scope.
- Do not run lint, tests, build, e2e, migrations, or other execution-oriented verification.
- Do not invoke `/review:change`, `/ralph:run`, or any other follow-up command from this command; only suggest them.

Legacy bundles:

- If a legacy bundle exists at `thoughts/plans/<slug>/spec.md` and/or `thoughts/plans/<slug>/tasks.md`, you may read it for migration.
- Do not delete or modify legacy bundle files.

## Process

### 1) Resolve Plan Path

1. If `$ARGUMENTS` looks like a path to an existing `.md` file, treat it as `plan_path`.
2. Otherwise derive `slug` from `$ARGUMENTS`.
   - Use lowercase, digits, and hyphens only.
   - If multiple plausible slugs exist, ask once with `question` and use the user's choice.
3. Set `plan_path` to `thoughts/plans/<slug>.md`.
4. Ensure `thoughts/plans/` exists (create it if missing).

### 2) Re-establish Planning Context

Before writing the plan:

1. Read the repo root `AGENTS.md`.
2. Read `thoughts/specs/product_intent.md` if the repo uses it.
3. Read `thoughts/plans/AGENTS.md` only if it exists and the repo uses it for local planning overrides.
4. Load the shared `planning-workflow` skill.
5. Load any repo-recommended or surface-specific skills that are clearly relevant to the plan being written.
   - Use `tdd-test-writer` when the phases will depend on tests-first delivery.
   - Use `dependency-selection` when the planned work introduces or replaces non-trivial functionality with real build-vs-buy choices, such as protocol handling, parsing, transport, wrappers, infrastructure, or integrations.
   - Use frontend, React/Next, Rust, MCP, browser, or other domain skills when the work clearly spans those domains.

If required planning guidance is missing and the repo cannot be planned confidently without it, ask the user instead of guessing.

### 3) Read Existing Plan (If Present)

If `plan_path` exists, read it fully.

Preserve existing state:

- Any completed checkboxes (`[x]`) in `## Progress` and their IDs (do not renumber)
- Any existing entries in `## Decisions / Deviations Log`
- Any existing entries in `## Plan Changelog` (append a new entry when regenerating)

Legacy migration support (read-only; do not delete legacy files):

- If `thoughts/plans/<slug>/spec.md` and/or `thoughts/plans/<slug>/tasks.md` exist, read them.
- Prefer the legacy spec as the source of intent.
- If legacy tasks contain completed items, convert that state into coarse phase completion in `## Progress`.
  - Do not copy long checklists into the new plan.

### 4) Validate Repo Reality

Validate key claims from the conversation by directly inspecting the codebase:

- Locate the relevant files and existing patterns
- Confirm APIs, data shapes, configuration, and constraints
- Identify integration points and risks
- Verify actual commands, targets, package names, and paths that the plan will reference

Use `Glob`, `Grep`, and `Read` for targeted research. Use `Task(subagent_type="explore")` only for broad searches.

Do not run side-effecting commands while doing this validation.

### 5) Write `plan_path`

Write (or update) `plan_path` by following the shared `planning-workflow` skill, the repo's `AGENTS.md`, and any explicit repo-local planning overrides.

Before any write or side-effecting action, verify it only updates `plan_path`. If it would touch any other file or begin execution, do not do it under `dev:plan`.

Non-negotiable compatibility requirements:

- Write exactly one plan file at `plan_path`.
- Preserve prior progress and append-only logs when regenerating.
- `## Progress` contains the only checkboxes and uses stable IDs (`P1`, `P2`, ...).
- Each phase includes `### End State`, `### Tests first`, `### Expected files`, `### Work`, and `### Verify`.
- Ready plans do not leave unresolved `Open Questions` or equivalent unresolved-decision sections.
- `### Verify` steps are copy/paste ready and match actual repo reality.
- The plan is resumable by another agent without inventing missing semantics.
- When the change introduces or replaces non-trivial functionality, the plan includes a dedicated dependency/library evaluation section or equivalent explicit checkpoint that names the official SDKs and well-maintained libraries considered, records the chosen option and why it is acceptable, or explains why custom implementation is justified.
- When no dependency/library scan is needed, the plan still includes a brief statement explaining why the work is trivial or purely local wiring.

Before considering the plan complete:

- Use product intent if the repo requires it, and make the alignment explicit in the plan.
- Resolve every important question before finalizing the plan.
- If the codebase or docs answer a question with high confidence, answer it directly in the plan.
- If confidence is not high enough, ask the user and incorporate the answer into the plan.
- Use `tdd-test-writer` when available to improve the `### Tests first` sections.
- Make `### Tests first` strong enough to catch partial or misleading implementations by covering happy path, guardrail/failure behavior, counterexamples or ambiguity cases, and boundary/scale or parity cases when applicable.
- Lock canonical contracts, payloads, schemas, or evidence sources in the plan before phases that depend on them.
- Plans that require dependency/library evaluation are not ready until that checkpoint is documented; a missing official-SDK/library decision keeps the plan in draft.

### 6) Consistency Pass

Before finishing:

- The plan structure follows the shared planning workflow and any repo-local planning overrides.
- Every acceptance criterion has at least one phase `### Verify` item that provides evidence.
- Every progress checkbox corresponds to a phase header.
- Phase ordering and naming is consistent across phases, progress, and acceptance criteria.
- Every phase has a `### Tests first` section.
- The `### Tests first` sections describe user-visible behavioral outcomes, not only implementation mechanics.
- BDD scenarios or equivalent `Given/When/Then` coverage are explicit when required by repo guidance.
- Multi-surface phases make parity expectations explicit in `### Tests first`, `### Work`, or `### Expected files`.
- `### Verify` commands are copy/paste ready and match current repo/package/target names.
- There are no unresolved decision points left in the plan.
- If non-trivial build-vs-buy choices are in scope, the dependency/library evaluation checkpoint is present; otherwise the plan briefly states why no scan was needed.
- No non-plan file was modified.

## Next Steps For The User

These are suggestions for the user to run after this command finishes. Do not run them as part of `dev:plan`.

- Review the plan:
  - `/review:change thoughts/plans/<slug>.md`
- Execute:
  - `/ralph:run thoughts/plans/<slug>.md`
