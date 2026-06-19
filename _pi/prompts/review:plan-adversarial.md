---
description: Run adversarial second-pass plan review using Pi quality-reviewer subagents, then integrate findings
argument-hint: '<existing-plan-path | plan slug | legacy: <spec> <tasks> | legacy: <directory containing spec.md and tasks.md>'
---

# Adversarial Plan Review Process

This command runs a second-pass adversarial review after the normal `/review:plan` flow.

It uses **two read-only Pi subagents**:
- `quality-reviewer` — GPT-5.5 reviewer, replacing the former Codex review leg
- `quality-reviewer-glm` — GLM-5.2 reviewer with `thinking: xhigh`, replacing the former Claude Code review leg

Do not launch Claude Code, Codex CLI, `claude-code-review`, `codex-review-partner`, OMP, or any other external reviewer for this command.

Documents to review: $ARGUMENTS

## When to use this command

Use this after the standard `/review:plan` flow when you want an explicit challenge pass focused on:

- hidden weaknesses and incomplete exploration,
- product-intent drift,
- false-completion loopholes,
- under-specified retries, fail-closed boundaries, and shipped-path verification gaps.

## Reviewer Names and Comment Formats

GPT-5.5 reviewer name:
```text
GPT55
```

GPT-5.5 comment format:
```text
[REVIEW:GPT55] Your critical feedback here [/REVIEW]
```

GLM-5.2 reviewer name:
```text
GLM52
```

GLM-5.2 comment format:
```text
[REVIEW:GLM52] Your critical feedback here [/REVIEW]
```

## Phase 1: Parallel Pi Subagent Adversarial Reviews

Launch both subagents before waiting for either result.

### Shared adversarial review goals

Both reviewers should challenge the plan through these lenses:

1. hidden weaknesses and incomplete exploration,
2. product-intent drift,
3. insufficient detail for accurate execution,
4. false completion / loophole analysis,
5. boundary handling and fail-closed behavior,
6. recovery realism,
7. verification realism for the actual shipped/operator path.

Both reviewers must:

- review the plan as if it will be implemented literally,
- return copyable inline review comments only,
- avoid rewriting or integrating the plan,
- preserve plan structure and progress state,
- stop after a concise summary.

### Required adversarial reviewer prompt content

Each subagent prompt must:

- resolve the target plan path,
- review the plan as if it will be implemented literally,
- return inline review comments only,
- use the reviewer-specific comment tag,
- not rewrite, integrate, remove comments, or edit files,
- preserve plan structure and progress state,
- stop after a concise summary.

Both adversarial prompts must explicitly challenge the plan for:

- hidden weaknesses,
- product-intent drift,
- ambiguity that would allow the wrong implementation,
- false-positive verify steps,
- missing fail-closed behavior,
- incomplete recovery guidance,
- and places where the plan could ship green while the real outcome is still wrong.

## Phase 2: Integration

After both reviewers complete, integrate the review feedback into the plan.

### Integration requirements

- Read the plan and the returned `[REVIEW:GPT55]` and `[REVIEW:GLM52]` comments from both subagent outputs.
- Apply edits directly to the plan based on the feedback.
- Remove resolved review comments.
- Update affected sections such as Locked Decisions, Acceptance Criteria, BDD scenarios, phase work, verify steps, resume instructions, and changelog.
- Resolve important open questions before finishing integration.
- Validate that no `[REVIEW:...]` comments remain and that the plan still satisfies the repo’s canonical plan structure.

## Summary Format

After review and integration, provide:

```text
## Adversarial Review Complete

### Reviewers:
- ✅ GPT-5.5 quality-reviewer
- ✅ GLM-5.2 quality-reviewer-glm (`thinking: xhigh`)

### Highest-risk issues:
[List the most important issues found]

### Divergent views:
[List any meaningful differences between GPT-5.5 and GLM-5.2]

### Changes integrated:
[List the important plan changes made]

### Recommendation:
[Major revision needed / Proceed with caution / Ready to execute]
```

## Intended workflow

Typical flow:

1. `/review:plan <plan>`
2. `/review:plan-adversarial <plan>`
3. `/cmd:execute-plan <plan>`
