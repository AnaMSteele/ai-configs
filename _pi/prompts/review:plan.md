---
description: Run comprehensive review-only plan review using GPT5.4, Kimi K2.5, and Claude Code in parallel
argument-hint: '<path to plan.md | plan slug | legacy: <spec> <tasks> | legacy: <directory containing spec.md and tasks.md>'
---

# Multi-Model Plan Review Process

This command orchestrates a comprehensive review-only plan review using three independent reviewers in parallel: GPT5.4, Kimi K2.5, and Claude Code.

Documents to review: $ARGUMENTS

## Execution Mode

- Use the actual Pi subagent tool surface: launch two background agents with `Agent`, and launch Claude Code via `interactive_shell`.
- Each reviewer runs independently without seeing the other's work.
- Start the Claude session in `hands-free` mode, then immediately move that session to the background so it does not pin the foreground overlay while it works.
- All three reviewers must be launched before waiting for completions.
- Do not perform any reviews directly in the primary agent.
- Do not rely on a nonexistent `subagent(...)` runner or on slash-command chaining.
- Do not use the `process` tool for the Claude review.
- Launch exactly one Claude Code review session and treat that session as authoritative.
- Do not infer failure from quiet output. Claude may think silently and then return to its prompt.
- Do not launch a second Claude Code session unless the first session has already exited non-zero and you are explicitly retrying after reporting that failure cause.
- This command is review-only. Do not integrate or clean up review comments here.

## Phase 1: Parallel Review (3 Reviewers)

Launch all three reviews before waiting for any of them to finish.

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

### Reviewer 3: Claude Code Review
- **Tool:** `interactive_shell`
- **Reviewer name:** `CLAUDE`
- **Task:** Perform a review-only pass equivalent to `/review:change-opus`, but by launching real Claude Code via `interactive_shell`
- **Output:** Plan file with `[REVIEW:CLAUDE]` comments + summary

### Parallel Execution

Launch two background `Agent` calls plus one backgrounded Claude Code session so Pi actually runs all three reviewers concurrently.

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

exec_command({
  cmd: `cat > /tmp/pi-claude-review-prompt.txt <<'EOF'
Review the plan at $ARGUMENTS as a review-only pass.

Your reviewer name is CLAUDE.
Use [REVIEW:CLAUDE] ... [/REVIEW] comments.
Only insert review comments. Do not rewrite, integrate, or remove plan content. Stop after your review summary.
EOF
cat > /tmp/pi-claude-review-wrapper.py <<'PY'
import os
import sys

repo = sys.argv[1]
prompt_path = sys.argv[2]
with open(prompt_path, 'r', encoding='utf-8') as fh:
    prompt = fh.read()

cmd = [
    'claude',
    '--permission-mode', 'bypassPermissions',
    '--effort', 'high',
    prompt,
]

os.chdir(repo)
os.execvp(cmd[0], cmd)
PY`,
});

const claudeSession = interactive_shell({
  command: `zsh -lic 'export PATH="$HOME/.local/bin:$PATH"; cd "$PWD" || exit 1; command -v claude >/dev/null 2>&1 || { echo "claude_not_found" >&2; exit 127; }; exec python3 /tmp/pi-claude-review-wrapper.py "$PWD" /tmp/pi-claude-review-prompt.txt'`,
  mode: "hands-free",
  handsFree: { autoExitOnQuiet: false, quietThreshold: 8000, updateInterval: 60000 },
  reason: "Claude Code review-only pass",
});

interactive_shell({ sessionId: claudeSession.sessionId, background: true });

get_subagent_result({ agent_id: gpt54.agent_id ?? gpt54.id, wait: true });
get_subagent_result({ agent_id: kimi.agent_id ?? kimi.id, wait: true });
interactive_shell({ sessionId: claudeSession.sessionId, outputLines: 80, outputMaxChars: 12000 });
interactive_shell({ sessionId: claudeSession.sessionId, input: "/exit" });
interactive_shell({ sessionId: claudeSession.sessionId, inputKeys: ["enter"] });
interactive_shell({ sessionId: claudeSession.sessionId, outputLines: 80, outputMaxChars: 12000 });
```

Wait for both `get_subagent_result(..., wait: true)` calls and the Claude Code session to complete before producing any summary text.

## Phase 2: Claude Code Review Lifecycle

Claude Code is another review-only reviewer in this command, not an integration pass.

### Claude Code Pass
- **Tool:** `interactive_shell`
- **Purpose:** Review the plan with Claude Code directly in parallel with GPT5.4 and Kimi.
- **Task:** Start exactly one Claude Code interactive-shell session against the target plan file while the two parallel reviewer subagents are also running.
- **Shell requirement:** launch Claude Code through a login shell so user-local PATH entries such as `~/.local/bin/claude` are available on macOS and similar setups.
- **Mode requirement:** use `mode: "hands-free"`, not `dispatch`, so the launch path creates a real Claude Code TUI session that can then be backgrounded and later controlled explicitly.
- **Lifecycle requirement:** set `handsFree.autoExitOnQuiet: false`. Interactive Claude does not exit on its own after answering.
- **Prompt transport requirement:** do not inline the full Claude review prompt directly inside shell quotes. Instead, write the prompt body to `/tmp/pi-claude-review-prompt.txt`, write the exact Python wrapper below to `/tmp/pi-claude-review-wrapper.py`, and launch that wrapper through `interactive_shell`.

### Claude Code Execution

Use the same review-only behavior as `/review:change-claude-code`, but perform it here with `interactive_shell` rather than by invoking another slash command.

Example shape:

```javascript
exec_command({
  cmd: `cat > /tmp/pi-claude-review-prompt.txt <<'EOF'
<review-only prompt for $ARGUMENTS using [REVIEW:CLAUDE] comments>
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
    '--permission-mode', 'bypassPermissions',
    '--effort', 'high',
    prompt,
]

os.chdir(repo)
os.execvp(cmd[0], cmd)
PY`,
})

