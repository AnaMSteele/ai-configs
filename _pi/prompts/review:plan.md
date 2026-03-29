---
description: Run comprehensive multi-model plan review using GPT5.4, Kimi K2.5, and Opus 4.6
argument-hint: '<path to plan.md | plan slug | legacy: <spec> <tasks> | legacy: <directory containing spec.md and tasks.md>'
---

# Multi-Model Plan Review Process

This command orchestrates a comprehensive plan review using three independent reviewers running in parallel, followed by a final synthesis review.

Documents to review: $ARGUMENTS

## Execution Mode

- Run three parallel reviews by delegating to the `subagent` tool in parallel mode with three separate review tasks.
- Each subagent runs independently without seeing the others' work.
- After all three complete, run a final synthesis review using a dedicated GPT5.4 synthesis subagent on high reasoning.
- Do not perform any reviews directly in the primary agent.

## Phase 1: Parallel Review (3 Subagents)

Launch three independent reviews simultaneously using the subagent tool.

### Subagent 1: GPT5.4 Review
- **Agent:** `reviewer-plan-gpt5.4`
- **Model:** `openai-codex/gpt-5.4`
- **Reasoning:** High
- **Task:** Perform comprehensive plan review per reviewer-plan-gpt5.4 instructions
- **Output:** Plan file with `[REVIEW:GPT5.4]` comments + summary

### Subagent 2: Kimi K2.5 Review
- **Agent:** `reviewer-plan-kimi`
- **Model:** `opencode-zen/kimi-k2.5`
- **Reasoning:** High
- **Task:** Perform comprehensive plan review per reviewer-plan-kimi instructions
- **Output:** Plan file with `[REVIEW:Kimi K2.5]` comments + summary

### Subagent 3: Opus 4.6 Review
- **Agent:** `reviewer-plan-opus`
- **Model:** `opencode-zen/claude-opus-4-6`
- **Reasoning:** High
- **Task:** Perform comprehensive plan review per reviewer-plan-opus instructions
- **Output:** Plan file with `[REVIEW:Opus 4.6]` comments + summary

### Parallel Execution

Launch one `subagent` call in parallel mode so pi actually runs the three reviewers concurrently.

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
    },
    {
      agent: "reviewer-plan-opus",
      task: "Review the plan at $ARGUMENTS. Follow your reviewer-plan-opus instructions exactly. Add [REVIEW:Opus 4.6] comments to the plan file and provide a summary."
    }
  ],
  context: "fresh"
})
```

Wait for the parallel `subagent` call to return all three review results before proceeding to Phase 2.

## Phase 2: Synthesis Review (Final)

After receiving all three review outputs:

### Final Reviewer: GPT5.4 Synthesis
- **Agent:** `reviewer-plan-synthesis`
- **Model:** `openai-codex/gpt-5.4`
- **Reasoning:** High
- **Task:** 
  1. Read the original plan
  2. Review all comments from GPT5.4, Kimi K2.5, and Opus 4.6
  3. Identify conflicts or agreements between reviewers
  4. Add synthesis comments using `[REVIEW:Synthesis]` format
  5. Provide final consolidated summary

The synthesis should:
- Highlight areas where all reviewers agree (high confidence issues)
- Flag areas where reviewers disagree (requires human judgment)
- Identify any gaps that only one reviewer caught
- Provide a final recommendation considering all perspectives

### Synthesis Execution

Launch the synthesis review using the dedicated synthesis subagent:

```javascript
subagent({
  agent: "reviewer-plan-synthesis",
  task: "Synthesize the existing GPT5.4, Kimi K2.5, and Opus 4.6 review comments already present in the plan at $ARGUMENTS. Add [REVIEW:Synthesis] comments and provide a final consolidated summary."
})
```
## Review Integration Output

All four sets of comments (GPT5.4, Kimi K2.5, Opus 4.6, and Synthesis) will be present in the plan file.

## Summary Format

After completing all reviews, provide:

```
## Multi-Model Review Complete

### Reviewers:
- ✅ GPT5.4 (openai-codex/gpt-5.4, high reasoning)
- ✅ Kimi K2.5 (opencode-zen/hf:moonshotai/Kimi-K2.5, high reasoning)
- ✅ Opus 4.6 (opencode-zen/claude-opus-4-6, high reasoning)
- ✅ Synthesis (openai-codex/gpt-5.4, high reasoning)

### Consensus Areas:
[List issues all reviewers flagged]

### Divergent Views:
[List areas where reviewers disagreed]

### Unique Insights:
[List issues only one reviewer caught]

