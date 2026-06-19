---
description: Run blocker-focused review-only plan review using Pi quality-reviewer subagents
argument-hint: '<existing-plan-path | plan slug | legacy: <spec> <tasks> | legacy: <directory containing spec.md and tasks.md>'
---

# Pi Quality-Reviewer Plan Review Process

This command orchestrates a blocker-focused review-only plan review using two independent Pi quality-reviewer subagents:

- `quality-reviewer` — GPT-5.5 reviewer, replacing the former Codex/GPT reviewer path
- `quality-reviewer-glm` — GLM-5.2 reviewer with `thinking: xhigh`, replacing the former Claude reviewer path

Documents to review: $ARGUMENTS

HTML plans are first-class inputs. If the argument is a slug, resolve it through repo-local active plan guidance; in this repo's browser-reviewed flow that means `thoughts/plans/<slug>.html`, not a Markdown fallback.

## Execution Mode

- Use the actual Pi subagent tool surface: launch two background agents with `Agent`.
- Each reviewer runs independently without seeing the other's work.
- Both reviewers must be launched before waiting for completions.
- Review against the plan's stated goal, non-goals, original requested scope, and validated repo evidence; comment only on blockers, materially risky gaps, or missing decisions required to execute that scope.
- Do not use this command as a broad idea-generation pass or an excuse to expand the plan into adjacent nice-to-haves.
- Do not perform any reviews directly in the primary agent.
- Do not rely on a nonexistent `subagent(...)` runner or on slash-command chaining.
- Do not launch Claude Code, Codex CLI, `claude-code-review`, `codex-review-partner`, OMP, or any other external reviewer.
- This command is review-only. Do not integrate or clean up review comments here.

## Phase 1: Parallel Review

Launch both reviews before waiting for either of them to finish.

### Subagent 1: GPT-5.5 Quality Review
- **Agent:** `quality-reviewer`
- **Model:** `openai-codex/gpt-5.5`
- **Task:** Perform blocker-only plan review using the prompt below.
- **Output:** Copyable `[REVIEW:GPT55]` comments + summary. The primary agent inserts accepted comments into the same plan file after both reviewers return.

### Subagent 2: GLM-5.2 Quality Review
- **Agent:** `quality-reviewer-glm`
- **Model:** `ollama/glm-5.2:cloud`
- **Thinking:** `xhigh`
- **Task:** Perform blocker-only plan review using the prompt below.
- **Output:** Copyable `[REVIEW:GLM52]` comments + summary. The primary agent inserts accepted comments into the same plan file after both reviewers return.

### Shared Reviewer Prompt

```text
Review the plan at $ARGUMENTS. Treat HTML plan files as first-class plan inputs and do not convert them to Markdown.

Do not edit files. Return copyable inline review comments only for blockers, materially risky gaps, or missing decisions required to execute the stated goal within the validated source scope.

Use your assigned tag only:
- GPT-5.5 reviewer: [REVIEW:GPT55] ... [/REVIEW]
- GLM-5.2 reviewer: [REVIEW:GLM52] ... [/REVIEW]

Check:
- goal and user-visible outcome are clear
- scope and non-goals are enforceable
- acceptance criteria are concrete
- BDD scenarios cover happy, edge, and failure paths
- phase work is ordered and bounded
- tests-first expectations are practical
- each phase has exact verification commands
- required web/native/API/CLI parity is explicit when relevant
- unresolved product decisions are not hidden in execution
- final verification is sufficient for touched surfaces

Return one verdict:
- VERDICT: PLAN_EXECUTION_READY
- VERDICT: PLAN_NEEDS_REVISION
- VERDICT: BLOCKED_BY_PRODUCT_QUESTION
```

### Parallel Execution

Launch two background `Agent` calls so Pi actually runs both reviewers concurrently.

```javascript
const gpt55 = Agent({
  subagent_type: "quality-reviewer",
  description: "Review plan with GPT-5.5",
  prompt: "Review the plan at $ARGUMENTS using the shared reviewer prompt in /review:plan. Use [REVIEW:GPT55] comments only.",
  run_in_background: true,
});

const glm52 = Agent({
  subagent_type: "quality-reviewer-glm",
  description: "Review plan with GLM-5.2",
  thinking: "xhigh",
  prompt: "Review the plan at $ARGUMENTS using the shared reviewer prompt in /review:plan. Use [REVIEW:GLM52] comments only.",
  run_in_background: true,
});

get_subagent_result({ agent_id: gpt55.agent_id ?? gpt55.id, wait: true });
get_subagent_result({ agent_id: glm52.agent_id ?? glm52.id, wait: true });
```

Wait for both `get_subagent_result(..., wait: true)` calls to complete before producing any summary text.

## Review Output

After both subagents return, the primary agent must insert any material returned `[REVIEW:GPT55]` and `[REVIEW:GLM52]` comments into the same plan file in its original format. For HTML plans, keep the document valid semantic HTML and insert comments visibly without converting the plan to Markdown.

## Summary Format

After completing all reviews, provide:

```markdown
## Pi Quality-Reviewer Plan Review Complete

### Reviewers:
- ✅ GPT-5.5 quality-reviewer
- ✅ GLM-5.2 quality-reviewer-glm (`thinking: xhigh`)

### Consensus Blockers:
[List issues multiple reviewers flagged that materially affect execution readiness]

### Divergent Material Risks:
[List any material disagreements between GPT-5.5 and GLM-5.2, if present]

### Unique Material Risks:
[List blocker-level or materially risky issues caught by only one reviewer]

### Final Readiness:
[Needs material revision before execution / Proceed with caution / Ready to execute]
```

## Scope

This command is review-only:

- Phase 1: GPT-5.5 quality-reviewer pass
- Phase 1: GLM-5.2 quality-reviewer-glm (`thinking: xhigh`) pass
- The final output is an annotated plan with material returned review comments inserted by the primary agent and left in place
- If the user wants integration afterward, run `/review:change-integrate <plan>`