const claudeSession = interactive_shell({
  command: `zsh -lic 'export PATH="$HOME/.local/bin:$PATH"; cd "$PWD" || exit 1; command -v claude >/dev/null 2>&1 || { echo "claude_not_found" >&2; exit 127; }; exec python3 /tmp/pi-claude-review-wrapper.py "$PWD" /tmp/pi-claude-review-prompt.txt'`,
  mode: "hands-free",
  handsFree: { autoExitOnQuiet: false, quietThreshold: 8000, updateInterval: 60000 },
  reason: "Claude Code plan review",
});

interactive_shell({ sessionId: claudeSession.sessionId, background: true });
```

Execution rules:

- Launch one session.
- Do not start a second Claude Code session while the first interactive session is still running.
- After the session starts, immediately dismiss it to the background with `interactive_shell({ sessionId: claudeSession.sessionId, background: true })` so the review continues without occupying the foreground overlay.
- Wait about 60 seconds before the first status query unless the user interrupts sooner.
- Query the session with `interactive_shell({ sessionId, outputLines: 80, outputMaxChars: 12000 })`.
- When the output shows Claude has returned to its `❯` prompt after finishing the review, send `/exit` with `interactive_shell({ sessionId, input: "/exit" })`, then press Enter with `interactive_shell({ sessionId, inputKeys: ["enter"] })`.
- After sending `/exit` and Enter, wait briefly and query once more to confirm the session exited.
- If the user wants to watch it again, reattach with `interactive_shell({ attach: sessionId, mode: "dispatch" })` or equivalent before continuing.
- Only if that session exits non-zero or fails to launch may you inspect the failure and decide whether one explicit retry is justified.
- Do not invent alternate quoting strategies or new launcher shapes mid-run. The prompt-file + Python-wrapper transport above is the required transport.

Then read the resulting plan file and report the review comments left by the reviewers.

Failure condition: if the command returns before an `interactive_shell` call launches Claude Code, the review is incomplete and must not be treated as successful.

## Review Output

The final plan file should be an annotated plan containing any `[REVIEW:...]` comments left by GPT5.4, Kimi K2.5, and Claude.

## Summary Format

After completing all reviews, provide:

```markdown
## Multi-Model Review Complete

### Reviewers:
- ✅ GPT5.4 (openai-codex/gpt-5.4, high reasoning)
- ✅ Kimi K2.5 (opencode/kimi-k2.5, high reasoning)
- ✅ Claude Code (review-only via pi-interactive-shell hands-free, then backgrounded)

### Consensus Areas:
[List issues multiple reviewers flagged]

### Divergent Views:
[List any disagreements between GPT5.4 and Kimi, if present]

### Unique Insights:
[List issues caught by only one reviewer]

### Final Recommendation:
[Major revision needed / Proceed with caution / Ready to execute]
```

## Scope

This command is review-only:

- Phase 1: GPT5.4 review-only pass
- Phase 1: Kimi K2.5 review-only pass
- Phase 1: Claude Code review-only pass
- The final output is an annotated plan with review comments left in place
- If the user wants integration afterward, run `/review:change-integrate <plan>`

## Execution Flow Summary

```text
Input Plan
    ↓
Phase 1: Parallel Reviews (3 reviewers)
  ├─ GPT5.4 Review → [REVIEW:GPT5.4] comments
  ├─ Kimi K2.5 Review → [REVIEW:Kimi K2.5] comments
  └─ Claude Code Review → [REVIEW:CLAUDE] comments
    ↓
Output: Annotated Plan (run /review:change-integrate before execution if you want comments resolved)
```

---

## Oh My Pi Integration Instructions

### For ALL Plan Reviews in Oh My Pi:

**This `/review:plan` command MUST be used as the standard review process for ALL plans.**

Whenever a plan is created or updated and needs review:

1. **Primary agent MUST delegate to this command** instead of performing direct review
2. **Always use the full multi-model review** - do not skip reviewers or use single-reviewer shortcuts
3. **Launch all three reviewers before waiting** - GPT5.4, Kimi, and Claude Code should all be running in parallel
4. **Keep this command review-only** - it should stop with inline review comments still present in the plan
5. **Do not make the running agent invent fallback launcher logic** - this prompt must already specify the exact Claude launch path and lifecycle handling

### Process Flow:

```text
User: "Review this plan"
Agent: Delegate to /review:plan <plan-path>
  → Agent launches GPT5.4 + Kimi reviewers and Claude Code in parallel
  → Each adds [REVIEW:Name] comments
  → Returns an annotated plan with review comments left in place
```

### Benefits:

- **Multiple perspectives:** Two different model architectures catch different issue types
- **High reasoning mode:** All reviewers use a strong review pass
- **Parallel efficiency:** All three reviews run simultaneously for faster turnaround
- **Deterministic Claude launch:** Claude Code runs as one tracked interactive-shell session, then gets backgrounded instead of occupying the foreground overlay
- **Consistency:** Standardized review format and process across all plans

### Do NOT:

- Run single-reviewer reviews for plans
- Skip the Claude Code review phase
- Use lower reasoning settings to save time
- Manually review plans without delegating to this command