### Final Recommendation:
[Major revision needed / Proceed with caution / Ready to execute]
```

## Scope (Review Phases 1-2 Only)

Phases 1 and 2 are review-only.

- Subagents only modify the plan by inserting inline `[REVIEW:...] ... [/REVIEW]` comments.
- Do not change any other plan content during review phases.
- Phase 3 performs automatic integration (see below).

### Phase 3: Automatic Integration

Phase 3 is NOT review-only. It:

- Reads all review comments from Phases 1-2
- Applies edits directly to the plan
- Removes resolved inline review comments
- Updates all relevant plan sections
- Validates the final plan structure

The output of this command is a clean, integrated plan ready for execution.

## Phase 3: Auto-Integration

After synthesis is complete, automatically integrate all review comments into the plan.

### Integration Process

#### 3.0) Read Plan and Extract Comments
- Read the plan file with all review comments
- Extract all inline review tags: `[REVIEW:GPT5.4]`, `[REVIEW:Kimi K2.5]`, `[REVIEW:Opus 4.6]`, `[REVIEW:Synthesis]`
- If no review comments exist, integration is already complete

#### 3.1) Explore Codebase for Context
For any feedback that depends on feasibility or existing patterns, explore the codebase to resolve it.
Use the `subagent` tool with a codebase exploration agent:

```javascript
subagent({
  agent: "explore",
  task: "Explore the codebase to understand [specific patterns/feasibility concern from review feedback]. Focus on [specific area]. Report findings including file paths, existing patterns, and any constraints that would affect plan implementation."
})
```

#### 3.2) Apply Integration Edits
Apply edits directly to the plan based on all review feedback:

- Remove each resolved inline review comment after addressing it
- If feedback implies adding or changing requirements, update:
  - Locked Decisions
  - Goal/Non-goals / Acceptance Criteria
  - `## Progress` if phase structure changes
  - The impacted phase(s) `### End State` / `### Work` / `### Verify`
  - `### Tests first` sections so they still describe the intended user-visible behavior
  - `Resume Instructions (Agent)` if needed
- If review feedback establishes that a dependency/library evaluation checkpoint was missing or under-specified, preserve or add that decision explicitly in the cleaned plan.
- If a review comment shows that custom implementation was proposed without adequate library research, integrate the requirement to evaluate official SDKs / well-maintained libraries.
- Append a new entry to `## Plan Changelog` describing what changed due to review integration.

#### 3.3) Resolve Open Questions
- Resolve every important question before considering integration complete
- If the codebase, existing specs, product-intent docs, or plan context answer a question with high confidence, answer it directly in the plan
- If a question cannot be answered with high confidence, ask the user with the `question` tool
- Incorporate the user's answer into the plan and re-check the whole document for any downstream phase updates needed
- Do not leave an `Open Questions` section or any unresolved-decision placeholder in the final plan
- If review established that non-trivial build-vs-buy work needs a dependency/library evaluation checkpoint, the final plan is not complete until that decision is documented

#### 3.4) Final Validation
- No `[REVIEW:...]` comments remain in the plan
- `## Progress` still corresponds to the phase headers
- Each acceptance criterion has at least one verification step
- Each phase has `### End State`, `### Tests first`, `### Work`, and `### Verify`
- The plan has `Resume Instructions (Agent)` and `## Decisions / Deviations Log`
- Required dependency/library evaluation decisions established during review remain present in the final clean plan
- The plan does not leave unresolved `Open Questions`, `Decision Points`, or equivalent unresolved-decision sections

#### 3.5) Integration Summary
After integration completes, provide:

```
## Integration Complete

### Changes Made:
- [List of changes made based on review feedback]

### Review Comments Addressed:
- ✅ GPT5.4 comments integrated
- ✅ Kimi K2.5 comments integrated
- ✅ Opus 4.6 comments integrated
- ✅ Synthesis comments integrated

### Open Questions Resolved:
- [List any questions answered during integration]

### Final State:
- Plan is clean with no review comments
- All required sections present and valid
- Plan changelog updated

### Next Step:
```
`/cmd:execute-plan <plan path | plan slug>`
```
```

---

## Updated Scope (Review + Integration)

This command now performs both review AND integration:

- Phase 1-2: Review-only (subagents insert `[REVIEW:...]` comments)
- Phase 3: Integration (apply feedback and remove all review comments)
- The final output is a clean, updated plan ready for execution

## Execution Flow Summary

```
Input Plan
    ↓
Phase 1: Parallel Reviews (3 subagents)
  ├─ GPT5.4 Review → [REVIEW:GPT5.4] comments
  ├─ Kimi K2.5 Review → [REVIEW:Kimi K2.5] comments
  └─ Opus 4.6 Review → [REVIEW:Opus 4.6] comments
    ↓
Phase 2: Synthesis (GPT5.4)
  └─ Consolidates all feedback → [REVIEW:Synthesis] comments
    ↓
Phase 3: Auto-Integration
  └─ Applies all feedback → Clean updated plan
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
3. **Wait for parallel completion** - all 3 reviewers + synthesis must complete
4. **Respect the synthesis** - the final GPT5.4 synthesis represents the consolidated expert opinion

### Process Flow:

```
User: "Review this plan"
Agent: Delegate to /review:plan <plan-path>
  → Task launches 3 parallel reviewers
  → Each adds [REVIEW:Name] comments
  → Synthesis reviewer consolidates all feedback
  → Returns comprehensive multi-model assessment
```

### Benefits:

- **Multiple perspectives:** Three different model architectures catch different issue types
- **High reasoning mode:** All reviewers use maximum reasoning effort
- **Parallel efficiency:** Reviews run simultaneously for faster turnaround
- **Synthesis quality:** Final GPT5.4 review consolidates all perspectives
- **Consistency:** Standardized review format and process across all plans

### Do NOT:

- Run single-reviewer reviews for plans
- Skip the synthesis phase
- Use lower reasoning settings to save time
- Manually review plans without delegating to this command
