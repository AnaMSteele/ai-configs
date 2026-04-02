---
name: doct-document-ops
description: Interact with doct documents via doct-cli, REST, and Hocuspocus/Yjs. Use when asked to open a doct URL, list doct workspaces or documents, view a doct document, edit doct document metadata, edit a doct text document body, add or inspect comments in doct, or publish a coding plan to the user's personal "Coding Plans" document as a child document.
---

# Doct document operations

Use this skill when the user wants work done **inside doct itself** rather than only in local markdown files.

## Default approach

1. Resolve the target document or destination.
2. Resolve auth.
3. Choose the correct write path:
   - **View/list/lookup** → doct-cli or REST.
   - **Metadata-only updates** (title, rename, move, settings) → REST.
   - **Text body edits** → realtime Hocuspocus/Yjs only.
   - **Text comments** → realtime Hocuspocus/Yjs only.
   - **Publish a coding plan** → use `scripts/publish-coding-plan.sh`.

## Special default: coding plans

If the user asks to **send, publish, copy, or save a coding plan to doct**, default to this destination unless they explicitly say otherwise:

- workspace: the user's **personal** doct workspace
- parent document title: **Coding Plans**
- new document type: **text**
- placement: create the new plan as a **child document** under `Coding Plans`

### Coding-plan workflow

1. If the plan is in a local file, read it fully first.
2. If the user pasted the plan, preserve the markdown as given.
3. Derive a title from the first H1 if possible; otherwise use the file basename or ask if the title matters.
4. Run:

```bash
bash "$SKILL_DIR/scripts/publish-coding-plan.sh" --file /absolute/or/relative/path/to/plan.md
```

Or, when the content is already in a temp file / stdin pipeline:

```bash
printf '%s' "$PLAN_MARKDOWN" | bash "$SKILL_DIR/scripts/publish-coding-plan.sh" --title "Plan Title"
```

5. Return the created doct URL and document id to the user.

The publisher script automatically:
- validates doct auth
- finds the personal workspace
- ensures the root document `Coding Plans` exists
- creates the new child document beneath it
- surfaces a clear hint when the current token is read-only

## Resolve the target first

Accept any of these inputs:
- Full doct URL
- Document id
- Workspace id + document path
- Workspace id + title/path discovered by listing

If the user gives a doct URL, extract the document id from `/docs/<uuid>` and then fetch the document by id.

If the target is still ambiguous, ask for exactly one missing locator: document URL, document id, or workspace+path.

## Auth workflow

Prefer existing doct auth first.

### Fast path

Use the actual `doct-cli` executable:

```bash
doct-cli auth status
```

If not logged in, start device auth:

```bash
doct-cli auth login --url https://doct.nodaste.com
# or develop:
doct-cli auth login --url https://doct.develop.nodaste.com
```

The CLI stores base URL and PAT in `~/.config/doct-cli/config.json`.

Important: the standard doct-cli device flow currently mints a **read-only** PAT. Read/list/view operations work with that token, but publishing a coding plan requires a **write-scope** PAT (for example via `DOCT_ACCESS_TOKEN`).

### Environment overrides

Use these when needed:
- `DOCT_BASE_URL`
- `DOCT_ACCESS_TOKEN`

## Read operations

For common read/list tasks, use the actual `doct-cli` executable:

```bash
doct-cli workspaces list --json
doct-cli docs list --workspace <workspace-id> --json
doct-cli docs view --workspace <workspace-id> --path '<doc-path>'
doct-cli docs view --workspace <workspace-id> --path '<doc-path>' --json
```

If the user provides a document id instead of a path, use REST directly:

```bash
curl -sS "$DOCT_BASE_URL/api/documents?id=<document-id>" \
  -H "Authorization: Bearer $DOCT_ACCESS_TOKEN" \
  -H "X-Doct-Pat: Bearer $DOCT_ACCESS_TOKEN"

curl -sS "$DOCT_BASE_URL/api/documents?id=<document-id>" \
  -H "Authorization: Bearer $DOCT_ACCESS_TOKEN" \
  -H "X-Doct-Pat: Bearer $DOCT_ACCESS_TOKEN" \
  -H 'Accept: text/plain'
```

Read `references/rest-and-cli.md` for exact lookup/read patterns.

## Write operations

### Metadata-only changes

Safe over REST:
- create document
- rename document
- move document
- update title/status/settings/theme
- add comments to **non-text** documents
- create child documents under `Coding Plans`

### Text body edits

Do **not** send text document content through `POST /api/documents` or `PUT /api/documents/[id]`.
Those routes intentionally return `410` for text body writes.

For text body edits, use the realtime path described in `references/text-doc-realtime.md`:
- connect with PAT over Hocuspocus
- wait for sync
- apply markdown into the Yjs doc
- optionally create a named version after the edit

### Text comments

Do **not** use `POST /api/documents/comments` for text documents.
That route intentionally returns `410` for text docs.

For text comments, use the realtime path in `references/text-doc-realtime.md`:
- sync the Yjs doc
- build an anchored quote with `createCommentAnchor` or `createCommentAnchorFromQuote`
- add the thread to the Yjs comments array

### Existing comments on text docs

Public REST routes intentionally do not expose text-doc comments cleanly:
- `GET /api/documents/[id]/comments` returns `410` for text docs
- `GET /api/documents/with-comments` reports `contentSource: yjs` but does not return text comments

If the user wants to inspect existing text comments, prefer:
1. doct UI/browser automation, or
2. repo-local doct internals / DB-backed investigation if direct API visibility is insufficient.

## Decision rules

- Use doct-cli for quick listing and path-based viewing.
- Use REST when the operation is explicitly supported and not a text-body mutation.
- Use Hocuspocus/Yjs for text edits and text comments.
- Use `scripts/publish-coding-plan.sh` for the default coding-plan destination.
- If the user wants visual verification inside doct, use browser automation after approval.

## References

- `references/rest-and-cli.md` — auth, lookup, list, view, metadata-safe REST patterns
- `references/text-doc-realtime.md` — exact realtime edit/comment workflow for text docs
- `scripts/publish-coding-plan.sh` — creates a child doc under personal `Coding Plans`
