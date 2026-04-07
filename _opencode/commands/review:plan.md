---
description: Run comprehensive review-only plan review using GPT5.4 and Kimi in parallel
argument-hint: '<path to plan.md | plan slug | legacy: <spec> <tasks> | legacy: <directory containing spec.md and tasks.md>'
---

# Multi-Model Plan Review (Single Plan File)

Review the provided change plan using the existing OpenCode GPT5.4 and Kimi reviewers in parallel.

Documents to review: $ARGUMENTS

## Scope (Review-Only; Do Not Integrate)

This command is review-only.

- Do not perform the review directly in the primary agent.
- Resolve the reviewed plan argument once, then pass the same normalized `plan_path` to both review legs.
- Launch both review legs before waiting for either result.
- Reuse only the existing OpenCode reviewer agents: `reviewer-gpt5.4` and `reviewer-kimi`.
- Keep inline `[REVIEW:...] ... [/REVIEW]` comments in place.
- Do not run follow-up commands (including `/review:change-integrate`).
- Do not introduce adversarial review, PRD review flows, Pi-only reviewer names, Pi-only tool-surface wording, or automatic Claude fallback behavior.
- After both review legs finish and you provide the wrapper summary, stop.

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

### 1) Normalize Once

- Compute `plan_path` exactly once using the rules above.
- Use that same normalized `plan_path` for both review legs.
- Do not ask each reviewer to reinterpret the original raw argument when the normalized `plan_path` is already known.

### 2) Launch Parallel Review Legs

Use the Task tool to launch both reviewers in parallel. Do not wait for the first task before launching the second.

#### Review leg 1: GPT5.4

```text
Task(
  subagent_type="reviewer-gpt5.4",
  description="Review plan with GPT5.4",
  prompt="""Review the single-file change plan at ${plan_path}.

For this run, your reviewer name is GPT5.4.
Use this comment format exactly:
[REVIEW:GPT5.4] Your critical feedback here [/REVIEW]

Reuse the existing OpenCode review contract from _opencode/commands/review:change-gpt5.4.md, with the plan path already resolved:
- Only modify the plan by inserting inline review comments.
- Do not change any other plan content.
- Do not remove or resolve review comments.
- Do not run follow-up commands, including /review:change-integrate.
- Explore the codebase for context when needed.
- Apply the same review focus, execution-readiness checks, and summary style as review:change-gpt5.4.
- After adding comments and returning the summary, stop."""
)
```

#### Review leg 2: Kimi

```text
Task(
  subagent_type="reviewer-kimi",
  description="Review plan with Kimi",
  prompt="""Review the single-file change plan at ${plan_path}.

For this run, your reviewer name is Kimi Reviewer.
Use this comment format exactly:
[REVIEW:Kimi Reviewer] Your critical feedback here [/REVIEW]

Reuse the existing OpenCode review contract from _opencode/commands/review:change-k2.5.md, with the plan path already resolved:
- Only modify the plan by inserting inline review comments.
- Do not change any other plan content.
- Do not remove or resolve review comments.
- Do not run follow-up commands, including /review:change-integrate.
- Explore the codebase for context when needed.
- Apply the same review focus, execution-readiness checks, and summary style as review:change-k2.5.
- After adding comments and returning the summary, stop."""
)
```

### 3) Wait For Both Review Legs

- Wait for both review tasks to finish before producing any wrapper summary.
- Preserve any inline review comments already added to the plan.
- Do not add a third reviewer or fallback reviewer if one leg fails; report the failing leg explicitly instead.

### 4) Provide Combined Summary And Stop

After both review legs finish, provide a combined review-only summary in this format:

```markdown
## Multi-Model Review Complete

### Reviewers
- GPT5.4: complete
- Kimi Reviewer: complete

### Consensus Areas
- [Issues both reviewers flagged]

### Divergent Views
- [Meaningful disagreements, if any]

### Unique Insights
- [Issues caught by only one reviewer]

### Final Recommendation
- [Major revision needed / Proceed with caution / Ready to execute]
```

Then stop. Inline review comments remain in the plan file for later `/review:change-integrate` work if the user asks for it.
