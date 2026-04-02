---
name: cmd-create-handoff
description: Create a context-preserving handoff document for transferring work between agents or sessions. Use when pausing work or switching contexts.
---

# Create Handoff Document

Generate a handoff document to preserve context when transferring work between agents or sessions.

## Usage

```
/skill:cmd-create-handoff [description]
```

## Output

Creates: `thoughts/handoffs/[TICKET]/YYYY-MM-DD_HH-MM-SS_[description].md`

## Process

### 1) Gather Context

Collect current state:
```bash
# Current git state
git rev-parse HEAD
git branch --show-current
git status --short

# Recent commits
git log --oneline -5
```

### 2) Capture Working State

Document:
- Current task/phase being worked on
- Files currently being modified (from git status)
- Open questions or blockers
- Recent decisions made
- Next steps identified

### 3) Generate Handoff Document

Template:

```markdown
---
date: [YYYY-MM-DD HH:MM:SS]
author: [current agent/user]
git_commit: [hash]
branch: [branch name]
ticket: [issue key if applicable]
type: handoff
status: active
---

# Handoff: [Description]

## Current Context
[What was being worked on]

## Progress Status
- Phase: [current phase]
- Completed: [what's done]
- In Progress: [what's currently being worked on]
- Blocked: [any blockers]

## Working Files
[Files with uncommitted changes]
```
[git status output]
```

## Open Questions
[Questions needing answers]

## Next Steps
[What should be done next]

## Notes
[Any additional context]
```

### 4) Report

- Handoff file location
- Key context preserved
