# OpenCode `review:plan` Wrapper

**Last Updated:** 2026-04-06
**Status:** ✅ Implemented

## Overview

OpenCode now has a first-class `review:plan` command at `_opencode/commands/review:plan.md`. The command adds an explicit reviewed-plan entrypoint without replacing the stricter existing single-reviewer review surfaces.

The shipped implementation is an OpenCode-native wrapper around the existing GPT and Kimi review contracts. It resolves the plan path once, launches both reviewer legs in parallel with `Task`, waits for both to finish, then returns a combined review-only summary without running `/review:change-integrate`.

## Command Contract

Implemented in `_opencode/commands/review:plan.md`.

Supported inputs match the existing OpenCode review commands:
- a single plan file such as `thoughts/plans/<slug>.md`
- a workspace-relative path prefixed with `@`
- a plan slug resolved to `thoughts/plans/<slug>.md`
- a legacy bundle that can be migrated into a single-file plan

The wrapper contract is:
- review-only
- normalize the reviewed `plan_path` once
- launch `reviewer-gpt` and `reviewer-kimi` before waiting on either
- preserve inline `[REVIEW:...]` comments in the reviewed plan
- stop after a combined summary
- do not auto-run `/review:change-integrate`
- do not add fallback reviewers when one reviewer leg fails

## Data Flow

1. Parse `$ARGUMENTS` and resolve a single normalized `plan_path`.
2. Launch a GPT review task using the existing `_opencode/commands/review:change-gpt.md` contract.
3. Launch a Kimi review task using the existing `_opencode/commands/review:change-k2.5.md` contract.
4. Wait for both task results before generating a wrapper-level summary.
5. Leave inline review comments in the plan file for later optional `/review:change-integrate` work.

## Behaviors

- `review:plan` is now a discoverable OpenCode command instead of requiring users to know the `review:change*` family.
- The wrapper reuses existing OpenCode reviewer agents rather than introducing Pi-specific `reviewer-plan-*` agents.
- The wrapper preserves OpenCode's provider/model configuration by depending on `reviewer-gpt` and `reviewer-kimi`.
- The wrapper reports partial failure explicitly if one review leg cannot start or complete.

## Constraints

- The wrapper is intentionally review-only and never performs integration cleanup itself.
- It does not implement adversarial review, PRD review parity, execution-routing parity, Kimi naming aliases, or Pi interactive review transports.
- Runtime command availability depends on the installed OpenCode config under `~/.config/opencode/commands`; editing `_opencode/commands/` alone does not refresh the live OpenCode command registry.
- Full two-reviewer completion depends on reviewer provider availability. In the 2026-04-06 verification run, GPT completed but the Kimi leg failed with `ProviderModelNotFoundError`.

## Dependencies

The wrapper depends on these existing review surfaces:
- `_opencode/commands/review:change-gpt.md`
- `_opencode/commands/review:change-k2.5.md`
- `_opencode/agents/reviewer-gpt.md`
- `_opencode/agents/reviewer-kimi.md`

It also depends on `install.sh` copying `_opencode/commands/` into `~/.config/opencode/commands` for the live CLI runtime.

## Testing

Verified on 2026-04-06 with:
- `ls _opencode/commands/review:plan.md _opencode/commands/review:change-gpt.md _opencode/commands/review:change-k2.5.md _opencode/agents/reviewer-gpt.md _opencode/agents/reviewer-kimi.md`
- `opencode run --command "review:plan" "<disposable plan path>"`

Observed verification results:
- the wrapper resolved a single normalized plan path
- the wrapper launched both reviewer legs before waiting
- the GPT leg inserted inline review comments into the plan file
- the wrapper stopped before `/review:change-integrate`
- the Kimi leg failed at runtime with `ProviderModelNotFoundError`, so the wrapper summary reported an explicit failed leg instead of falling back to another reviewer

## Integration Points

- `_opencode/commands/review:plan.md`
- `_opencode/commands/review:change-gpt.md`
- `_opencode/commands/review:change-k2.5.md`
- `_opencode/agents/reviewer-gpt.md`
- `_opencode/agents/reviewer-kimi.md`
- `install.sh`

## Implementation Notes

- The final implementation deliberately does not copy `_pi/prompts/review:plan.md` literally.
- Pi-specific reviewer agent names, Pi model/provider strings, PRD review infrastructure, adversarial review infrastructure, and `interactive_shell` review transport assumptions remain out of scope.
- The original working plan was `thoughts/plans/pi-opencode-command-parity-review.md` and is preserved in git history after graduation cleanup.
