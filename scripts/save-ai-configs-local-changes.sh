#!/usr/bin/env bash
set -euo pipefail

repo="${AI_CONFIGS_REPO:-/Users/anasteele/code/ai-configs}"
expected_origin="${AI_CONFIGS_ORIGIN_URL:-https://github.com/AnaMSteele/ai-configs.git}"
message="${1:-Save ai-configs local updates}"

cd "$repo"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Not a Git checkout: $repo" >&2
  exit 1
fi

origin_url="$(git remote get-url origin 2>/dev/null || true)"
if [ "$origin_url" != "$expected_origin" ]; then
  echo "origin must point at Ana's repo before saving changes." >&2
  echo "expected: $expected_origin" >&2
  echo "found: ${origin_url:-<missing>}" >&2
  exit 1
fi

if git diff --quiet && git diff --cached --quiet && [ -z "$(git ls-files --others --exclude-standard)" ]; then
  echo "No ai-configs changes to save."
  exit 0
fi

git add -A

if git diff --cached --quiet; then
  echo "No staged changes after git add."
  exit 0
fi

git commit -m "$message"
branch="$(git branch --show-current)"
if [ -z "$branch" ]; then
  echo "Cannot push from detached HEAD." >&2
  exit 1
fi

git push -u origin "$branch"
echo "ai-configs changes committed and pushed to origin/$branch."
