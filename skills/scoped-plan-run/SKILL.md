---
name: scoped-plan-run
description: Execute an existing implementation plan persistently through code changes, scoped Claude and Codex reviews, fixes, verification, commit, push, and PR creation without expanding beyond the plan's stated scope.
---

# Scoped Plan Run

Use this skill when the user has a plan file and wants it implemented all the way to a pull request with both Claude and Codex review, while preventing reviewer-driven scope creep.

The plan is the contract. Reviews can reveal adjacent problems, but they do not expand the contract unless the user explicitly approves that expansion.

## Invocation

```text
Use $scoped-plan-run to execute thoughts/plans/<slug>.md
```

Accept either a plan path or a slug. For a slug, resolve `thoughts/plans/<slug>.md`.

## Non-Negotiable Rules

- Do not implement if the request is plan-only, review-only, or investigation-only.
- Do not run destructive git commands unless the user explicitly requested them.
- Do not fix adjacent issues just because a reviewer found them.
- Do not let Claude or Codex edit files during review. Reviews are read-only.
- Do not ask reviewers to review the whole product for open-ended problems.
- Do not proceed past a blocked plan decision by silently choosing a larger scope.
- Do not create a PR until verification appropriate to the touched surfaces has run or a blocker is clearly reported.

## Scope Contract

Before editing, read the full plan and extract:

- Goal and user-visible outcome
- Explicit in-scope files, surfaces, phases, and acceptance criteria
- Explicit out-of-scope items
- Required tests and verification commands
- Base branch and PR target, if stated
- Open questions, unresolved decisions, or readiness status

Stop before implementation if:

- the plan is not execution-ready,
- acceptance criteria are vague enough that scope cannot be enforced,
- required user decisions remain unresolved,
- the current branch contains unrelated dirty changes that make isolation unsafe,
- Claude and Codex review are required but one is unavailable and the user has not waived it.

## Scope Classification

Every requested change and every reviewer finding must be classified before implementation:

- `IN_PLAN`: directly required by the plan's acceptance criteria, phase work, or verification.
- `PLAN_PREREQUISITE`: not named in the plan, but the plan cannot work or verify without it.
- `REGRESSION_FROM_THIS_DIFF`: caused by the current implementation and must be fixed before PR.
- `OUT_OF_SCOPE_FOLLOW_UP`: real issue, but not required for this plan.
- `QUESTION`: requires user/product decision before implementation.

Only implement `IN_PLAN`, `PLAN_PREREQUISITE`, and `REGRESSION_FROM_THIS_DIFF`.

Use this acceptance test for any non-obvious finding:

1. Which exact plan line, acceptance criterion, or verification command requires this?
2. Would the planned feature be incorrect or unverifiable if this remained unchanged?
3. Was the issue introduced by this branch?

If the answer to all three is no, defer it.

## Workflow

### 1. Prepare

1. Read repo instructions and the plan file.
2. Check git status and current branch.
3. Identify the base branch from the plan, or use the repo's normal integration branch.
4. Create or confirm a task branch if needed.
5. Record the scope contract in your working notes before editing.

If the worktree is dirty, preserve unrelated changes. Do not clean them up for convenience.

### 2. Implement Phase by Phase

For each unfinished phase:

1. Write or update only the tests required by the phase.
2. Implement the smallest product change that satisfies the phase.
3. Run the phase's targeted verification.
4. Update the plan progress only when that phase is actually complete.
5. Record any deferred discoveries in the plan's deviation log or the repo's discovery ledger.

If a phase exposes a broader product problem, classify it. Fix it only if it is a plan prerequisite or a regression from this diff.

### 3. Self Scope Audit

Before external review, inspect the diff against the plan:

```bash
git diff --stat
git diff --name-only
```

For every changed file, answer: why does this file need to change for this plan?

If a changed file has no plan-bound reason, revert only your own edits to that file or split the work into a separate follow-up branch. Never revert user changes.

### 4. Codex Review

Use the `codex-review-partner` skill or its wrapper for a read-only implementation review.

The review prompt must include:

