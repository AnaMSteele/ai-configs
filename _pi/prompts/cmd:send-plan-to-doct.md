---
description: Publish a coding plan to doct under the personal Coding Plans document
argument-hint: "[plan file path or short description]"
---

# Send Coding Plan to Doct

Publish a coding plan into doct as a **child document** under the root document **Coding Plans** in the user's **personal** workspace.

Request: $ARGUMENTS

## Required behavior

- Prefer the `doct-document-ops` skill if it is available.
- If `$ARGUMENTS` looks like a local file path, read that file **fully** before publishing.
- If the user pasted the plan inline, preserve the markdown exactly.
- Default destination unless the user explicitly overrides it:
  - workspace: personal
  - parent title: `Coding Plans`
  - kind: `text`
  - placement: child document under `Coding Plans`

## Publish flow

1. Verify doct auth:

```bash
doct-agent auth status --all --json
```

2. Publish the plan with `doct-agent` by:
- resolving the personal workspace id
- ensuring a root document titled `Coding Plans` exists
- creating a new published `text` document with `parentId` set to the `Coding Plans` document id
- replacing the body with `doct-agent documents replace-body --file`

Preferred helper when this repo is installed:

```bash
bash "$HOME/.agents/skills/doct-document-ops/scripts/publish-coding-plan.sh" --file "$ARGUMENTS"
```

If the plan is not already in a file, write the markdown to a temp file first or pipe it on stdin:

```bash
printf '%s' "$PLAN_MARKDOWN" | bash "$HOME/.agents/skills/doct-document-ops/scripts/publish-coding-plan.sh" --title "Plan Title"
```

3. Return to the user:
- created doct title
- document id
- doct URL

## Notes

- The helper script auto-creates the root `Coding Plans` document if it does not already exist.
- New plans are created as child documents, not appended into the parent body.
- If auth is missing or invalid, run `doct-agent auth login --base-url https://doct.nodaste.com` first.
- For one-off automation, use `DOCT_AGENT_PAT` only with an explicit endpoint such as `DOCT_BASE_URL`.
- If the helper script is unavailable, perform the same steps manually with `doct-agent workspaces list --json`, `doct-agent documents list --workspace-id <id> --json`, `doct-agent documents create ... --json`, and `doct-agent documents replace-body --id <id> --file <file> --json`.
