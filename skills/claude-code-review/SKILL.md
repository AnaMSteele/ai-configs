---
name: claude-code-review
description: Run read-only Claude Code plan/code reviews through the canonical private-tmux interactive launcher. Use when the task is to have Claude Code review a plan or code diff without editing files.
---

# Claude Code Review

Use this skill when a required Claude Code review must run reliably and produce a saved review artifact.

Required transport: call the canonical launcher:

```bash
python3 "$HOME/.agents/skills/claude-code-review/scripts/claude_interactive_review.py" \
  --cwd /path/to/repo \
  --prompt-file /tmp/claude-review-prompt.md \
  --output /tmp/claude-review-output.md \
  --review-name claude-review
```

The launcher owns all Claude Code process mechanics:

- creates a fresh private tmux server from the real caller process,
- checks `claude auth status` inside that private tmux server as an early signal,
- starts exactly one interactive Claude TUI with the launcher-internal command pinned to Sonnet 4.6 (`claude --model claude-sonnet-4-6`),
- pastes the prompt through tmux,
- extracts only the answer region after the post-submit boundary,
- writes normalized review text at the beginning of `--output`,
- tears down successful smoke/review tmux servers,
- preserves transcript and inspect metadata on failure.

Do not choose or document alternate required-review transports or models. Required Claude Code reviews must use the launcher's Sonnet 4.6 pin. In particular, do not use `claude -p` [FORBIDDEN-EXAMPLE], `claude --print` [FORBIDDEN-EXAMPLE], prompt piping, input redirection, direct `interactive_shell` Claude launches, direct `process` Claude launches, raw tmux Claude snippets outside the launcher, Opus, or model-provider substitutes for a required Claude Code gate.

## Same-process smoke

Before relying on a caller context, smoke-test the launcher from that same context:

```bash
python3 "$HOME/.agents/skills/claude-code-review/scripts/claude_interactive_review.py" \
  --smoke \
  --cwd /path/to/repo \
  --review-name claude-review-smoke \
  --output /tmp/claude-review-smoke.txt
```

Pass condition: output contains `CLAUDE_REVIEW_SMOKE_READY`, `socket=`, and `session=`. Smoke success tears down its private tmux server. Smoke failure is a real prerequisite/auth/readiness failure; do not retry with another transport.

## Prompt rules

Write the review prompt to a file, then pass that path via `--prompt-file`. Keep prompts read-only and scope-bounded:

- explicitly say **read-only** and **do not edit files**,
- name the plan path or diff/range under review,
- name the expected verdict format,
- ask for findings with file/path evidence,
- exclude unrelated cleanup and broad audits.

## Failure handling

Launcher failures are classified and agent-legible:

- missing `tmux` or `claude`,
- private-tmux auth unavailable,
- TUI reports not logged in,
- TUI readiness timeout,
- prompt-boundary uncertainty,
- review timeout.

On failure, read the output file and sibling transcript. If an inspect command is present, use it to inspect the preserved private tmux server. Ask for the exact user action named by the failure, such as `/login` or unlocking the keychain. Never switch to a direct Claude transport as a fallback.

## Installed locations

The canonical source is `skills/claude-code-review/scripts/claude_interactive_review.py`.

Expected installed copies:

- Pi/shared skill: `$HOME/.agents/skills/claude-code-review/scripts/claude_interactive_review.py`
- OpenCode compatibility skill: `$HOME/.config/opencode/skills/claude-code-review/scripts/claude_interactive_review.py`

Pi prompts should call the central shared launcher under `$HOME/.agents/skills`. OpenCode scripts may resolve `$CLAUDE_REVIEW_LAUNCHER`, the shared installed launcher, the repo checkout launcher, or the OpenCode compatibility copy, in that order.
