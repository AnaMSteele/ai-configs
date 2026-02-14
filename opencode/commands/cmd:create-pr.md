---
description: Create a GitHub pull request from the current branch
argument-hint: '[BASE_REF]'
---

# Create Pull Request

Create a GitHub PR for the current branch using `gh`.

## Input

Optional `BASE_REF`: `$ARGUMENTS`.

If omitted, prefer `origin/develop` if it exists; otherwise use `origin/main`.

## Process

### 1) Resolve Base

Resolve `base_ref`:

- If `$ARGUMENTS` provided: use it.
- Else:
  - Use `origin/develop` if it exists
  - Else use `origin/main`

Verify base exists:

```bash
git rev-parse --verify "${base_ref}^{commit}"
```

### 2) Resolve Head + Check Existing PR

```bash
BRANCH="$(git rev-parse --abbrev-ref HEAD)"

gh pr list --head "$BRANCH" --json number,title,url --limit 1
```

If a PR already exists, report the URL and STOP.

### 3) Prepare Title + Evidence

```bash
TITLE="$(git log -1 --format=%s)"

git log --oneline "${base_ref}...HEAD"
git diff --stat "${base_ref}...HEAD"
```

### 4) Create PR

```bash
# Ensure base_ref is set (if you didn't set it earlier, set it now).
if [ -n "$1" ]; then
  base_ref="$1"
elif git rev-parse --verify "origin/develop^{commit}" >/dev/null 2>&1; then
  base_ref="origin/develop"
else
  base_ref="origin/main"
fi

BASE_NAME="${base_ref#origin/}"
BRANCH="$(git rev-parse --abbrev-ref HEAD)"
TITLE="$(git log -1 --format=%s)"

gh pr create \
  --base "$BASE_NAME" \
  --head "$BRANCH" \
  --title "$TITLE" \
  --body "$(cat <<'EOF'
## Summary
- (fill from commits / plan)

## Verification
- (commands run)

## Notes
- (links / caveats)
EOF
)"
```

After creation, print the PR URL.

Note: squash-vs-merge is typically configured at merge time; `gh pr create` does not enforce squash on its own.
