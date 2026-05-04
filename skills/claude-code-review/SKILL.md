---
name: claude-code-review
description: Launch Claude Code through the user-owned codex tmux session for background plan/code reviews. Use when the task is to have Claude Code review a plan or code diff without editing files.
---

# Claude Code Review

Use this skill when you want Claude Code to review work in the background and report back reliably on the first try.

Hard requirement: always invoke Claude through a login shell and a real PTY. Do not call `claude` directly from a plain non-login shell.

On this machine, a Codex-created tmux server can still fail macOS Keychain access and cause `claude auth status` to report `loggedIn: false`. The durable background runner is the user-owned tmux session named `codex`, whose server is created from the user's authenticated interactive multiplexer context. Create review-specific windows inside that session; do not name sessions by review/date.

## Preflight

Before declaring Claude unavailable:

1. Confirm the `codex` tmux session exists.
2. If it is missing, recreate it through the existing authenticated `zellij main` session.
3. Run the Claude auth check in a temporary window in `codex`.

```bash
tmux has-session -t codex 2>/dev/null || \
  zellij --session main run --name codex-tmux-bootstrap --close-on-exit -- \
    /bin/zsh -ilc 'tmux new-session -d -s codex'

out=/tmp/codex-claude-auth.txt
rm -f "$out"
tmux new-window -t codex -n claude-auth-probe \
  "zsh -ilc 'claude auth status > $out 2>&1; echo EXIT=\$? >> $out'"
for i in {1..30}; do
  [ -f "$out" ] && grep -q '^EXIT=' "$out" && break
  sleep 0.2
done
cat "$out"
tmux kill-window -t codex:claude-auth-probe 2>/dev/null || true
```

If the zellij bootstrap fails because `zellij main` is not running, stop and report that the authenticated user multiplexer is unavailable. Do not open Terminal.app automatically.

## Default launch pattern

Use one tmux session named `codex`. Name each review window for the review, such as `claude-plan-nod636` or `claude-diff-auth`.

```bash
prompt=/tmp/codex-claude-review-prompt.txt
out=/tmp/codex-claude-review-output.txt
window=claude-plan-review

cat > "$prompt" <<'PROMPT'
Review thoughts/plans/foo.md against AGENTS.md and thoughts/specs/product_intent.md.
This is read-only. Do not edit files. Return a concise review with Verdict, Findings, Required Changes, Residual Risks.
PROMPT

tmux has-session -t codex 2>/dev/null || \
  zellij --session main run --name codex-tmux-bootstrap --close-on-exit -- \
    /bin/zsh -ilc 'tmux new-session -d -s codex'

rm -f "$out"
tmux new-window -t codex -n "$window" \
  "cd /path/to/repo && zsh -ilc 'claude -p \"\$(< $prompt)\" > $out 2>&1; echo EXIT=\$? >> $out'"

for i in {1..180}; do
  [ -f "$out" ] && tail -1 "$out" | grep -q '^EXIT=' && break
  sleep 1
done
cat "$out"
```

Keep the temp command read-only in behavior: ask Claude not to edit files and use `claude -p` for one-shot review output.

## What worked in local testing

### Reliable default
Use the `codex` tmux session with:
- one window per review
- a login shell wrapper around Claude, e.g. `zsh -ilc 'claude -p "$(< /tmp/prompt.txt)"'`
- a prompt that asks Claude Code to return the review in stdout, not save it to a file

### Less reliable paths
Avoid these as the first attempt:
- creating a fresh tmux server directly from Codex
- opening Terminal.app as an automatic fallback
- asking Claude Code in `plan` mode to write review output to `/tmp` or repo files
- starting `hands-free`, then backgrounding it, then trying to steer it later
- using write-to-`/tmp` as the normal artifact path for read-only reviews

In testing, the write-to-file flow stalled on Claude Code permission prompts after `Write(...)` failed and it fell back to `Bash(touch /tmp/file)`.

## Default launch patterns

