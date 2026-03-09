# Planning Overrides AGENTS Template

Use this template for `thoughts/plans/AGENTS.md` only when the repo needs planning rules beyond the shared `planning-workflow` skill.

Do not restate the full shared planning doctrine here. This file is for repo-local overrides only.

## Objective

- State which planning behaviors differ from or add to the shared `planning-workflow` skill.
- Keep overrides concrete, repo-specific, and minimal.

## Required local inputs

- Product intent path if different from `thoughts/specs/product_intent.md`.
- Required docs or directories planners must read before writing a plan.
- Canonical plan output path if different from `thoughts/plans/<slug>.md`.

## Repo-specific plan additions or overrides

- Additional required headings beyond the shared plan contract.
- Allowed heading aliases for this repo, if any.
- Any mandatory plan metadata or delivery-order conventions.

## Repo-specific TDD / BDD expectations

- Additional scenario types required in this repo.
- Contract, fixture, parity, or evidence-source expectations unique to this repo.
- Cases where strict TDD is commonly impractical and what compensating verification is required.

## Skill routing hints

- List the skills planners should load for common repo surfaces.
- Example: frontend work -> `vercel-react-best-practices`, browser flows -> `webapp-testing`, Rust services -> `rust-best-practices`.

## Verify command requirements

- Canonical quality-gate commands that plans should reference.
- Any repo-specific command patterns, package filters, or environment requirements planners must use.

## Legacy migration policy

- What old plan formats are acceptable to preserve.
- Which sections must be backfilled before an old plan can continue execution.

## Local ready bar additions

- Any repo-specific conditions that must be true before a plan is considered ready.
- Keep this additive to the shared ready bar.

## Notes

- If this file grows into a restatement of the shared planning workflow, collapse it back into repo-specific deltas and push the shared rule into the central skill instead.
