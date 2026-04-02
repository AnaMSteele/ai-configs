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
doct-cli auth status
```

2. Publish the plan with REST by:
- resolving the personal workspace id
- ensuring a root document titled `Coding Plans` exists
- creating a new `text` document with `parentId` set to the `Coding Plans` document id

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
- Standard doct-cli device login is read-only. For publishing, set `DOCT_ACCESS_TOKEN` to a write-scope PAT if the current token lacks write access.
- If auth is missing, run `doct-cli auth login --url https://doct.nodaste.com` first.
- If the helper script is unavailable, perform the same steps manually with `doct-cli workspaces list --json`, `doct-cli docs list --workspace <id> --json`, and `POST /api/documents`.
