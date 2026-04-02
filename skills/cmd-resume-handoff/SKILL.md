---
name: cmd-resume-handoff
description: Resume work from a handoff document. Use when continuing work that was previously paused and documented.
---

# Resume From Handoff

Restore context and continue work from a previously created handoff document.

## Usage

```
/skill:cmd-resume-handoff [handoff-path-or-ticket]
```

## Process

### 1) Locate Handoff

If argument is:
- A path: read it directly
- A ticket key: find latest handoff in `thoughts/handoffs/[TICKET]/`

### 2) Read and Parse

Extract from handoff:
- Git commit and branch
- Current phase and progress
- Working files
- Open questions
- Next steps

### 3) Validate State

```bash
# Check current git state
git rev-parse HEAD
git branch --show-current
```

Compare with handoff:
- If commit differs, show diff since handoff
- If branch differs, suggest checkout
- Show current status vs handoff status

### 4) Restore Context

Present to user:
- Summary of where work left off
- What's changed since handoff (if anything)
- Recommended next steps
- Open questions needing resolution

### 5) Guide Next Steps

Suggest appropriate follow-up actions:
- Continue with current phase
- Address blockers first
- Resolve open questions
- Run verification commands
