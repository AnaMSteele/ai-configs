# Root AGENTS.md Template

Use this as a starting point for `<repo>/AGENTS.md`. Replace bracketed placeholders.

## 1) Purpose and scope

- State that this file is the authoritative repo-specific guide for coding agents.
- Clarify precedence if `.cursorrules` or other rule files diverge.

## 2) Repo reality checks

- Secrets policy (`.env*`, encryption, commit restrictions).
- Local vs production safety boundaries.
- Any "never do" commands specific to the repo.

## 3) Build / lint / test commands

Provide copy-paste-ready commands:

- install/dev/build
- lint/format
- unit test full suite + single-file + single-test pattern
- e2e and/or contract tests

## 4) Quality gates

Define the exact gate order (example):

1. lint
2. unit
3. build
4. e2e
5. contract (if relevant)

Include one canonical command if available (for example `pnpm quality:gates`).

## 5) Plan execution mode

Codify the quality-gated loop:

- implement one phase
- review
- re-review until critical issues are closed
- only then move to the next phase

Require phase-level progress updates and resumable handoff notes.

Reference where plan standards live (for example `thoughts/plans/AGENTS.md`) and make that file authoritative for plan structure.

Require a product-intent source-of-truth file at `thoughts/specs/product_intent.md`.

- If missing, create it before plan execution.
- Treat plan updates that conflict with product intent as blocking until resolved.

Require tests-first behavior for plan phases where practical and call out expected RED->GREEN evidence in handoffs.

## 6) Commit and handoff rules

- Commit messages capture rationale, not only what changed.
- Require push before marking work complete (unless user asks otherwise).
- Include what evidence should be returned (changed files + gate summary + residual risks).

## 7) Style and architecture guardrails

- Formatter/linter authority.
- Import/type conventions.
- Error-handling expectations.
- Where to look for subsystem docs before non-trivial edits.

## 8) Worktree and environment notes

- Worktree env file sync steps.
- Any bootstrapping commands for local dependencies.

## 9) Fast triage commands (optional)

Useful quick commands for diagnostics, status, and targeted tests.
