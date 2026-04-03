---
description: Run comprehensive plan review using GPT5.4, Kimi K2.5, and Claude Code
argument-hint: '<path to plan.md | plan slug | legacy: <spec> <tasks> | legacy: <directory containing spec.md and tasks.md>'
---

# Multi-Model Plan Review Process

This command orchestrates a comprehensive plan review using two independent reviewers in parallel, followed by a Claude Code review-and-integration pass.

Documents to review: $ARGUMENTS

## Execution Mode

- Run two parallel reviews by delegating to the `subagent` tool in parallel mode with two separate review tasks.
- Each subagent runs independently without seeing the other's work.
- After both complete, run the Claude Code review-and-integration pass directly through the `review:change-claude-code` workflow.
- Do not perform any reviews directly in the primary agent.

## Phase 1: Parallel Review (2 Subagents)

Launch two independent reviews simultaneously using the subagent tool.

### Subagent 1: GPT5.4 Review
- **Agent:** `reviewer-plan-gpt5.4`
- **Model:** `openai-codex/gpt-5.4`
- **Reasoning:** High
- **Task:** Perform comprehensive plan review per reviewer-plan-gpt5.4 instructions
- **Output:** Plan file with `[REVIEW:GPT5.4]` comments + summary

### Subagent 2: Kimi K2.5 Review
- **Agent:** `reviewer-plan-kimi`
- **Model:** `opencode/kimi-k2.5`
- **Reasoning:** High
- **Task:** Perform comprehensive plan review per reviewer-plan-kimi instructions
- **Output:** Plan file with `[REVIEW:Kimi K2.5]` comments + summary

### Parallel Execution

Launch one `subagent` call in parallel mode so pi actually runs the two reviewers concurrently.

```javascript
subagent({
  tasks: [
    {
      agent: "reviewer-plan-gpt5.4",
      task: "Review the plan at $ARGUMENTS. Follow your reviewer-plan-gpt5.4 instructions exactly. Add [REVIEW:GPT5.4] comments to the plan file and provide a summary."
    },
    {
      agent: "reviewer-plan-kimi",
      task: "Review the plan at $ARGUMENTS. Follow your reviewer-plan-kimi instructions exactly. Add [REVIEW:Kimi K2.5] comments to the plan file and provide a summary."
    }
  ],
  context: "fresh"
})
```

Wait for the parallel `subagent` call to return both review results before proceeding to Phase 2.

## Phase 2: Claude Code Review and Integration

After receiving both review outputs, run the direct Claude Code review workflow to apply the final pass and integrate accepted feedback into the same plan file.

### Claude Code Pass
- **Command:** `/review:change-claude-code`
- **Purpose:** Review the plan with Claude Code directly, then integrate the accepted feedback into the same file.
- **Task:** Run the new direct Claude Code review workflow against the target plan file after the two parallel reviewer passes complete.

### Claude Code Execution

Run the direct Claude Code review command against the same plan file:

```text
/review:change-claude-code $ARGUMENTS
```

## Review Integration Output

The final plan file will reflect the GPT5.4 and Kimi feedback after the Claude Code integration pass. No Opus review path remains in this command.

## Summary Format

After completing all reviews, provide:

```markdown
## Multi-Model Review Complete

### Reviewers:
- ✅ GPT5.4 (openai-codex/gpt-5.4, high reasoning)
- ✅ Kimi K2.5 (opencode/kimi-k2.5, high reasoning)
- ✅ Claude Code (direct integration via pi-processes)

### Consensus Areas:
[List issues GPT5.4 and Kimi both flagged before Claude Code integration]

### Divergent Views:
[List any disagreements between GPT5.4 and Kimi, if present]

### Unique Insights:
[List issues caught by only one of the parallel reviewers]

### Final Recommendation:
[Major revision needed / Proceed with caution / Ready to execute]
```

## Scope

This command performs review and integration in sequence:

- Phase 1: Review-only (parallel subagents insert `[REVIEW:...]` comments)
- Phase 2: Claude Code review-and-integration (direct pass cleans up the plan)
- The final output is a clean, updated plan ready for execution

## Execution Flow Summary

```text
Input Plan
    ↓
Phase 1: Parallel Reviews (2 subagents)
  ├─ GPT5.4 Review → [REVIEW:GPT5.4] comments
  └─ Kimi K2.5 Review → [REVIEW:Kimi K2.5] comments
    ↓
Phase 2: Claude Code Review + Integration
  └─ Direct Claude Code pass → integrated plan
    ↓
Output: Integrated Plan (ready for /cmd:execute-plan or direct /dev:run or /ralph:run)
```

---

## Oh My Pi Integration Instructions

### For ALL Plan Reviews in Oh My Pi:

**This `/review:plan` command MUST be used as the standard review process for ALL plans.**

Whenever a plan is created or updated and needs review:

1. **Primary agent MUST delegate to this command** instead of performing direct review
2. **Always use the full multi-model review** - do not skip reviewers or use single-reviewer shortcuts
3. **Wait for parallel completion** - both reviewer passes must complete before the Claude Code pass
4. **Respect the Claude Code integration pass** - the final integrated plan is the consolidated expert output

### Process Flow:

```text
User: "Review this plan"
Agent: Delegate to /review:plan <plan-path>
  → Task launches 2 parallel reviewers
  → Each adds [REVIEW:Name] comments
  → Claude Code integration pass resolves feedback
  → Returns a clean integrated plan
```

### Benefits:

- **Multiple perspectives:** Two different model architectures catch different issue types
- **High reasoning mode:** Both reviewers use maximum reasoning effort
- **Parallel efficiency:** Reviews run simultaneously for faster turnaround
- **Direct integration:** Claude Code resolves feedback into the plan itself
- **Consistency:** Standardized review format and process across all plans

### Do NOT:

- Run single-reviewer reviews for plans
- Skip the Claude Code integration phase
- Use lower reasoning settings to save time
- Manually review plans without delegating to this command
