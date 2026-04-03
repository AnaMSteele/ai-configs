---
description: Run comprehensive plan review using GPT5.4, Kimi K2.5, and Claude Code via interactive-shell dispatch
argument-hint: '<path to plan.md | plan slug | legacy: <spec> <tasks> | legacy: <directory containing spec.md and tasks.md>'
---

# Multi-Model Plan Review Process

This command orchestrates a comprehensive plan review using two independent reviewers in parallel, followed by a single deterministic Claude Code review-and-integration pass.

Documents to review: $ARGUMENTS

## Execution Mode

- Use the actual Pi subagent tool surface: launch two background agents with `Agent`, then wait for both with `get_subagent_result`.
- Each reviewer runs independently without seeing the other's work.
- After both complete, run the Claude Code review-and-integration pass directly in this command via `interactive_shell`.
- After both `get_subagent_result(..., wait: true)` calls return, your very next steps must be the deterministic Claude launcher prep described below and then an `interactive_shell({ ... })` call that launches Claude Code. Do not stop after Phase 1.
- Do not perform any reviews directly in the primary agent.
- Do not rely on a nonexistent `subagent(...)` runner or on slash-command chaining for Phase 2.
- Do not use the `process` tool for the Claude phase.
- Launch exactly one Claude Code session for Phase 2 and treat that session as authoritative.
- Do not infer failure from silent stdout/stderr. Claude may stay quiet until completion.
- Do not launch a second Claude Code session unless the first session has already exited non-zero and you are explicitly retrying after reporting that failure cause.

## Phase 1: Parallel Review (2 Subagents)

Launch two independent reviews simultaneously using the `Agent` tool.

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

Launch two background `Agent` calls so Pi actually runs the reviewers concurrently.

```javascript
const gpt54 = Agent({
  subagent_type: "reviewer-plan-gpt5.4",
  description: "Review plan with GPT5.4",
  prompt: "Review the plan at $ARGUMENTS. Follow your reviewer-plan-gpt5.4 instructions exactly. Add [REVIEW:GPT5.4] comments to the plan file and provide a summary.",
  run_in_background: true,
});

const kimi = Agent({
  subagent_type: "reviewer-plan-kimi",
  description: "Review plan with Kimi K2.5",
  prompt: "Review the plan at $ARGUMENTS. Follow your reviewer-plan-kimi instructions exactly. Add [REVIEW:Kimi K2.5] comments to the plan file and provide a summary.",
  run_in_background: true,
});

get_subagent_result({ agent_id: gpt54.agent_id ?? gpt54.id, wait: true });
get_subagent_result({ agent_id: kimi.agent_id ?? kimi.id, wait: true });

// Equivalent alternative: launch both first, then wait for both results.
// Do not serialize the launches.
```

Wait for both `get_subagent_result(..., wait: true)` calls to complete before proceeding to Phase 2. Once they return, immediately launch Claude Code before producing any summary text.

## Phase 2: Claude Code Review and Integration

After receiving both review outputs, run Claude Code directly from this command to apply the final pass and integrate accepted feedback into the same plan file.

### Claude Code Pass
- **Tool:** `interactive_shell`
- **Purpose:** Review the plan with Claude Code directly, then integrate the accepted feedback into the same file.
- **Task:** Start exactly one Claude Code interactive-shell session against the target plan file after the two parallel reviewer passes complete.
- **Shell requirement:** launch Claude Code through a login shell so user-local PATH entries such as `~/.local/bin/claude` are available on macOS and similar setups.
- **Mode requirement:** use `mode: "dispatch"` so Pi tracks the session lifecycle and wakes the agent on completion instead of forcing the agent to guess from log silence.
- **Prompt transport requirement:** do not inline the full Claude review prompt directly inside shell quotes. Instead, write the prompt body to `/tmp/pi-claude-review-prompt.txt`, write the exact Python wrapper below to `/tmp/pi-claude-review-wrapper.py`, and launch that wrapper through `interactive_shell`.

