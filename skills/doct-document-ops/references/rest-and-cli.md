# Doct REST and CLI reference

Use this reference for auth, workspace discovery, document lookup, listing, read-only inspection, and REST-safe metadata operations.

## 1. CLI

Use the actual `doct-agent` executable on PATH. The former standalone Node CLI package was removed from the current doct repo; its operational surfaces are consolidated under `doct-agent`.

```bash
doct-agent --help
doct-agent auth status --all --json
doct-agent workspaces list --json
```

Overrides:
- `DOCT_BASE_URL`
- `DOCT_AGENT_PAT` with an explicit base URL for one-off automation

## 2. Auth

### Agent login

```bash
doct-agent auth login --base-url https://doct.nodaste.com
doct-agent auth login --base-url https://doct.develop.nodaste.com
```

### Validate current auth

```bash
doct-agent auth status --all --json
doct-agent auth status --base-url https://doct.nodaste.com --json
```

`doct-agent` stores registrations by canonical endpoint origin under the platform config directory, with endpoint-specific token files. It also discovers and persists the websocket URL after auth.

Important: if `auth status` reports an invalid or expired token, re-auth that endpoint with `doct-agent auth login --base-url <endpoint>` or import a valid PAT with `doct-agent auth import-pat --base-url <endpoint> --token <token>`.

## 3. Workspace discovery

```bash
doct-agent workspaces list --json
```

Use this when the user only knows the doc title/path loosely and you need a workspace id first.

## 4. List documents in a workspace

```bash
doct-agent documents list --workspace-id <workspace-id> --json
```

This calls:

```text
GET /api/documents/tree?workspaceId=<workspace-id>&includeContent=0
```

Good for:
- finding a path
- confirming the document id
- narrowing ambiguous user instructions

## 5. View a document by workspace + path

Plain text body for text docs:

```bash
doct-agent documents get --workspace-id <workspace-id> --path '<doc-path>' --text
```

Full JSON payload / metadata:

```bash
doct-agent documents get --workspace-id <workspace-id> --path '<doc-path>' --json
```

## 6. View a document by id

JSON:

```bash
doct-agent documents get --id <document-id> --json
```

Plain markdown for text docs:

```bash
doct-agent documents get --id <document-id> --text
```

## 7. Resolve a doct URL

Doct document URLs typically look like:

```text
https://doct.nodaste.com/d/<workspace-handle>/docs/<document-id>
https://doct.develop.nodaste.com/d/<workspace-handle>/docs/<document-id>
```

Workflow:

1. Parse `<document-id>` from `/docs/<uuid>`.
2. Fetch `doct-agent documents get --id <document-id> --json`.
3. Use the response to recover title, path, workspaceId, and kind.
4. For text content, follow up with `doct-agent documents get --id <document-id> --text` if you need the rendered markdown body.

## 8. REST-safe metadata operations

Prefer `doct-agent` where it exposes a command. The raw REST examples below are fallback patterns for supported metadata/comment routes that are not yet exposed through the CLI; they require `DOCT_BASE_URL` and `DOCT_AGENT_PAT`.

### Create a document

```bash
doct-agent documents create \
  --workspace-id <workspace-id> \
  --title "New doc" \
  --path "notes/new-doc" \
  --kind text \
  --content "Initial content" \
  --json
```

Note: creating a new text doc through `doct-agent documents create` is published by default. Use `--status draft` only when the user explicitly wants a hidden draft.

### Replace a full text document body

```bash
doct-agent documents replace-body --id <document-id> --file prepared.md --json
```

Use this for whole-body text replacement. It goes through the supported server path and returns verified readback metadata.

### Update document metadata by id

Use `PUT /api/documents/[id]` for title/status and other metadata that is not a text-body change.

```bash
curl -sS -X PUT "$DOCT_BASE_URL/api/documents/<document-id>" \
  -H "Authorization: Bearer $DOCT_AGENT_PAT" \
  -H "X-Doct-Pat: Bearer $DOCT_AGENT_PAT" \
  -H 'Content-Type: application/json' \
  -d '{
    "title": "Renamed title"
  }'
```

### Rename / move

Use the dedicated rename/move endpoints rather than trying to change `path`, `parentId`, or `displayOrder` through the generic document route.
Search the doct repo routes if you need the exact variant for the current install:

```bash
cd /Users/anasteele/Documents/GitHub/doct
rg -n "rename|move" app/\(chat\)/api/documents -g 'route.ts'
```

## 9. Comments

### Non-text documents

Allowed over REST:

```bash
curl -sS -X POST "$DOCT_BASE_URL/api/documents/comments" \
  -H "Authorization: Bearer $DOCT_AGENT_PAT" \
  -H "X-Doct-Pat: Bearer $DOCT_AGENT_PAT" \
  -H 'Content-Type: application/json' \
  -d '{
    "path": "artifacts/example",
    "workspaceId": "<workspace-id>",
    "comments": [{
      "id": "<uuid>",
      "text": "Looks good",
      "selectedText": "",
      "content": "",
      "createdAt": "<iso8601>",
      "replies": []
    }]
  }'
```

### Text documents

Do **not** use the REST comments route.
It returns `410 COMMENT_SYNC_DEPRECATED` for text docs.
Use realtime/Yjs instead. See `text-doc-realtime.md`.

## 10. Important guardrails

- Raw `POST /api/documents` and `PUT /api/documents/[id]` reject unsupported **text body updates** with `410`; prefer `doct-agent documents replace-body`.
- `POST /api/documents/comments` rejects **text doc comments** with `410`.
- `GET /api/documents/[id]/comments` returns `410` for text docs.
- `GET /api/documents/with-comments` is fine for metadata/content-source checks, but does not give you usable text-doc comments.

## 11. Quick triage commands

If something is failing, these are the first checks:

```bash
doct-agent auth status --all --json
doct-agent workspaces list --json
doct-agent documents list --workspace-id <workspace-id> --json
doct-agent documents get --id <document-id> --json
doct-agent triage run db preview --json
```
