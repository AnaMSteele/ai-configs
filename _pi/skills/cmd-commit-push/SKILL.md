---
name: cmd-commit-push
description: Commit all changes in the repo and push to GitHub. Use when you need to save work and push to remote.
---

# Commit and Push

Commit ALL current working tree changes on the current branch and push to the tracked remote.

## Usage

```
/skill:cmd-commit-push [commit subject]
```

If no commit subject is provided, one will be generated from the branch name (and an inferred Linear issue key if present).

## Preconditions

### 1) Check Branch Protection

```bash
git rev-parse --abbrev-ref HEAD
```

If on `main`, `master`, or `develop`, STOP and ask the user to switch to a feature branch.

### 2) Check for Changes

```bash
git status --porcelain=v1
```

If empty, STOP (nothing to do).

### 3) Secret Hygiene

If `git status` includes files matching `.env*`, `*.pem`, `*.key`, `credentials*.json`, or `*.p12`, STOP and ask before staging.

## Process

### 1) Stage Everything

```bash
git add -A
git diff --cached --stat
```

### 2) Build Commit Subject

If user provided arguments, use them as the commit subject.

Otherwise generate:

```bash
BRANCH="$(git rev-parse --abbrev-ref HEAD)"
# Extract issue key (e.g., ENG-123) from branch name
python3 -c 'import re,sys; b=sys.argv[1]; m=re.search(r"([A-Za-z]+-\d+)", b); print(m.group(1).upper() if m else "")' "$BRANCH"
```

If issue key found:
```
feat: {ISSUE_KEY} {BRANCH}
```

Otherwise:
```
feat: {BRANCH}
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

### 5) Report Results

- Branch name
- Commit SHA (`git rev-parse HEAD`)
- Remote tracking status (`git status -sb`)
