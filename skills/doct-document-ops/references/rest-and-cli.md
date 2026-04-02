# Doct REST and CLI reference

Use this reference for auth, workspace discovery, document lookup, listing, read-only inspection, and REST-safe metadata operations.

## 1. CLI

Use the actual `doct-cli` executable on PATH:

```bash
doct-cli --help
doct-cli auth status
doct-cli workspaces list --json
```

Overrides:
- `DOCT_BASE_URL`
- `DOCT_ACCESS_TOKEN`

## 2. Auth

### Device login

```bash
doct-cli auth login --url https://doct.nodaste.com
doct-cli auth login --url https://doct.develop.nodaste.com
```

### Validate current auth

```bash
doct-cli auth status
```

Config lives at:

```text
~/.config/doct-cli/config.json
```

Important: the standard doct-cli device flow currently mints a read-only PAT. That is enough for discovery and document reads, but metadata writes like creating a new coding-plan child document require a write-scope PAT supplied separately (for example through `DOCT_ACCESS_TOKEN`).

## 3. Workspace discovery

```bash
doct-cli workspaces list --json
```

Use this when the user only knows the doc title/path loosely and you need a workspace id first.

## 4. List documents in a workspace

```bash
doct-cli docs list --workspace <workspace-id> --json
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
doct-cli docs view --workspace <workspace-id> --path '<doc-path>'
```

Full JSON payload / metadata:

```bash
doct-cli docs view --workspace <workspace-id> --path '<doc-path>' --json
```

## 6. View a document by id

JSON:

```bash
curl -sS "$DOCT_BASE_URL/api/documents?id=<document-id>" \
  -H "Authorization: Bearer $DOCT_ACCESS_TOKEN" \
  -H "X-Doct-Pat: Bearer $DOCT_ACCESS_TOKEN"
```

Plain markdown for text docs:

```bash
curl -sS "$DOCT_BASE_URL/api/documents?id=<document-id>" \
  -H "Authorization: Bearer $DOCT_ACCESS_TOKEN" \
  -H "X-Doct-Pat: Bearer $DOCT_ACCESS_TOKEN" \
  -H 'Accept: text/plain'
```

## 7. Resolve a doct URL

Doct document URLs typically look like:

```text
https://doct.nodaste.com/d/<workspace-handle>/docs/<document-id>
https://doct.develop.nodaste.com/d/<workspace-handle>/docs/<document-id>
```

Workflow:

1. Parse `<document-id>` from `/docs/<uuid>`.
2. Fetch `GET /api/documents?id=<document-id>`.
3. Use the response to recover title, path, workspaceId, and kind.
4. For text content, follow up with `Accept: text/plain` if you need the rendered markdown body.

## 8. REST-safe metadata operations

These are safe over REST.

### Create a document

```bash
curl -sS -X POST "$DOCT_BASE_URL/api/documents" \
  -H "Authorization: Bearer $DOCT_ACCESS_TOKEN" \
  -H "X-Doct-Pat: Bearer $DOCT_ACCESS_TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{
    "title": "New doc",
    "kind": "text",
    "content": "Initial content",
    "workspaceId": "<workspace-id>",
    "path": "notes/new-doc"
  }'
```

Note: creating a new text doc via REST is allowed because doct initializes Yjs state from the initial content.

### Update document metadata by id

Use `PUT /api/documents/[id]` for title/status and other metadata that is not a text-body change.

```bash
curl -sS -X PUT "$DOCT_BASE_URL/api/documents/<document-id>" \
  -H "Authorization: Bearer $DOCT_ACCESS_TOKEN" \
  -H "X-Doct-Pat: Bearer $DOCT_ACCESS_TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{
    "title": "Renamed title"
  }'
```

### Rename / move

Use the dedicated rename/move endpoints rather than trying to change `path`, `parentId`, or `displayOrder` through the generic document route.
Search the doct repo routes if you need the exact variant for the current install:

```bash
cd /Users/anichols/code/doct
rg -n "rename|move" app/\(chat\)/api/documents -g 'route.ts'
```

## 9. Comments

### Non-text documents

Allowed over REST:

```bash
curl -sS -X POST "$DOCT_BASE_URL/api/documents/comments" \
  -H "Authorization: Bearer $DOCT_ACCESS_TOKEN" \
  -H "X-Doct-Pat: Bearer $DOCT_ACCESS_TOKEN" \
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

- `POST /api/documents` and `PUT /api/documents/[id]` reject **text body updates** with `410`.
- `POST /api/documents/comments` rejects **text doc comments** with `410`.
- `GET /api/documents/[id]/comments` returns `410` for text docs.
- `GET /api/documents/with-comments` is fine for metadata/content-source checks, but does not give you usable text-doc comments.

## 11. Quick triage commands

If something is failing, these are the first checks:

```bash
doct-cli auth status
doct-cli workspaces list --json
doct-cli docs list --workspace <workspace-id> --json
curl -i "$DOCT_BASE_URL/api/documents?id=<document-id>" \
  -H "Authorization: Bearer $DOCT_ACCESS_TOKEN" \
  -H "X-Doct-Pat: Bearer $DOCT_ACCESS_TOKEN"
```