- the plan path,
- the base branch or comparison range,
- the changed files,
- the scope contract,
- instructions to classify every finding using `IN_PLAN`, `PLAN_PREREQUISITE`, `REGRESSION_FROM_THIS_DIFF`, `OUT_OF_SCOPE_FOLLOW_UP`, or `QUESTION`,
- instructions not to propose unrelated improvements.

Required verdict format:

```text
VERDICT: PASS_SCOPED
VERDICT: PASS_WITH_DEFERRED_FOLLOW_UPS
VERDICT: FIX_IN_SCOPE_FINDINGS
VERDICT: BLOCKED_BY_SCOPE_QUESTION
```

Reject malformed reviews and rerun once with a tighter prompt.

### 5. Claude Review

Use the `claude-code-review` skill for a read-only Claude review.

Claude must receive the same bounded prompt as Codex. It must not edit files. It must return findings in chat, classified with the same scope categories.

If Claude reports broad adjacent risks, keep them as deferred follow-ups unless they pass the scope classification test.

### 6. Triage Reviews Before Fixing

Create a short triage table in your working notes:

```text
Finding | Source | Classification | Decision | Evidence
```

For each Claude and Codex finding:

- Fix `IN_PLAN`, `PLAN_PREREQUISITE`, and `REGRESSION_FROM_THIS_DIFF`.
- Record `OUT_OF_SCOPE_FOLLOW_UP` without fixing it.
- Stop and ask the user for `QUESTION`.

Do not implement fixes directly from reviewer prose. Convert them through this triage step first.

### 7. Repeat Review Loop

After fixing in-scope findings:

1. Rerun targeted tests for touched code.
2. Rerun Codex review with the previous findings and current diff.
3. Rerun Claude review with the same bounded scope.
4. Repeat until both reviewers return `PASS_SCOPED` or `PASS_WITH_DEFERRED_FOLLOW_UPS`.

Stop and report a convergence blocker if:

- the same finding recurs after two fix attempts,
- reviewers disagree on scope and the plan does not resolve it,
- a needed fix would clearly expand the plan,
- three full review cycles have not converged.

## Final Verification

Run the plan's final verification commands. If the plan does not specify enough verification, run the smallest repo-appropriate gate for the changed surfaces and report the gap as a plan defect.

Do not hide failures. Fix failures only when they are in scope or caused by this branch. Otherwise, report them as pre-existing or deferred with evidence.

## Commit, Push, and PR

When implementation and scoped reviews pass:

1. Review `git diff --stat` and `git diff --name-only`.
2. Commit only the scoped changes.
3. Push the branch.
4. Open a PR to the plan's target branch, or the repo's normal integration branch.

The PR body must include:

- plan path,
- in-scope summary,
- verification commands and results,
- Claude review verdict,
- Codex review verdict,
- deferred out-of-scope follow-ups,
- known residual risks.

Do not include memory citations in PR messages.

## Reviewer Prompt Template

Use this shape for both reviewers:

```text
Read-only implementation review. Do not edit files.

Plan: <plan path>
Base/comparison: <base branch or range>
Changed files:
<files>

Scope contract:
<goal, acceptance criteria, in-scope, out-of-scope, verification>

Review only whether this diff correctly implements the plan.
Classify every finding as exactly one of:
- IN_PLAN
- PLAN_PREREQUISITE
- REGRESSION_FROM_THIS_DIFF
- OUT_OF_SCOPE_FOLLOW_UP
- QUESTION

Do not recommend unrelated cleanup, hardening, new features, or broad product audits.
If you notice adjacent problems, list them only as OUT_OF_SCOPE_FOLLOW_UP.

Return one verdict:
- VERDICT: PASS_SCOPED
- VERDICT: PASS_WITH_DEFERRED_FOLLOW_UPS
- VERDICT: FIX_IN_SCOPE_FINDINGS
- VERDICT: BLOCKED_BY_SCOPE_QUESTION

For each finding include: file/line, classification, evidence, and why it is or is not required by the plan.
```

## Final Response

Report:

- PR URL,
- changed files at a high level,
- verification run,
- Claude and Codex verdicts,
- deferred out-of-scope follow-ups,
- any residual risk.

Keep the closeout concise and evidence-based.
