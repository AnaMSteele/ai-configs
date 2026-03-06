---
name: opencode-conversation-reviewer
description: Review and summarize recent OpenCode (opencode) sessions for the current directory/repo using `opencode db`. Use to answer "what has been done/changed", infer next steps from the last N conversations, and find dangling/unresolved threads via open todos, errors, or incomplete messages.
license: Complete terms in LICENSE.txt
---

# Opencode Conversation Reviewer

## Overview

Use `opencode db` to pull the recent session history for a directory, then synthesize it into a clear status update: what happened, what changed, what is still open, and what to do next.

Prefer the bundled helper script for a compact, repeatable digest. Fall back to SQL recipes if you need custom slices.

## Quick Start

1) Generate a digest for the current repo/directory:

```bash
python3 scripts/opencode_conversation_digest.py --limit 10
```

2) Target a specific directory (and include sessions created in subdirectories):

```bash
python3 scripts/opencode_conversation_digest.py --dir /path/to/repo --scope subtree --limit 20
```

3) Output JSON for downstream processing:

```bash
python3 scripts/opencode_conversation_digest.py --limit 10 --format json
```

## Workflow

### 1) Choose the target directory

- Default to the git repo root (via `git rev-parse --show-toplevel`) when available.
- Otherwise default to `pwd`.
- If the user says "for this subfolder" or "for this worktree", pass an explicit `--dir`.

### 2) Pull the last N sessions (token-efficient)

Run the helper script and keep it small:

- Start with `--limit 10`.
- Prefer `--scope subtree` if the user runs opencode from subdirectories.
- Prefer `--format json` if you need to post-process or diff programmatically.

### 3) Synthesize an answer from the digest

Focus on what the user asked:

- "What has been done?" -> enumerate completed outcomes, changes (files/+/-), and the final assistant outputs.
- "Where are we at / what next?" -> list open todos, dangling sessions, and concrete next actions.
- "Workflow/tooling improvements?" -> look for repeated friction: recurring errors, repeated manual steps, repeated rework, missing validation steps.

## Heuristics: Spotting Dangling Threads

Treat a session as potentially unresolved if any of these are true:

- Open todos exist in `todo` (status not in `completed` or `cancelled`).
- The latest assistant message has an `error` field.
- The latest message lacks `time.completed` (often indicates an interrupted run).

When in doubt, open the specific session (pull more parts) rather than guessing.

## Output Template (Recommended)

Write answers in a stable structure so the user can scan quickly:

- Recent work (last N sessions): 1 line per session with outcome
- Open loops: todos + "dangling" sessions + why they look unresolved
- Next steps: 3-7 concrete actions, ordered
- Workflow/tooling opportunities: 3-5 evidence-backed ideas tied to repeated pain

## Resources

- `scripts/opencode_conversation_digest.py` - Generate a compact digest via `opencode db`
- `references/sql_recipes.md` - Manual queries (sessions/messages/parts/todos)
