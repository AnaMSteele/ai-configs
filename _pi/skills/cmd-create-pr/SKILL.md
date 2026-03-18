---
name: cmd-create-pr
description: Create a GitHub pull request from the current branch using gh CLI. Use when ready to submit code for review.
---

# Create Pull Request

Create a GitHub PR for the current branch using `gh`.

## Usage

```
/skill:cmd-create-pr [BASE_REF]
```

If BASE_REF is omitted, prefers `origin/develop` if it exists; otherwise uses `origin/main`.

## Process

### 1) Resolve Base

Resolve `base_ref`:

- If arguments provided: use them
- Else use `origin/develop` if it exists
- Else use `origin/main`

Verify base exists:
```bash
git rev-parse --verify "${base_ref}^{commit}"
```

### 2) Check for Existing PR

```bash
BRANCH="$(git rev-parse --abbrev-ref HEAD)"
gh pr list --head "$BRANCH" --json number,title,url --limit 1
```

If a PR already exists, report the URL and STOP.

### 3) Prepare Title and Evidence

```bash
TITLE="$(git log -1 --format=%s)"
git log --oneline "${base_ref}...HEAD"
git diff --stat "${base_ref}...HEAD"
```

### 4) Create PR

```bash
BASE_NAME="${base_ref#origin/}"
BRANCH="$(git rev-parse --abbrev-ref HEAD)"
TITLE="$(git log -1 --format=%s)"

gh pr create \
  --base "$BASE_NAME" \
  --head "$BRANCH" \
  --title "$TITLE" \
  --body "## Summary
- (fill from commits / plan)

## Verification
- (commands run)

## Notes
- (links / caveats)"
```

After creation, print the PR URL.

Note: squash-vs-merge is typically configured at merge time; `gh pr create` does not enforce squash on its own.
