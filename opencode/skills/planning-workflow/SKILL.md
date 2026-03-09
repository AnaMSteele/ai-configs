---
name: planning-workflow
description: Shared planning doctrine for creating or updating executable software plans. Use when moving from read-only research into writing a real plan, when you need to structure a resumable TDD/BDD-driven implementation plan, or when a command like `dev:plan` needs the canonical planning workflow plus guidance on which domain skills to load.
---

# Planning Workflow

Use this skill as the canonical source of truth for plan-writing methodology across repos.

## Boundaries

- `plan mode` is for discovery only: inspect the codebase, validate assumptions, gather evidence, and identify ambiguities.
- `dev:plan` (or equivalent plan-materialization step) writes the actual plan file after discovery is complete.
- During plan writing, edit only the target plan artifact unless the repo's `AGENTS.md` explicitly allows another planning-side file.
- Do not change product code, tests, app config, docs, generated files, or environment files while planning.
- Avoid side effects: no installs, codegen, migrations, formatting runs, commits, rebases, resets, or destructive commands.

## Planning inputs

Before writing a plan, read in this order:

1. Root `AGENTS.md` for repo-specific commands, quality gates, docs, and skill-routing hints.
2. `thoughts/specs/product_intent.md` when the repo requires product-intent alignment.
3. Optional `thoughts/plans/AGENTS.md` only when the repo uses local planning overrides beyond this shared skill.
4. Existing plan file, legacy plan bundle, task list, issue, or source specification that the plan must preserve.

If required repo guidance or product intent is missing, stop and ask the user or tell them the repo bootstrap needs to be completed first.

## Skill routing

Always consider which additional skills are needed before writing the plan.

- Load `tdd-test-writer` when phases will rely on tests-first delivery or when the RED-phase contract needs strengthening.
- Load repo-recommended skills from `AGENTS.md` for the relevant surface or stack.
- Load domain-specific skills when the planned work clearly spans those domains (frontend, React/Next, Rust, MCP, browser automation, UI review, etc.).

The plan should reflect the behavior those skills require, not merely mention them.

## Research standard

Validate important claims directly against repo reality before writing the plan:

- locate existing files, routes, registries, commands, and patterns,
- confirm data shapes, schemas, contracts, and constraints,
- identify integration points, parity surfaces, and likely risks,
- verify command names, package names, and file paths used in `### Verify` sections.

Use targeted `Glob`, `Grep`, and `Read` first. Delegate broad codebase discovery only when targeted search is not enough.

## Canonical plan contract

Write plans as execution artifacts, not brainstorming notes. A ready plan must be executable by another agent without inventing missing semantics.

Required sections for new plans unless repo-local overrides say otherwise:

1. Title
2. Status
3. Goal
4. Why this plan exists
5. Authority and inputs
6. Current implementation reality
7. Progress
8. Resume instructions (agent)
9. Product intent alignment
10. Locked decisions
11. Acceptance criteria
12. BDD scenarios
13. Phase-by-phase execution plan
14. Verification strategy
15. Delivery order
16. Non-goals
17. Decisions / Deviations log

Legacy heading aliases may be preserved in historical plans, but new plans should use canonical headings unless the repo explicitly says otherwise.

## TDD + BDD rules

For every acceptance area:

- define acceptance in observable user or system outcomes,
- add `Given/When/Then` scenarios for happy path, failure path, and relevant edge cases,
- add counterexample or ambiguity scenarios when matching, routing, identity, parsing, refs, or policies could yield misleading passes,
- add boundary or scale scenarios when volume, fan-out, or aggregation could change correctness,
- add cross-surface parity scenarios when behavior must match across HTTP/CLI/MCP/UI or similar interfaces.

For every phase:

- start with failing tests first when practical,
- map tests to acceptance criteria and BDD scenario IDs,
- make the RED-phase contract strong enough to catch partial or misleading implementations,
- if strict TDD is not practical, state why and define compensating verification.

## Phase template

Every phase must include:

- `### End state`
- `### End State`
- `### Tests first`
- `### Work`
- `### Expected files`
- `### Verify`

Phase guidance:

- keep phases coarse and outcome-oriented,
- do not hide task lists inside phases,
- make multi-surface parity inventory explicit in `### Expected files` or `### Work`,
- lock canonical contracts, schemas, fixtures, payloads, or evidence sources before downstream phases depend on them.

## Resumability rules

- `## Progress` contains the only checkboxes in the plan.
- Use stable IDs like `P1`, `P2`, ... and keep them aligned to phase headers.
- Preserve completed items and append-only deviation/history sections when regenerating a plan.
- `Resume instructions` must tell the next agent to read the document fully, identify the first unchecked progress item, continue phase-by-phase, and ask the user only for truly unresolvable decisions.

## Ready bar

A plan is ready only when all of the following are true:

- important questions are resolved,
- acceptance criteria and BDD scenarios are concrete,
- phase `### Verify` steps are executable and current for the real repo,
- product-intent alignment is explicit when required,
- parity expectations are explicit for multi-surface work,
- no unresolved `Open Questions` remain in a ready plan,
- progress and resume instructions are present.

## Handoff to execution

When the plan is complete:

- leave the repo ready for `ralph:run` or the repo's execution command,
- ensure the plan reflects repo-specific commands from `AGENTS.md`,
- keep deviations and migration notes append-only,
- do not stop with an implicit draft if the user asked for an execution-ready plan.
