---
name: planning-workflow
description: Shared planning doctrine for creating or updating executable software plans. Use when moving from read-only research into writing a real plan, when you need to structure a resumable TDD/BDD-driven implementation plan, or when a command like `dev:plan` needs the canonical planning workflow plus guidance on which domain skills to load.
---

# Planning Workflow

Use this skill as the canonical source of truth for plan-writing methodology across repos.

## Boundaries

- `plan mode` is for discovery only: inspect the codebase, validate assumptions, gather evidence, and identify ambiguities.
- `dev:plan` (or equivalent plan-materialization step) writes the actual plan file once discovery has produced enough evidence to choose the correct readiness state: `execution-ready` when foundational decisions are resolved, or a single non-ready `research-ready` artifact when further research is the next handoff. Before that handoff point, the work remains `discovery`.
- `dev:plan` ends when the plan artifact is written or updated; execution starts only after a separate explicit execution command or a new user instruction.
- In Pi-style reviewed-plan workflows, keep the handoff explicit: `/review:plan` -> `/review:change-integrate` -> optional `/review:plan-adversarial` -> `/cmd:execute-plan` -> `/dev:run` or `/ralph:run`. Do not assume a hidden fallback to Claude Code or any other alternate review surface.
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

- Load `product-principles` for planning work that affects user/operator/agent workflows, defaults, onboarding, recovery behavior, error handling, architecture, or regression strategy. Use it to define the golden path, safe defaults, self-healing expectations, actionable error guidance, and a quick dissonance audit against repo guidance (`AGENTS.md`, product-intent docs, onboarding docs, config/status surfaces, and tests).
- Load `tdd-test-writer` when phases will rely on tests-first delivery or when the RED-phase contract needs strengthening.
- Load repo-recommended skills from `AGENTS.md` for the relevant surface or stack.
- Load domain-specific skills when the planned work clearly spans those domains (frontend, React/Next, Rust, MCP, browser automation, UI review, etc.).

The plan should reflect the behavior those skills require, not merely mention them.

When product work touches interactions, commands, processes, or operator/agent workflows, the plan should encode these default beliefs unless repo evidence explicitly requires a different constraint:

- the product should do the obvious right thing by default,
- routine faults should be detected and healed inside the normal requested flow,
- normal workflows should not depend on users discovering and running separate status or remediation commands,
- errors should assume a capable agent is reading them and should explain what happened, what the system already tried, why automation stopped, and what to do next,
- fail-closed behavior is reserved for ambiguous or high-risk situations such as data loss, security/privacy risk, or identity/authority uncertainty.

## Research standard

Validate important claims directly against repo reality before writing the plan:

- locate existing files, routes, registries, commands, and patterns,
- confirm data shapes, schemas, contracts, and constraints,
- identify integration points, parity surfaces, and likely risks,
- verify command names, package names, and file paths used in `### Verify` sections,
- identify the simplest supported workflow and which inputs should be optional because the system can infer or heal them,
- identify which manual status-check or repair steps currently exist and whether they should instead become built-in behavior on the normal path,
- check whether repo guidance, onboarding docs, config defaults, status surfaces, and tests are aligned with that default-path contract.

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
- define what the system should do automatically before asking the user or agent to intervene,
- add `Given/When/Then` scenarios for happy path, failure path, and relevant edge cases,
- add counterexample or ambiguity scenarios when matching, routing, identity, parsing, refs, or policies could yield misleading passes,
- add boundary or scale scenarios when volume, fan-out, or aggregation could change correctness,
- add cross-surface parity scenarios when behavior must match across HTTP/CLI/MCP/UI or similar interfaces.

For workflow and product-surface planning, include scenarios that distinguish:

- routine recoverable faults that should self-heal,
- ambiguous or high-risk faults that should fail closed,
- and the exact agent-legible error or inline guidance expected when automation must stop.

For every phase:

- start with failing tests first when practical,
- map tests to acceptance criteria and BDD scenario IDs,
- make the RED-phase contract strong enough to catch partial or misleading implementations,
- if strict TDD is not practical, state why and define compensating verification.

## Phase template

Every phase must include:

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

An `execution-ready` plan is ready only when all of the following are true:

- important questions are resolved,
- acceptance criteria and BDD scenarios are concrete,
- phase `### Verify` steps are executable and current for the real repo,
- product-intent alignment is explicit when required,
- parity expectations are explicit for multi-surface work,
- self-healing expectations and fail-closed boundaries are explicit for workflow-affecting work,
- plans do not normalize routine manual remediation when the product should absorb that burden instead,
- no unresolved `Open Questions` remain in a ready plan,
- no unresolved low-confidence decisions remain,
- foundational decisions are not deferred into later execution phases,
- progress and resume instructions are present.

If any item above is still missing, the plan is `not ready`: stay in `discovery` while evidence is still being gathered, or emit a `research-ready` artifact when research is the explicit next handoff.

## Readiness states

- `discovery` means planning evidence is still being gathered and the work is not yet plan-finalization-ready; it is a pre-handoff state, not a substitute for a written research handoff.
- `research-ready` means exactly one non-ready plan artifact may be written once discovery has established that research is the next handoff; that artifact must capture unresolved decisions, the next research step, and the condition for later promotion.
- `execution-ready` means the plan can hand off to execution without inventing missing contracts, rollout semantics, compatibility rules, or other foundational behavior.
- A plan is `not ready` when foundational decisions are deferred into later execution phases, even if the phase list itself looks complete.

## Low-confidence decision workflow

- Treat any materially outcome-shaping unknown as a `low-confidence` decision: contracts, migrations, rollout semantics, compatibility behavior, safety constraints, or cross-surface behavior.
- Resolve low-confidence decisions from repo evidence first.
- If repo evidence is insufficient and the choice changes intended behavior, ask the user before finalizing the plan.
- If the answer is researchable without user intent input, delegate research immediately or emit a non-ready `research-ready` research plan artifact.
- A non-ready plan artifact must list the unresolved low-confidence decisions, make the exact next research action explicit, and stay clearly separate from an `execution-ready` handoff.
- Never bury low-confidence decisions inside future execution phases or assume implementation will resolve them later.

## Complexity-aware completeness

- Keep the doctrine `complexity-aware` and domain-agnostic: scale planning depth to the real task shape, not the stack.
- Simple local wiring or narrow refactor tasks should stay `lightweight`; do not force heavyweight schema, protocol, or rollout sections when they do not improve confidence.
- Non-trivial, migration-heavy, compatibility-sensitive, or multi-surface work requires complete contracts before it can be `execution-ready`.
- Every non-trivial ready plan must include a `test coverage matrix` that maps acceptance criteria and BDD scenarios to planned test layers, intended suites or files, and `### Verify` commands strong enough to catch partial implementations.
- If task complexity is uncertain, bias toward more explicit contracts and acceptance-to-test mapping until evidence justifies a lighter plan.

## Verification ownership

- Phase `### Verify` checks are agent-run execution gates: they must be runnable during implementation, grounded in repo reality, and expanded with compensating checks when strict TDD is not practical.
- Final completion still requires a semantic coherence review across the shared files touched by the work so reviewers confirm the doctrine means the same thing everywhere, not just that strings appear.

## Handoff to execution

When the plan is complete:

- leave the repo ready for `ralph:run` or the repo's execution command,
- `ready for` means handoff-ready, not permission to start execution in the current command,
- if the active command is planning-only, stop after updating the plan and reporting the next suggested command,
- ensure the plan reflects repo-specific commands from `AGENTS.md`,
- keep deviations and migration notes append-only,
- do not stop with an implicit draft if the user asked for an execution-ready plan.
