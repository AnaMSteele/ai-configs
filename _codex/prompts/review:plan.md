---
description: Run blocker-focused review-only plan review using GPT and Kimi K2.5 in parallel
argument-hint: '<existing-plan-path | plan slug | legacy: <spec> <tasks> | legacy: <directory containing spec.md and tasks.md>'
---

# Multi-Model Plan Review Process

This command orchestrates a blocker-focused review-only plan review using two independent reviewers in parallel: GPT and Kimi K2.5.

Documents to review: $ARGUMENTS

## Execution Mode

- Use the `Agent` tool surface directly: launch two background agents with `Agent`.
- Each reviewer runs independently without seeing the other's work.
- Both reviewers must be launched before waiting for completions.
- Review against the plan's stated goal, non-goals, original requested scope, and validated repo evidence; comment only on blockers, materially risky gaps, or missing decisions required to execute that scope.
- Do not use this command as a broad idea-generation pass or an excuse to expand the plan into adjacent nice-to-haves.
- Do not perform any reviews directly in the primary agent.
- Do not rely on a nonexistent `subagent(...)` runner or on slash-command chaining.
- This command is review-only. Do not integrate or clean up review comments here.
- Do not trigger or imply an automatic fallback to `/review:change-claude-code`; Claude Code review remains a separate explicit opt-in command.

## Phase 1: Parallel Review (2 Reviewers)

Launch both reviews before waiting for either of them to finish.

### Subagent 1: GPT Review
- **Agent:** `reviewer-plan-gpt5.5`
- **Model:** `openai-codex/gpt-5.5`
- **Reasoning:** High
- **Task:** Perform blocker-only plan review per reviewer-plan-gpt5.5 instructions
- **Output:** Plan file with `[REVIEW:GPT]` comments + summary

### Subagent 2: Kimi K2.5 Review
- **Agent:** `reviewer-plan-kimi`
- **Model:** `opencode/kimi-k2.5`
- **Reasoning:** High
- **Task:** Perform blocker-only plan review per reviewer-plan-kimi instructions
- **Output:** Plan file with `[REVIEW:Kimi K2.5]` comments + summary

### Parallel Execution

Launch two background `Agent` calls so both reviewers actually run concurrently.

```javascript
const gpt54 = Agent({
  subagent_type: "reviewer-plan-gpt5.5",
  description: "Review plan with GPT",
  prompt: "Review the plan at $ARGUMENTS. Follow your reviewer-plan-gpt5.5 instructions exactly. Add [REVIEW:GPT] comments only for blockers, materially risky gaps, or missing decisions required to execute the stated goal within the validated source scope, then provide a readiness summary.",
  run_in_background: true,
});

const kimi = Agent({
  subagent_type: "reviewer-plan-kimi",
  description: "Review plan with Kimi K2.5",
  prompt: "Review the plan at $ARGUMENTS. Follow your reviewer-plan-kimi instructions exactly. Add [REVIEW:Kimi K2.5] comments only for blockers, materially risky gaps, or missing decisions required to execute the stated goal within the validated source scope, then provide a readiness summary.",
  run_in_background: true,
});

get_subagent_result({ agent_id: gpt54.agent_id ?? gpt54.id, wait: true });
get_subagent_result({ agent_id: kimi.agent_id ?? kimi.id, wait: true });
```

Wait for both `get_subagent_result(..., wait: true)` calls to complete before producing any summary text.

## Review Output

The final plan file should be an annotated plan containing any `[REVIEW:...]` comments left by GPT and Kimi K2.5.

## Summary Format

After completing all reviews, provide:

```markdown
## Multi-Model Review Complete

### Reviewers:
- ✅ GPT (openai-codex/gpt-5.5, high reasoning)
- ✅ Kimi K2.5 (opencode/kimi-k2.5, high reasoning)

### Consensus Blockers:
[List issues multiple reviewers flagged that materially affect execution readiness]

### Divergent Material Risks:
[List any material disagreements between GPT and Kimi, if present]

### Unique Material Risks:
[List blocker-level or materially risky issues caught by only one reviewer]

### Final Readiness:
[Needs material revision before execution / Proceed with caution / Ready to execute]
```

## Scope

This command is review-only:

- Phase 1: GPT review-only pass
- Phase 1: Kimi K2.5 review-only pass
- The final output is an annotated plan with review comments left in place
- If the user wants integration afterward, run `/review:change-integrate <plan>`

## Execution Flow Summary

```text
Input Plan
    ↓
Phase 1: Parallel Reviews (2 reviewers)
  ├─ GPT Review → [REVIEW:GPT] comments
  ├─ Kimi K2.5 Review → [REVIEW:Kimi K2.5] comments
    ↓
Output: Annotated Plan (run /review:change-integrate before execution if you want comments resolved)
```
