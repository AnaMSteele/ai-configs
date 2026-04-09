---
description: Run a review-only change review using Claude Code via interactive-shell hands-free, backgrounded
argument-hint: '<path to plan.md | plan slug | legacy: <spec> <tasks> | legacy: <directory containing spec.md and tasks.md>'
---

# Change Review via Claude Code

Review the provided plan by launching real interactive Claude Code through `interactive_shell`.

This command is review-only and should behave like `/review:change-opus`, except the review runs inside Claude Code via `interactive_shell`.

Documents to review: $ARGUMENTS

## Execution Mode

- Use `interactive_shell`, not `process`, to launch Claude Code.
- Start exactly one real interactive Claude Code session and run a Claude Code review prompt against the target plan file.
- Launch Claude Code through a login shell so PATH entries supplied by shell startup files are available (for example `zsh -lic` on macOS where `claude` may live in `~/.local/bin`).
- If needed, prepend `export PATH="$HOME/.local/bin:$PATH"` before invoking `claude`.
- Use `mode: "hands-free"`, not `dispatch`, so the launch creates a real Claude Code TUI session that can then be backgrounded.
- Set `handsFree.autoExitOnQuiet: false` because interactive Claude does not exit on its own after answering.
- Do not launch retry sessions just because stdout/stderr stays empty.
- Do not inline the full Claude review prompt directly inside shell quotes. Instead, write the prompt body to `/tmp/pi-claude-review-prompt.txt`, write the exact Python wrapper below to `/tmp/pi-claude-review-wrapper.py`, and launch that wrapper through `interactive_shell`.
- Immediately move the launched Claude session to the background.
- Run a single Claude Code session that:
  1. resolves the target plan file,
  2. reviews the plan as a cohesive unit,
  3. adds inline review comments using the `[REVIEW:CLAUDE] ... [/REVIEW]` format for issues it finds,
  4. does not rewrite or integrate the plan, and
  5. stops after the review summary.
- Do not delegate the review to a `reviewer-*` subagent.
- Wait for the Claude Code interactive session to finish, then verify the resulting plan file in this session.

Your reviewer name is CLAUDE

Use this comment format:
```
[REVIEW:CLAUDE] Your critical feedback here [/REVIEW]
```

To respond to other reviewers:
```
[REVIEW:CLAUDE] RE: [OtherReviewer] - Your response [/REVIEW]
```

# Change Review (Single Plan File)

Review the provided plan as a cohesive unit. Your goal is to ensure the plan is solid and executable without scope creep or error.

Documents to review: $ARGUMENTS

## Scope (Review-Only; Do Not Integrate)

This command is review-only.

- Only modify the plan by inserting inline `[REVIEW:...] ... [/REVIEW]` comments.
- Do not change any other plan content (do not fix, rewrite, or reorganize anything).
- Do not remove or resolve review comments.
- Do not run follow-up commands (including `/review:change-integrate`).
- After adding comments and providing the summary, stop.

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

### 1) Launch Claude Code Directly

Use `interactive_shell` to start one Claude Code session that performs the review.

Prefer a login-shell launch shape such as:

```javascript
exec_command({
  cmd: `cat > /tmp/pi-claude-review-prompt.txt <<'EOF'
<prompt>
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
  reason: "Claude Code review",
})

interactive_shell({ sessionId: claudeSession.sessionId, background: true })
```

Lifecycle rules:

- Launch one session only.
- Do not start another Claude Code session while the first is still active.
- Immediately move the launched session to the background with `interactive_shell({ sessionId: claudeSession.sessionId, background: true })` so the review keeps running without holding the foreground overlay.
- Wait about 60 seconds before the first status query unless the user interrupts sooner.
- Query the session with `interactive_shell({ sessionId, outputLines: 80, outputMaxChars: 12000 })`.
- When the output shows Claude has returned to its `❯` prompt after finishing the review, send `/exit` with `interactive_shell({ sessionId, input: "/exit" })`, then press Enter with `interactive_shell({ sessionId, inputKeys: ["enter"] })`.
- After sending `/exit` and Enter, wait briefly and query once more to confirm the session exited.
- If the user wants to inspect the live TUI again, reattach with `interactive_shell({ attach: sessionId, mode: "dispatch" })` or equivalent before continuing.
- Only if the session exits non-zero may you inspect the failure and decide whether a single explicit retry is warranted.
- Do not invent alternate quoting strategies or new launcher shapes mid-run. The prompt-file + Python-wrapper transport above is the required transport.

The launched Claude Code prompt should:

- inspect the target plan,
- look for gaps, risks, ambiguity, incorrect references, scope drift, and execution-readiness defects,
- explicitly check that each unchecked phase is a bounded execution slice with `### Tests first`, `### End State`, `### Work`, and `### Verify`,
- flag unresolved `Open Questions` / `Decision Points` in any execution-ready plan,
- flag phases that are too large and would likely require same-scope subdivision during execution,
- write inline review comments only where they improve the final plan,
- preserve the plan structure and progress state,
- not rewrite or resolve existing review comments,
- and stop after the review summary.

Do not route the work through a review subagent. The whole point of this command is to use Claude Code itself as a review-only pass.

### 2) Validate the Result

After the Claude Code session completes:

- read the resulting plan file,
- confirm the plan structure is still intact,
- confirm any Claude-written comments use the `[REVIEW:CLAUDE]` form,
- and report whether Claude found issues or returned a clean review.

### 3) Summary

After verification, provide a concise review summary.

## Summary Format

```
## Review Complete

### Claude Findings:
- [List of the most important Claude review findings, or say none]

### Plan Status:
[Solid / Needs rework]

### Recommendation:
[Proceed with caution / Major revision needed]
```
