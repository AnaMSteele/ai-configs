#!/usr/bin/env bash
set -euo pipefail

repo="${AI_CONFIGS_REPO:-/Users/anasteele/code/ai-configs}"
message="${1:-Save ai-configs skill updates}"

cd "$repo"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Not a Git checkout: $repo" >&2
  exit 1
fi

if git diff --quiet -- skills && git diff --cached --quiet -- skills && [ -z "$(git ls-files --others --exclude-standard skills)" ]; then
  echo "No skill changes to save."
  exit 0
fi

git add skills

if git diff --cached --quiet -- skills; then
  echo "No staged skill changes after git add."
  exit 0
fi

git commit -m "$message"
branch="$(git branch --show-current)"
if [ -z "$branch" ]; then
  echo "Cannot push from detached HEAD." >&2
  exit 1
fi

git push -u origin "$branch"
echo "Skill changes committed and pushed on $branch."
