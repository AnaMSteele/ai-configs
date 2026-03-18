---
name: review-change-integrate
description: Apply fixes from review findings. Works with review-change output to address issues systematically.
---

# Review Change - Integrate Fixes

Apply fixes based on review findings from `/skill:review-change`. Addresses issues systematically.

## Usage

```
/skill:review-change-integrate [review-file-path]
```

If no review file provided, looks for most recent review in `thoughts/validation/`.

## Process

### 1. Load Review Findings

If review file provided:
```bash
# Read the review file
cat [review-file-path]
```

Otherwise find most recent:
```bash
ls -t thoughts/validation/*.md | head -1
```

### 2. Prioritize Issues

Sort issues by:
1. **Critical** (security, data loss, crashes)
2. **Important** (performance, correctness)
3. **Minor** (style, optimizations)

### 3. Create Fix Plan

Generate task list from issues:

```markdown
## Fix Tasks

### Critical
- [ ] Fix [issue description] in `file:line`
- [ ] Fix [issue description] in `file:line`

### Important
- [ ] Fix [issue description] in `file:line`

### Minor (optional)
- [ ] Fix [issue description] in `file:line`
```

### 4. Execute Fixes

For each critical/important issue:

1. **Read** the affected code fully
2. **Understand** the problem from review
3. **Implement** the fix
4. **Verify** with appropriate tests/commands

Use `subagent` with `developer` agent for parallel fixes when safe.

### 5. Update Review Status

After addressing issues:

```markdown
---
date: [original timestamp]
updated: [current timestamp]
branch: [branch name]
type: review
status: [resolved|partially-resolved]
---

# Code Review: [Branch/Scope]

## Original Findings
[Link to original or summary]

## Resolution Status

### Critical Issues
- [x] [Issue 1] - Fixed in commit [sha]
- [x] [Issue 2] - Fixed in commit [sha]

### Important Issues
- [x] [Issue 3] - Fixed in commit [sha]
- [ ] [Issue 4] - Deferred: [reason]

## Summary
[What was fixed, what remains, any trade-offs made]
```

### 6. Report Results

- Issues fixed vs deferred
- Commits created
- Recommendation for next review

## Safety Guidelines

- Only fix issues you fully understand
- When in doubt, ask the user
- Run tests after each critical fix
- Commit incrementally for easy rollback

## Integration

Part of the review workflow:
1. `/skill:review-change` - Find issues
2. `/skill:review-change-integrate` - Fix issues
3. `/skill:cmd-commit-push` - Save fixes
