---
description: Bootstrap a dedicated OpenCode workspace and branch for a Linear issue
argument-hint: "ISSUE_KEY [BASE_BRANCH]"
---

Create an OpenCode workspace for a Linear issue. This uses OpenCode's workspace registry first so the issue build appears in the workspace picker, then creates or reuses the workspace-backed git worktree. For full deterministic execution, hand off to `/cmd:linear-build-workspace`, which initializes an enforced run ledger with `linear_build_orchestrator.py`.

**Arguments**: $ARGUMENTS

## Instructions

1. Parse the arguments:
   - First argument: `ISSUE_KEY` (required) - e.g., `NOD-123`
   - Second argument: `BASE_BRANCH` (optional) - defaults to `origin/main`

2. If no arguments provided, respond with usage:
   ```
   Usage: /cmd:start-linear-issue ISSUE_KEY [BASE_BRANCH]

   Examples:
     /cmd:start-linear-issue NOD-123
     /cmd:start-linear-issue NOD-123 origin/develop
   ```

3. Fetch Linear issue metadata:

```bash
mkdir -p .opencode/tmp
ltui --format json --fields identifier,title,url,state,project \
  issues view "${ISSUE_KEY}" --no-attachment-probe > ".opencode/tmp/${ISSUE_KEY}.json"
```

4. Create or reuse the OpenCode workspace:

```bash
ISSUE_TITLE="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("title", ""))' ".opencode/tmp/${ISSUE_KEY}.json")"

python3 "$HOME/.config/opencode/scripts/create_linear_workspace.py" \
  "${ISSUE_KEY}" \
  --base-ref "${BASE_BRANCH:-origin/main}" \
  --title "${ISSUE_TITLE}" \
  --repo "$(git rev-parse --show-toplevel)" \
  > ".opencode/tmp/${ISSUE_KEY}-workspace.json"
```

5. Verify the workspace exists in OpenCode, not only in `git worktree list`:

```bash
WORKSPACE_ID="$(python3 -c 'import re,sys; print("wrk_" + re.sub(r"[^a-z0-9]+", "_", sys.argv[1].lower()).strip("_"))' "${ISSUE_KEY}")"
opencode db "select id,type,branch,directory from workspace where id = '${WORKSPACE_ID}'" --format json
```

If the workspace row is missing, stop and report `BLOCKED_WORKSPACE_NOT_REGISTERED`.

6. Report the workspace id and directory from `.opencode/tmp/${ISSUE_KEY}-workspace.json`.

For full deterministic issue execution, continue with:

```text
/cmd:linear-build-workspace ${ISSUE_KEY} ${BASE_BRANCH:-origin/main}
```

Legacy behavior below is retired and should not be used for new Linear builds:

```
Task(
  subagent_type="worktree-creator",
  description="Create git worktree for Linear issue",
  prompt=f"""Create a git worktree for Linear issue {ISSUE_KEY}.

Base branch: {BASE_BRANCH:-origin/main}

Follow the worktree-creator agent instructions precisely."""
)
```

Do not use a plain worktree-only flow unless the user explicitly asks for it.