### 1) One-shot plan review
```bash
prompt=/tmp/codex-claude-plan-review-prompt.txt
out=/tmp/codex-claude-plan-review-output.txt
window=claude-plan-review

cat > "$prompt" <<'PROMPT'
Review thoughts/plans/foo.md against thoughts/plans/AGENTS.md and thoughts/specs/product_intent.md.
This is a read-only plan review. Do not edit files.
Return concise sections: Verdict, Strengths, Issues, Required Changes.
PROMPT

tmux has-session -t codex 2>/dev/null || \
  zellij --session main run --name codex-tmux-bootstrap --close-on-exit -- \
    /bin/zsh -ilc 'tmux new-session -d -s codex'

rm -f "$out"
tmux new-window -t codex -n "$window" \
  "cd /path/to/repo && zsh -ilc 'claude -p \"\$(< $prompt)\" > $out 2>&1; echo EXIT=\$? >> $out'"
```

### 2) One-shot code review
```bash
prompt=/tmp/codex-claude-code-review-prompt.txt
out=/tmp/codex-claude-code-review-output.txt
window=claude-code-review

cat > "$prompt" <<'PROMPT'
Review path/to/file.ts and path/to/test.ts for correctness, edge cases, and test gaps.
This is a read-only code review. Do not edit files.
Return concise sections: Summary, Findings, Suggested Follow-ups.
PROMPT

tmux has-session -t codex 2>/dev/null || \
  zellij --session main run --name codex-tmux-bootstrap --close-on-exit -- \
    /bin/zsh -ilc 'tmux new-session -d -s codex'

rm -f "$out"
tmux new-window -t codex -n "$window" \
  "cd /path/to/repo && zsh -ilc 'claude -p \"\$(< $prompt)\" > $out 2>&1; echo EXIT=\$? >> $out'"
```

## Prompt rules

Prefer prompts that:
- explicitly say **read-only**
- explicitly say **do not edit files**
- ask for a **compact structured review on stdout**
- name the exact files/docs to review
- name the rubric or comparison docs

Good plan review structure:
- `Verdict`
- `Strengths`
- `Issues`
- `Required Changes`

Good code review structure:
- `Summary`
- `Findings`
- `Suggested Follow-ups`

## When to use an attached session instead

For one-pass reviews, prefer `claude -p` in a review-named tmux window. If you expect real follow-up interaction while Claude Code stays live, create a named window in the existing `codex` session and attach to it manually.

```bash
tmux new-window -t codex -n claude-review-live \
  "cd /path/to/repo && zsh -ilc 'claude'"
```

Do not default to this for one-pass reviews.

## If you need a saved artifact

Best path:
1. ask Claude Code to return the review on stdout
2. capture the review from the tmux-launched command output
3. save it yourself with Codex file-editing tools

Do not make Claude Code file-writing the default for review tasks.

## If the run gets stuck

Typical failure pattern in testing:
- Claude Code attempts `Write(...)`
- write fails
- Claude falls back to `Bash(touch /tmp/file)`
- session blocks on an approval prompt

Recovery:
1. inspect the session output via `tmux capture-pane -t codex:<window> -p`
2. if the session is waiting on permissions, stop it
3. relaunch with a simpler read-only prompt that returns the review on stdout
4. save the result yourself if needed

A non-zero exit does not automatically mean failure. In testing, a plan review produced a complete structured review in the transcript and still ended with exit code `143` after teardown. Judge success by whether the review content was fully produced.

## Notes from testing

Observed:
- `tmux new-window -t codex ... claude auth status` reported logged in
- if the `codex` tmux session is missing, creating it through `zellij --session main run ... tmux new-session -d -s codex` preserves Claude auth
- creating a fresh tmux server directly from Codex reported Claude logged out
- `plan mode + write to /tmp` did not succeed reliably
- `acceptEdits` and extra `/tmp` access were not proven reliable enough to recommend as the default review workflow

## Recommendation

For “have Claude Code review this in the background,” the first try should be:
- reuse tmux session `codex`
- create a review-named window
- run `zsh -ilc 'claude -p ...'`
- return review in stdout
- save artifacts with Codex, not Claude Code
- if `codex` is missing, recreate it via `zellij --session main`; do not open Terminal.app automatically
