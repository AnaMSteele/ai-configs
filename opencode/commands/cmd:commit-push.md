---
description: Commit all changes in the repo and push to GitHub
argument-hint: '["commit subject"]'
---

# Commit + Push (All Changes)

Commit ALL current working tree changes on the current branch and push to the tracked remote.

## Input

Optional commit subject: `$ARGUMENTS`.

If omitted, generate a default from the branch name (and an inferred Linear issue key if present).

## Preconditions

1) Must not be on a protected branch:

```bash
git rev-parse --abbrev-ref HEAD
```

If on `main`, `master`, or `develop`, STOP and ask the user to switch to a feature branch.

2) Must have something to commit:

```bash
git status --porcelain=v1
```

If empty, STOP (nothing to do).

3) Secret hygiene (conservative):

If `git status` includes files matching `.env*`, `*.pem`, `*.key`, `credentials*.json`, or `*.p12`, STOP and ask before staging.

## Process

### 1) Stage Everything

```bash
git add -A
git diff --cached --stat
```

### 2) Build Commit Subject

If `$ARGUMENTS` provided, use it.

Else generate:

```bash
BRANCH="$(git rev-parse --abbrev-ref HEAD)"
ISSUE_KEY="$(python3 -c 'import re,sys; b=sys.argv[1]; m=re.search(r"([A-Za-z]+-\\d+)", b); print(m.group(1).upper() if m else "")' "$BRANCH")"

if [ -n "$ISSUE_KEY" ]; then
  COMMIT_SUBJECT="feat: ${ISSUE_KEY} ${BRANCH}"
else
  COMMIT_SUBJECT="feat: ${BRANCH}"
fi
```

### 3) Commit

```bash
git commit -m "$COMMIT_SUBJECT"
```

If commit fails due to hooks, fix issues and create a NEW commit (do not amend unless explicitly requested).

### 4) Push

```bash
BRANCH="$(git rev-parse --abbrev-ref HEAD)"

if git rev-parse --abbrev-ref --symbolic-full-name "@{u}" >/dev/null 2>&1; then
  git push
else
  git push -u origin "$BRANCH"
fi
```

### 5) Output

Report:

- Branch name
- Commit SHA (`git rev-parse HEAD`)
- Remote tracking status (`git status -sb`)
