---
description: Iterative branch code review loop (GPT-5.2 subagent) - review branch changes, apply quick fixes, stop when no straightforward fixes remain
argument-hint: ""
agent: build
subtask: true
model: openai/gpt-5.2
---

# Branch Review Loop (Auto-Fix)

Run a GPT-5.2 review loop by delegating each review pass to the `reviewer-gpt5.2` subagent. Do not shell out to `opencode /review`.

This command reviews branch changes only.

## Scope Rules

In-scope changes are:

- Commits on the current branch since the branch diverged from the default remote branch.
- Local uncommitted changes (staged + unstaged + untracked files).

Out of scope:

- Any review scope that is only `origin/main...HEAD` (or another fixed branch) without first resolving the branch merge-base.
- Any changes outside the current branch and working tree.

## Process

### 0) Autopilot Rules

- Execute continuously; do not pause between iterations.
- Do not stop after a status update (for example, "reviewing" or "fixing issues").
- Every response must either (a) take the next concrete action by invoking a tool, or (b) ask for user input due to an unresolvable decision.
- Use `question` only when a decision between viable options materially changes behavior and cannot be resolved from the repo.

### 1) Resolve Branch Baseline

Determine the review base from the current branch's divergence point.

```bash
current_branch=$(git rev-parse --abbrev-ref HEAD)
default_ref=$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD || true)

if [ -z "$default_ref" ]; then
  for candidate in origin/main origin/master origin/develop; do
    if git show-ref --verify --quiet "refs/remotes/$candidate"; then
      default_ref="$candidate"
      break
    fi
  done
fi

if [ -z "$default_ref" ]; then
  echo "Unable to resolve default remote branch" >&2
  exit 1
fi

merge_base=$(git merge-base HEAD "$default_ref")
```

Review range for committed branch changes is always:

```bash
git diff "${merge_base}...HEAD"
```

### 2) Collect Review Context (Each Iteration)

At the start of every loop iteration, gather:

```bash
git status --short
git diff --stat "${merge_base}...HEAD"
git diff "${merge_base}...HEAD"
git diff --cached
git diff
```

### 3) Spawn Reviewer Subagent

Use Task with `subagent_type="reviewer-gpt5.2"` for every iteration.

Pass this review brief to the subagent, filling in the current values of `merge_base` and `default_ref`:

```text
You are a code reviewer. Your job is to review code changes and provide actionable feedback.

Review scope (branch-only):
- committed branch diff: git diff <merge_base>...HEAD
- staged diff: git diff --cached
- unstaged diff: git diff
- untracked files from git status --short

Important scope guardrails:
- Review only the changes listed above.
- Do not switch to a separate base diff such as origin/main...HEAD unless that exact ref came from the resolved merge-base scope above.

Required method:
1. Use diffs to identify changed files.
2. Read full file contents for every changed file and untracked file before flagging issues.
3. Focus on bugs first, then structural problems, then obvious performance issues.
4. Only flag issues in changed code.
5. If uncertain, say what is uncertain instead of asserting.

Classify findings into:
- Quick fixes: small, local, high-confidence changes.
- Not quick: broader refactor, unclear intent, architecture/product decisions, or deeper investigation.
- Needs clarification: behavior-changing choice that cannot be inferred from repository context.

Return exactly this format:
Quick fixes:
- [Q1] <severity> <file[:line]> - <issue> - <smallest safe fix>

Not quick:
- [N1] <severity> <file[:line]> - <issue> - <why not quick>

Needs clarification:
- [C1] <question> - <why repository context is insufficient>
```

### 4) Apply Quick Fixes

From subagent output:

1. Apply all quick fixes that are small, local, and high confidence.
2. Keep edits minimal; do not introduce features or broad refactors.
3. If any fix requires a material behavior choice and the repo does not disambiguate it, ask exactly one targeted `question` and stop.

### 5) Loop Termination

Maximum 3 iterations.

- If zero quick fixes are found, stop and report remaining issues.
- If 3 iterations are completed, stop and report remaining issues even if more quick fixes may exist.
- Otherwise, repeat from Step 2.

### 6) Completion

When terminating, report:

- Brief summary of fixes applied.
- Remaining `Not quick` and `Needs clarification` issues.
