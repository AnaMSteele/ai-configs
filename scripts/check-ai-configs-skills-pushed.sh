#!/usr/bin/env bash
set -euo pipefail

repo="${AI_CONFIGS_REPO:-/Users/anasteele/code/ai-configs}"

if [ ! -d "$repo/.git" ]; then
  exit 0
fi

cd "$repo"

dirty_skills=false
if ! git diff --quiet -- skills || ! git diff --cached --quiet -- skills || [ -n "$(git ls-files --others --exclude-standard skills)" ]; then
  dirty_skills=true
fi

unpushed_skill_commits=false
if upstream="$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null)"; then
  while IFS= read -r commit; do
    if git diff-tree --no-commit-id --name-only -r "$commit" -- skills | grep -q .; then
      unpushed_skill_commits=true
      break
    fi
  done < <(git rev-list "${upstream}..HEAD" 2>/dev/null)
fi

if [ "$dirty_skills" = true ] || [ "$unpushed_skill_commits" = true ]; then
  cat >&2 <<'JSON'
{"decision":"block","reason":"ai-configs skill changes are not complete until they are committed and pushed. Run `save-ai-configs-skills` from any directory, or commit/push the skill changes manually, then finish the response."}
JSON
  exit 2
fi

exit 0
