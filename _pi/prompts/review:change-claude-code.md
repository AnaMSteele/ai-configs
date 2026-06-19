---
description: Deprecated alias; use Pi quality-reviewer-glm instead of Claude Code for review-only change review
argument-hint: '<plan path | diff scope | review prompt>'
agent: quality-reviewer-glm
subtask: true
model: ollama/glm-5.2:cloud
thinking: xhigh
---

# Deprecated Claude Review Alias

Do not launch Claude Code for this command. Standard Pi plan, implementation, and PR review gates now use Pi subagents only:

- `quality-reviewer` for the GPT-5.5 reviewer leg
- `quality-reviewer-glm` for the GLM-5.2 reviewer leg, replacing the former Claude Code leg

This command runs inside the Pi `quality-reviewer-glm` subagent. Review `$ARGUMENTS` instead of using any Claude transport. Do not use `claude-code-review`, `claude`, `interactive_shell`, tmux launchers, prompt piping, or any external reviewer fallback.

Use this reviewer prompt shape:

```text
Read-only review. Do not edit files.

Scope: $ARGUMENTS

Review for blocker-level or readiness-changing issues only: correctness, data loss, security, performance, concurrency, resource cleanup, plan/implementation mismatch, and verification gaps with measurable impact.

Return one verdict:
- VERDICT: PASS_NO_ISSUES
- VERDICT: FINDINGS_NEED_FIX
- VERDICT: BLOCKED_BY_QUESTION

For each finding include file/line when applicable, severity, evidence, and the smallest scoped fix.
```

Final output must state that the legacy Claude command was handled by `quality-reviewer-glm` and no external Claude process was launched.
