#!/usr/bin/env bash
set -euo pipefail

repo="${AI_CONFIGS_REPO:-/Users/anasteele/code/ai-configs}"
expected_origin="${AI_CONFIGS_ORIGIN_URL:-https://github.com/AnaMSteele/ai-configs.git}"

if [ ! -d "$repo/.git" ]; then
  exit 0
fi

cd "$repo"

origin_url="$(git remote get-url origin 2>/dev/null || true)"
if [ "$origin_url" != "$expected_origin" ]; then
  cat >&2 <<JSON
{"decision":"block","reason":"ai-configs origin must point at Ana's repo before work is complete. Expected ${expected_origin}, found ${origin_url:-<missing>}. Fix with: git remote set-url origin ${expected_origin}"}
JSON
  exit 2
fi

dirty_repo=false
if ! git diff --quiet || ! git diff --cached --quiet || [ -n "$(git ls-files --others --exclude-standard)" ]; then
  dirty_repo=true
fi

unpushed_commits=false
if tracking_ref="$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null)"; then
  while IFS= read -r commit; do
    if git diff-tree --no-commit-id --name-only -r "$commit" | grep -q .; then
      unpushed_commits=true
      break
    fi
  done < <(git rev-list "${tracking_ref}..HEAD" 2>/dev/null)
else
  unpushed_commits=true
fi

if [ "$dirty_repo" = true ] || [ "$unpushed_commits" = true ]; then
  cat >&2 <<'JSON'
{"decision":"block","reason":"ai-configs local changes are not complete until they are committed and pushed to Ana's origin repo. Run `save-ai-configs-local-changes \"message\"`, or commit/push manually, then finish the response."}
JSON
  exit 2
fi

exit 0
