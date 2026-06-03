---
name: cmd-start-linear-issue
description: Start work on a Linear issue with worktree-based branch management. Use ltui for Linear CLI interactions.
---

# Start Linear Issue

Bootstrap work on a Linear issue with worktree management. This creates a dedicated branch and worktree for isolated development.

## Prerequisites

Requires `ltui` from https://github.com/Nodaste-Lab/ltui configured:
```bash
brew tap Nodaste-Lab/ltui https://github.com/Nodaste-Lab/ltui
brew install Nodaste-Lab/ltui/ltui
ltui auth list
ltui teams list
```

## Usage

```
/skill:cmd-start-linear-issue <ISSUE_KEY>
```

Example: `/skill:cmd-start-linear-issue ENG-123`

## Process

### 1) Fetch Issue Details

```bash
ltui issues view <ISSUE_KEY> --format detail
```

### 2) Create Branch Name

Format: `{ISSUE_KEY}-slugified-title`

Example: `ENG-123-fix-login-bug`

### 3) Create Worktree (if supported)

If the repo uses git worktrees:
```bash
git worktree add -b <branch-name> ../<branch-name>
cd ../<branch-name>
```

Otherwise create branch only:
```bash
git checkout -b <branch-name>
```

### 4) Copy Local Config

If worktree created, copy relevant config:
- `.env` files (if safe)
- Local settings
- MCP server configs

### 5) Create Linear Notes File

Create `thoughts/linear/<ISSUE_KEY>.md` with:
- Issue details
- Acceptance criteria
- Notes from initial read

### 6) Report

- Branch name created
- Worktree location (if applicable)
- Next steps suggestion

## Integration

This command integrates with:
- ltui for Linear API access
- Git worktrees for isolation
- `thoughts/linear/` directory for notes
