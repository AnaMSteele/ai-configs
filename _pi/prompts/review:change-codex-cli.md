---
description: Run a review-only change review using interactive Codex via interactive-shell hands-free, backgrounded
argument-hint: '<path to plan.md | plan slug | legacy: <spec> <tasks> | legacy: <directory containing spec.md and tasks.md>'
---

# Change Review via Interactive Codex

Review the provided plan by launching real interactive Codex through `interactive_shell`.

This command is review-only and should behave like `/review:change-codex`, except the review runs inside the real Codex TUI via `interactive_shell`.

Documents to review: $ARGUMENTS

## Execution Mode

- Use `interactive_shell`, not `process`, to launch Codex.
- Start exactly one real interactive Codex session and run a Codex review prompt against the target plan file.
- Launch Codex through a login shell so PATH entries supplied by shell startup files are available.
- If needed, prepend `export PATH="$HOME/.local/bin:$PATH"` before invoking `codex`.
- Use `mode: "hands-free"`, not `dispatch`, so the launch creates a real Codex TUI session that can then be backgrounded.
- Set `handsFree.autoExitOnQuiet: false` because interactive Codex may remain open after answering.
- Do not pass Codex `-s/--sandbox` flags in the interactive shell.
- Do explicitly pass `--dangerously-bypass-approvals-and-sandbox`. In PTY-driven review sessions, Codex's default `workspace-write` sandbox can fail before any real work starts (`bwrap: loopback: Failed RTM_NEWADDR: Operation not permitted`), which prevents local plan-file access. Do not rely on repo trust config or default CLI flags to disable that sandbox implicitly.
- Do not combine `--dangerously-bypass-approvals-and-sandbox` with `-a/--ask-for-approval`; Codex rejects that flag combination with exit code 2.
- Do not inline the full Codex review prompt directly inside shell quotes. Instead, write the prompt body to `/tmp/pi-codex-review-prompt.txt`, write the exact Python wrapper below to `/tmp/pi-codex-review-wrapper.py`, and launch that wrapper through `interactive_shell`.
- Immediately move the launched Codex session to the background.
- Run a single Codex session that:
  1. resolves the target plan file,
  2. reviews the plan as a cohesive unit,
  3. adds inline review comments using the `[REVIEW:CODEX] ... [/REVIEW]` format for issues it finds,
  4. does not rewrite or integrate the plan, and
  5. stops after the review summary.
- Do not delegate the review to a `reviewer-*` subagent.
- Wait for the Codex interactive session to finish, then verify the resulting plan file in this session.

Your reviewer name is CODEX

Use this comment format:
```text
[REVIEW:CODEX] Your critical feedback here [/REVIEW]
```

To respond to other reviewers:
```text
[REVIEW:CODEX] RE: [OtherReviewer] - Your response [/REVIEW]
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

### 1) Launch Codex Directly

Use `interactive_shell` to start one Codex session that performs the review.

Prefer a login-shell launch shape such as:

```javascript
exec_command({
  cmd: `cat > /tmp/pi-codex-review-prompt.txt <<'EOF'
<prompt>
EOF
cat > /tmp/pi-codex-review-wrapper.py <<'PY'
import os
import sys

repo = sys.argv[1]
prompt_path = sys.argv[2]
with open(prompt_path, 'r', encoding='utf-8') as fh:
    prompt = fh.read()

cmd = [
    'codex',
    '--dangerously-bypass-approvals-and-sandbox',
    '-m', 'gpt-5.4',
    '-c', 'model_reasoning_effort="high"',
    '--no-alt-screen',
    prompt,
]

os.chdir(repo)
os.execvp(cmd[0], cmd)
PY`,
})

const codexSession = interactive_shell({
  command: `zsh -lic 'export PATH="$HOME/.local/bin:$PATH"; cd "$PWD" || exit 1; command -v codex >/dev/null 2>&1 || { echo "codex_not_found" >&2; exit 127; }; exec python3 /tmp/pi-codex-review-wrapper.py "$PWD" /tmp/pi-codex-review-prompt.txt'`,
  mode: "hands-free",
  handsFree: { autoExitOnQuiet: false, quietThreshold: 8000, updateInterval: 60000 },
  reason: "Codex review",
})

interactive_shell({ sessionId: codexSession.sessionId, background: true })
```

Lifecycle rules:

- Launch one session only.
- Do not start another Codex session while the first is still active.
- Immediately move the launched session to the background with `interactive_shell({ sessionId: codexSession.sessionId, background: true })` so the review keeps running without holding the foreground overlay.
- Wait about 60 seconds before the first status query unless the user interrupts sooner.
- Query the session with `interactive_shell({ sessionId, outputLines: 80, outputMaxChars: 12000 })`.
- When the output shows Codex has finished the review and the target plan file already contains `[REVIEW:CODEX]` comments, it is acceptable to end the TUI session with `interactive_shell({ sessionId, kill: true })`.
- If Codex clearly returns to an idle prompt after finishing and accepts normal exit input, you may exit it cleanly instead of killing it.
- Only if the session exits non-zero may you inspect the failure and decide whether a single explicit retry is warranted.
- Do not invent alternate quoting strategies or new launcher shapes mid-run. The prompt-file + Python-wrapper transport above is the required transport.

The launched Codex prompt should:

- inspect the target plan,
- look for gaps, risks, ambiguity, incorrect references, scope drift, and execution-readiness defects,
- explicitly check that each unchecked phase is a bounded execution slice with `### Tests first`, `### End State`, `### Work`, and `### Verify`,
- flag unresolved `Open Questions` / `Decision Points` in any execution-ready plan,
- flag phases that are too large and would likely require same-scope subdivision during execution,
- write inline review comments only where they improve the final plan,
- preserve the plan structure and progress state,
- not rewrite or resolve existing review comments,
- and stop after the review summary.

Do not route the work through a review subagent. The whole point of this command is to use Codex itself as a review-only pass.

### 2) Validate the Result

After the Codex session completes:

- read the resulting plan file,
- confirm the plan structure is still intact,
- confirm any Codex-written comments use the `[REVIEW:CODEX]` form,
- and report whether Codex found issues or returned a clean review.

### 3) Summary

After verification, provide a concise review summary.

## Summary Format

```text
## Review Complete

### Codex Findings:
- [List of the most important Codex review findings, or say none]

### Plan Status:
[Solid / Needs rework]

### Recommendation:
[Proceed with caution / Major revision needed]
```
