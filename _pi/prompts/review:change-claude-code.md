---
description: Run a change review using Claude Code directly
argument-hint: '<path to plan.md | plan slug | legacy: <spec> <tasks> | legacy: <directory containing spec.md and tasks.md>'
---

# Change Review via Claude Code

Review the provided plan by launching Claude Code directly through the `pi-processes` extension, then integrate the results into a clean plan.

Documents to review: $ARGUMENTS

## Execution Mode

- Use the `process` tool from the `pi-processes` extension to launch Claude Code directly.
- Start a named process such as `claude-code-review` and run a Claude Code review prompt against the target plan file (for example via `claude -p` or `claude task`, depending on the installed CLI surface).
- Run a single Claude Code session that:
  1. resolves the target plan file,
  2. reviews the plan as a cohesive unit,
  3. adds inline review comments using the `[REVIEW:CLAUDE CODE] ... [/REVIEW]` format for issues it finds,
  4. applies the accepted feedback using the same rules as `/review:change-integrate`, and
  5. leaves the plan clean and executable.
- Do not delegate the review to a `reviewer-*` subagent.
- Do not stop after the review comments are written; complete the integration pass before responding.
- Wait for the Claude Code process to finish, then verify the resulting plan file in this session.

Your reviewer name is CLAUDE CODE

Use this comment format:
```
[REVIEW:CLAUDE CODE] Your critical feedback here [/REVIEW]
```

To respond to other reviewers:
```
[REVIEW:CLAUDE CODE] RE: [OtherReviewer] - Your response [/REVIEW]
```

# Change Review and Integration (Single Plan File)

Review the provided plan as a cohesive unit, then integrate the accepted feedback into the same file. Your goal is to ensure the final plan is solid, executable, and clean without scope creep or error.

Documents to review: $ARGUMENTS

## Scope (Review-and-Integrate; Do Not Leave Review Comments Behind)

This command is review-and-integrate.

- The Claude Code run may write inline `[REVIEW:...] ... [/REVIEW]` comments while reviewing.
- Once the review pass is complete, those comments must be resolved by integrating the accepted feedback into the plan.
- Do not leave unresolved review comments in the final file.
- Do not stop after the review pass; continue through integration and validation.

## Process

### 0) Resolve Inputs (Plan File, Slug, or Legacy Bundle)

Preferred input:

- A single plan file: `thoughts/plans/<slug>.md`

Accept legacy inputs for migration only:

- `<spec_path> <tasks_path>`
- A directory containing `spec.md` and `tasks.md`

Resolution rules:

- If `$ARGUMENTS` starts with `@`, strip the leading `@` and treat as workspace-relative.
- If a single argument is an existing `.md` file, treat it as `plan_path`.
- If a single argument is a slug, resolve to `thoughts/plans/<slug>.md`.
- If the plan file does not exist but a legacy bundle exists for the slug, migrate to `thoughts/plans/<slug>.md` (do not modify legacy files) and review the migrated plan.

If multiple candidates match or a required file is missing, ask for an explicit plan file path.

### 1) Launch Claude Code Directly

Use the `process` tool to start one Claude Code session that performs the review.

The launched Claude Code prompt should:

- inspect the target plan,
- look for gaps, risks, ambiguity, incorrect references, and scope drift,
- write inline review comments only where they improve the final plan,
- then integrate every resolved comment into the plan,
- preserve the plan structure and progress state,
- and leave no unresolved review comments behind.

Do not route the work through a review subagent. The whole point of this command is to use Claude Code itself for the review and integration pass.

### 2) Validate the Result

After the Claude Code process completes:

- read the resulting plan file,
- confirm there are no remaining `[REVIEW:...]` comments,
- confirm the plan still has runnable phases, progress, and verify steps if it had them before,
- and confirm the file now reflects the accepted feedback.

### 3) Summary

After verification, provide a concise summary of what changed and whether the plan is ready for execution.

## Summary Format

```
## Review and Integration Complete

### Changes Made:
- [List of review findings that were integrated]

### Final Status:
[Solid / Needs more work]

### Recommendation:
[Proceed / Proceed with caution / Major revision needed]
```
