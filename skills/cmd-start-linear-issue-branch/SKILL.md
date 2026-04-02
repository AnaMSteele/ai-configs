---
name: cmd-start-linear-issue-branch
description: Start a Linear issue on a new branch (no worktree) and draft a first-pass plan. Lightweight alternative to worktree approach.
---

# Start Linear Issue (Branch Only)

Start a Linear issue on a new branch without creating a worktree. Drafts a first-pass plan for quick startup.

## Prerequisites

Requires `ltui` configured. See AGENTS.md for ltui setup.

## Usage

```
/skill:cmd-start-linear-issue-branch <ISSUE_KEY>
```

## Process

### 1) Fetch Issue Details

```bash
ltui issues view <ISSUE_KEY> --format detail
```

### 2) Create and Checkout Branch

```bash
BRANCH="<ISSUE_KEY>-$(echo "<issue-title>" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd '[:alnum:]-')"
git checkout -b "$BRANCH"
```

### 3) Create Linear Notes File

Create `thoughts/linear/<ISSUE_KEY>.md` with:
- Issue metadata
- Acceptance criteria
- Initial notes
- Draft plan (first pass)

### 4) Report

- Branch name
- Linear notes file location
- Suggested next command (e.g., `/skill:dev-plan`)

## Notes

This is the lightweight alternative to `/skill:cmd-start-linear-issue` when worktrees are not needed or supported.
