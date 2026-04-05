---
description: Start /dev:run or /ralph:run in a fresh session from a reviewed plan
argument-hint: '<plan slug | thoughts/plans/<slug>.md | path/to/plan.md> [--target dev:run|ralph:run]'
---

# Execute Reviewed Plan

This command is the reviewed-plan handoff for repo-managed OMP. It does not replace `/dev:run` or `/ralph:run`; it validates an explicit reviewed plan argument, optionally accepts a target override, asks the user which of those two commands to run when needed, and then starts the chosen execution path in a fresh session using the same normalized plan argument.

**Arguments**: `$ARGUMENTS`

## Contract

- Accept a plan slug or an explicit `.md` plan path.
- Accept workspace-relative input that starts with `@` by stripping the leading `@`.
- Accept an optional target suffix: `--target dev:run` or `--target ralph:run`.
- Present exactly two execution choices: `/dev:run` and `/ralph:run`.
- Preserve the same normalized plan argument when dispatching.
- Start execution outside `/aplan` planning context by opening a fresh session before dispatch.

## Instructions

### 1) Validate Input

If no argument is provided, respond with:

```text
Usage: /cmd:execute-plan <plan slug | thoughts/plans/<slug>.md | path/to/plan.md> [--target dev:run|ralph:run]

Examples:
  /cmd:execute-plan review-execution-handoff
  /cmd:execute-plan thoughts/plans/review-execution-handoff.md
  /cmd:execute-plan @thoughts/plans/review-execution-handoff.md
  /cmd:execute-plan thoughts/plans/review-execution-handoff.md --target dev:run
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
   - Accept only `dev:run` or `ralph:run`.
   - If any other target is provided, stop and tell the user the only valid targets are `/dev:run` and `/ralph:run`.
5. If `PLAN_ARGUMENT` is empty after trimming, show the usage block and stop.
6. If `PLAN_ARGUMENT` starts with `@`, strip the leading `@`.
7. Preserve that normalized string as `PLAN_DISPATCH_ARGUMENT`.
8. Resolve `PLAN_PATH` for validation only:
   - If `PLAN_DISPATCH_ARGUMENT` is an existing `.md` file path, use it as `PLAN_PATH`.
   - Otherwise treat it as a slug and resolve `PLAN_PATH=thoughts/plans/<slug>.md`.
9. Read `PLAN_PATH` to confirm the reviewed plan exists.
10. If `PLAN_PATH` does not exist, stop and tell the user that `/cmd:execute-plan` requires an explicit existing reviewed plan file or slug.

Do not rewrite a slug into a path for dispatch. Forward the same normalized `PLAN_DISPATCH_ARGUMENT` that the user supplied.

### 3) Choose the Target Command

Determine `TARGET_COMMAND`:

- If `TARGET_OVERRIDE` is set, honor it without asking a follow-up question.
- Otherwise ask exactly one targeted question with only these two options:
  1. `/ralph:run <PLAN_DISPATCH_ARGUMENT>` — quality-gated, review-loop execution for the reviewed plan.
  2. `/dev:run <PLAN_DISPATCH_ARGUMENT>` — direct single-agent execution with resumable plan progress tracking.

Do not offer a planning pass here. Do not offer a third option.

### 4) Dispatch in a Fresh Session

Open a fresh session, then run exactly one of the following and stop:

```text
/dev:run <PLAN_DISPATCH_ARGUMENT>
```

```text
/ralph:run <PLAN_DISPATCH_ARGUMENT>
```

This command is only the reviewed-plan handoff wrapper; `/dev:run` and `/ralph:run` remain distinct execution paths with different behaviors.

When the `_omp/extensions/aplan` runtime extension is installed, invoking `/cmd:execute-plan` from an `/aplan` workflow disables the planning companion state before that fresh-session handoff so execution does not inherit planning restrictions.
