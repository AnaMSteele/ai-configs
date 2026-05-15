---
name: omp-review-partner
description: Use omp with OpenCode Zen Kimi models as a read-only review partner for implementation reviews, plan reviews, and technical pairing. Use this whenever the user asks to review plans or code with omp, opencode-zen, Kimi, kimi-k2.6, or wants an omp-based alternative to the Claude Code or Codex review partner workflow.
argument-hint: "[implementation-review|plan-review|pair] <input-file> [repo-path] [model]"
---

# OMP Review Partner

Use `omp` as an explicit second pass before finalizing technical plans or code changes.

This skill mirrors the local Claude Code review pattern: use a bounded prompt, run read-only, select the model explicitly, and capture structured review output. The tested default model is `opencode-zen/kimi-k2.6`.

## Core rule

Use one of three modes:
- `implementation-review` for code changes, bug fixes, refactors, and tests
- `plan-review` for plans, specs, and implementation approaches
- `pair` for open-ended debugging, exploration, and design discussion

Keep the inner review read-only. Disable write/edit tools by passing an explicit `--tools` list that excludes `edit` and `write`.

## Verified local facts

Checked on this machine:
- `omp` is installed at `/Users/anichols/.bun/bin/omp`.
- `omp v15.0.1` supports `-p`, `--model`, `--thinking`, `--no-session`, and `--tools`.
- `omp --list-models kimi` lists `opencode-zen/kimi-k2.6` with thinking levels `minimal,low,medium,high,xhigh`.
- Direct non-interactive reviews with `--model opencode-zen/kimi-k2.6` successfully reviewed local plan and implementation files.
- A review-named window in the existing `codex` tmux session worked when targeting the session as `codex:`.

## Recommended workflow

1. Create a concise input file with the exact context OMP needs.
2. Run `scripts/run-review.sh --help` if you need the wrapper interface.
3. Invoke the wrapper in the matching mode with an explicit model.
4. Review the output critically. OMP is a reviewer, not an oracle.
5. Verify important claims against the repo, tests, and runtime evidence.

## Wrapper usage

```bash
~/.agents/skills/omp-review-partner/scripts/run-review.sh \
  --mode implementation-review \
  --input /tmp/review-input.md \
  --cwd /path/to/repo \
  --model opencode-zen/kimi-k2.6
```

Optional output capture:

```bash
~/.agents/skills/omp-review-partner/scripts/run-review.sh \
  --mode plan-review \
  --input /tmp/plan-review.md \
  --cwd /path/to/repo \
  --model opencode-zen/kimi-k2.6 \
  --output /tmp/omp-plan-review.md
```

## Direct CLI pattern

Use this when the wrapper is unnecessary:

```bash
omp \
  --model opencode-zen/kimi-k2.6 \
  --thinking high \
  --no-session \
  --tools read,grep,find,bash,lsp \
  -p "$(< /tmp/review-input.md)"
```

## Background tmux pattern

Use the existing user-owned `codex` tmux session for background reviews, matching the Claude Code review workflow. In this environment, target the session as `codex:`.

```bash
prompt=/tmp/codex-omp-review-prompt.txt
out=/tmp/codex-omp-review-output.txt
window=omp-kimi-review

tmux has-session -t codex 2>/dev/null || \
  zellij --session main run --name codex-tmux-bootstrap --close-on-exit -- \
    /bin/zsh -ilc 'tmux new-session -d -s codex'

rm -f "$out"
tmux new-window -t codex: -n "$window" \
  "cd /path/to/repo && zsh -ilc 'omp --model opencode-zen/kimi-k2.6 --thinking high --no-session --tools read,grep,find,bash,lsp -p \"\$(< $prompt)\" > $out 2>&1; echo EXIT=\$? >> $out'"

for i in {1..300}; do
  [ -f "$out" ] && tail -1 "$out" | grep -q '^EXIT=' && break
  sleep 1
done
cat "$out"
```

## Input guidance

Keep the input concrete and bounded:
- what changed or what is proposed
- which files or diffs matter
- what kind of review you want
- any repo-specific constraints or acceptance criteria
- commands/tests already run

For templates, see `references/prompt-templates.md`.

## Prompt rules

Prefer prompts that:
- explicitly say `read-only`
- explicitly say `do not edit files`
- ask for compact structured review output
- name exact files/docs to review
- name the comparison docs, rubric, or acceptance criteria

Good plan review structure:
- `Verdict`
- `Findings`
- `Required Changes`
- `Residual Risks`

Good implementation review structure:
- `Verdict`
- `Findings`
- `Required Changes`
- `Residual Risks`

## Timeout rule

Do not use a short 120 second timeout for review work.

Minimum:
- use at least 300 seconds for a blocking review run
- for long reviews, launch in a review-named tmux window and wait for completion
- prefer waiting for a complete review over truncating a live run

## Non-recursion rule

If the wrapper or prompt says that OMP review-partner invocation is already active, do not start another nested OMP, Codex, or Claude review session.

## Final-answer rule

When an OMP review was used, summarize:
- what was reviewed
- the model used
- key findings or that no material issues were found
- what changed because of the review, if anything