### Claude Code Execution

Use the same direct review-and-integrate behavior as `/review:change-claude-code`, but perform it here with `interactive_shell` rather than by invoking another slash command.

Example shape:

```javascript
exec_command({
  cmd: `cat > /tmp/pi-claude-review-prompt.txt <<'EOF'
<review-and-integrate prompt for $ARGUMENTS>
EOF
cat > /tmp/pi-claude-review-wrapper.py <<'PY'
import os
import subprocess
import sys

repo = sys.argv[1]
prompt_path = sys.argv[2]
with open(prompt_path, 'r', encoding='utf-8') as fh:
    prompt = fh.read()

cmd = [
    'claude',
    '-p',
    '--output-format', 'json',
    '--permission-mode', 'bypassPermissions',
    '--add-dir', repo,
    '--effort', 'high',
    prompt,
]

completed = subprocess.run(cmd, cwd=repo, stdin=subprocess.DEVNULL)
sys.exit(completed.returncode)
PY`,
})

interactive_shell({
  command: `zsh -lic 'export PATH="$HOME/.local/bin:$PATH"; cd "$PWD" || exit 1; command -v claude >/dev/null 2>&1 || { echo "claude_not_found" >&2; exit 127; }; exec python3 /tmp/pi-claude-review-wrapper.py "$PWD" /tmp/pi-claude-review-prompt.txt'`,
  mode: "dispatch",
  reason: "Claude Code plan review + integration",
});
```

Execution rules:

- Launch one session.
- Do not start a second Claude Code session while the first dispatch session is still running.
- Wait for the automatic completion turn from `interactive_shell`.
- Only if that session exits non-zero may you inspect the failure and decide whether one explicit retry is justified.
- Do not invent alternate quoting strategies or new launcher shapes mid-run. The prompt-file + Python-wrapper transport above is the required transport.
- Keep the option order exactly as shown so the final prompt string is not swallowed by Claude's variadic `--add-dir` parsing.

Then read the resulting plan file and verify that no unresolved `[REVIEW:...]` comments remain.

Failure condition: if the command returns before an `interactive_shell` call launches Claude Code, the review is incomplete and must not be treated as successful.

## Review Integration Output

The final plan file will reflect the GPT5.4 and Kimi feedback after the Claude Code integration pass. No Opus review path remains in this command.

## Summary Format

After completing all reviews, provide:

```markdown
## Multi-Model Review Complete

### Reviewers:
- ✅ GPT5.4 (openai-codex/gpt-5.4, high reasoning)
- ✅ Kimi K2.5 (opencode/kimi-k2.5, high reasoning)
- ✅ Claude Code (direct integration via pi-interactive-shell dispatch)

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
- Phase 2: Claude Code review-and-integration (single dispatch session cleans up the plan)
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
  └─ Single Claude Code dispatch session → integrated plan
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
5. **Do not make the running agent invent fallback launcher logic** - this prompt must already specify the exact Claude launch path and lifecycle handling

### Process Flow:

```text
User: "Review this plan"
Agent: Delegate to /review:plan <plan-path>
  → Agent launches 2 parallel reviewers with the Agent tool
  → Each adds [REVIEW:Name] comments
  → Claude Code integration pass runs through interactive-shell dispatch and resolves feedback
  → Returns a clean integrated plan
```

### Benefits:

- **Multiple perspectives:** Two different model architectures catch different issue types
- **High reasoning mode:** Both reviewers use maximum reasoning effort
- **Parallel efficiency:** Reviews run simultaneously for faster turnaround
- **Deterministic integration:** Claude Code runs as one tracked interactive-shell session instead of a guessed background process
- **Consistency:** Standardized review format and process across all plans

### Do NOT:

- Run single-reviewer reviews for plans
- Skip the Claude Code integration phase
- Use lower reasoning settings to save time
- Manually review plans without delegating to this command
