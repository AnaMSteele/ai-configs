---
description: Run a change review using Claude Code via interactive-shell dispatch
argument-hint: '<path to plan.md | plan slug | legacy: <spec> <tasks> | legacy: <directory containing spec.md and tasks.md>'
---

# Change Review via Claude Code

Review the provided plan by launching Claude Code through `interactive_shell`, then integrate the results into a clean plan.

Documents to review: $ARGUMENTS

## Execution Mode

- Use `interactive_shell`, not `process`, to launch Claude Code.
- Start exactly one Claude Code dispatch session and run a Claude Code review prompt against the target plan file.
- Launch Claude Code through a login shell so PATH entries supplied by shell startup files are available (for example `zsh -lic` on macOS where `claude` may live in `~/.local/bin`).
- If needed, prepend `export PATH="$HOME/.local/bin:$PATH"` before invoking `claude`.
- Use `mode: "dispatch"` so Pi tracks completion and does not force the agent to guess from silent logs.
- Do not launch retry sessions just because stdout/stderr stays empty.
- Do not inline the full Claude review prompt directly inside shell quotes. Instead, write the prompt body to `/tmp/pi-claude-review-prompt.txt`, write the exact Python wrapper below to `/tmp/pi-claude-review-wrapper.py`, and launch that wrapper through `interactive_shell`.
- Run a single Claude Code session that:
  1. resolves the target plan file,
  2. reviews the plan as a cohesive unit,
  3. adds inline review comments using the `[REVIEW:CLAUDE CODE] ... [/REVIEW]` format for issues it finds,
  4. applies the accepted feedback using the same rules as `/review:change-integrate`, and
  5. leaves the plan clean and executable.
- Do not delegate the review to a `reviewer-*` subagent.
- Do not stop after the review comments are written; complete the integration pass before responding.
- Wait for the Claude Code dispatch session to finish, then verify the resulting plan file in this session.

Your reviewer name is CLAUDE CODE

Use this comment format:
```
[REVIEW:CLAUDE CODE] Your critical feedback here [/REVIEW]
```

To respond to other reviewers:
```
[REVIEW:CLAUDE CODE] RE: [OtherReviewer] - Your response [/REVIEW]
```

# Change Review and Integration (Single Plan File)

Review the provided plan as a cohesive unit, then integrate the accepted feedback into the same file. Your goal is to ensure the final plan is solid, executable, and clean without scope creep or error.

Documents to review: $ARGUMENTS

## Scope (Review-and-Integrate; Do Not Leave Review Comments Behind)

This command is review-and-integrate.

- The Claude Code run may write inline `[REVIEW:...] ... [/REVIEW]` comments while reviewing.
- Once the review pass is complete, those comments must be resolved by integrating the accepted feedback into the plan.
- Do not leave unresolved review comments in the final file.
- Do not stop after the review pass; continue through integration and validation.

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
  reason: "Claude Code review + integration",
})
```

Lifecycle rules:

- Launch one session only.
- Do not start another Claude Code session while the first is still active.
- Wait for the automatic completion notification from `interactive_shell`.
- Only if the session exits non-zero may you inspect the failure and decide whether a single explicit retry is warranted.
- Do not invent alternate quoting strategies or new launcher shapes mid-run. The prompt-file + Python-wrapper transport above is the required transport.
- Keep the option order exactly as shown so the final prompt string is not swallowed by Claude's variadic `--add-dir` parsing.

The launched Claude Code prompt should:

- inspect the target plan,
- look for gaps, risks, ambiguity, incorrect references, and scope drift,
- write inline review comments only where they improve the final plan,
- then integrate every resolved comment into the plan,
- preserve the plan structure and progress state,
- and leave no unresolved review comments behind.

Do not route the work through a review subagent. The whole point of this command is to use Claude Code itself for the review and integration pass.

### 2) Validate the Result

After the Claude Code session completes:

- read the resulting plan file,
- confirm there are no remaining `[REVIEW:...]` comments,
- confirm the plan still has runnable phases, progress, and verify steps if it had them before,
- and confirm the file now reflects the accepted feedback.

### 3) Summary

After verification, provide a concise summary of what changed and whether the plan is ready for execution.

## Summary Format

```
## Review and Integration Complete

### Changes Made:
- [List of review findings that were integrated]

### Final Status:
[Solid / Needs more work]

### Recommendation:
[Proceed / Proceed with caution / Major revision needed]
```
