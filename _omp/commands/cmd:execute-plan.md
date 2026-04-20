---
description: Canonical reviewed-plan handoff that routes an explicit plan into /skill:adn-dev-wf or /dev:run
argument-hint: '<plan slug | thoughts/plans/<slug>.md | path/to/plan.md> [--target skill:adn-dev-wf|dev:run]'
---

# Execute Reviewed Plan

This command validates an explicit reviewed plan argument, optionally accepts a target override, and then dispatches the same normalized plan argument into the canonical continuation.

**Arguments**: `$ARGUMENTS`

## Contract

- Accept a plan slug or an explicit `.md` plan path.
- Accept workspace-relative input that starts with `@` by stripping the leading `@`.
- Accept an optional target suffix: `--target skill:adn-dev-wf` or `--target dev:run`.
- Present exactly two execution choices: `/skill:adn-dev-wf` and `/dev:run`.
- Preserve the same normalized plan argument when dispatching.
- Refuse handoff when the plan still contains obvious review or readiness blockers.

## Instructions

### 1) Validate Input

If no argument is provided, respond with:

```text
Usage: /cmd:execute-plan <plan slug | thoughts/plans/<slug>.md | path/to/plan.md> [--target skill:adn-dev-wf|dev:run]

Examples:
  /cmd:execute-plan review-execution-handoff
  /cmd:execute-plan thoughts/plans/review-execution-handoff.md
  /cmd:execute-plan @thoughts/plans/review-execution-handoff.md
  /cmd:execute-plan thoughts/plans/review-execution-handoff.md --target skill:adn-dev-wf
```

Do not infer “the current plan” from conversation state.

### 2) Parse Optional Target Override and Normalize the Reviewed Plan Reference

1. Set `RAW_ARGUMENTS` to `$ARGUMENTS` after trimming whitespace.
2. If `RAW_ARGUMENTS` ends with `--target <value>`, split it into:
   - `PLAN_ARGUMENT` = everything before the final `--target`
   - `TARGET_OVERRIDE_RAW` = the trailing `<value>`
3. Otherwise set `PLAN_ARGUMENT=RAW_ARGUMENTS` and leave `TARGET_OVERRIDE` unset.
4. Normalize `TARGET_OVERRIDE_RAW` only if present:
   - Trim whitespace.
   - Strip one leading `/` if present.
   - Accept only `skill:adn-dev-wf` or `dev:run`.
   - If any other target is provided, stop and tell the user the only valid targets are `/skill:adn-dev-wf` and `/dev:run`.
5. If `PLAN_ARGUMENT` is empty after trimming, show the usage block and stop.
6. If `PLAN_ARGUMENT` starts with `@`, strip the leading `@`.
7. Preserve that normalized string as `PLAN_DISPATCH_ARGUMENT`.
8. Resolve `PLAN_PATH` for validation only:
   - If `PLAN_DISPATCH_ARGUMENT` is an existing `.md` file path, use it as `PLAN_PATH`.
   - Otherwise treat it as a slug and resolve `PLAN_PATH=thoughts/plans/<slug>.md`.
9. Read `PLAN_PATH` to confirm the reviewed plan exists.
10. If `PLAN_PATH` does not exist, stop and tell the user that `/cmd:execute-plan` requires an explicit existing reviewed plan file or slug.

Do not rewrite a slug into a path for dispatch. Forward the same normalized `PLAN_DISPATCH_ARGUMENT` that the user supplied.

### 3) Validate Handoff Readiness

Inspect `PLAN_PATH` for obvious blockers before offering execution.

Stop and tell the user what to fix first if any of these are true:

- unresolved inline review comments remain (for example `[REVIEW:...]`),
- the plan declares `Status: research-ready` or another explicitly non-ready state,
- `## Progress` is missing,
- `Resume Instructions (Agent)` is missing,
- an active phase is missing `### Tests first`, `### End State`, `### Work`, or `### Verify`,
- unresolved `Open Questions`, `Decision Points`, or equivalent unresolved-decision sections remain in a plan that is otherwise being handed to execution.

This validation is intentionally lightweight: it should catch obvious handoff mistakes, not perform a second full review.

### 4) Choose the Target Command

Determine `TARGET_COMMAND`:

- If `TARGET_OVERRIDE` is set, honor it without asking a follow-up question.
- Otherwise ask exactly one targeted question with only these two options:
  1. `/skill:adn-dev-wf <PLAN_DISPATCH_ARGUMENT>` — canonical reviewed-plan continuation that can resume from this reviewed plan.
  2. `/dev:run <PLAN_DISPATCH_ARGUMENT>` — direct execution-only path with one `quality-reviewer` pass after each phase.

Do not offer a planning pass here. Do not offer a third option.

### 5) Dispatch

Run exactly one of the following and then stop:

```text
/skill:adn-dev-wf <PLAN_DISPATCH_ARGUMENT>
```

```text
/dev:run <PLAN_DISPATCH_ARGUMENT>
```
