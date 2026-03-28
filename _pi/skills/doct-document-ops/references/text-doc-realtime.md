# Doct text-document realtime workflow

Use this reference when the user wants to edit the body of a doct text document or add an anchored comment to text.

## Core rule

For **text** documents, body edits and anchored comments go through **Hocuspocus/Yjs**, not the generic REST document endpoints.

REST writes intentionally return `410` for text body writes and text comment sync.

## Preconditions

You need all of these:
- doct base URL (`DOCT_BASE_URL`)
- doct PAT (`DOCT_ACCESS_TOKEN`)
- document id
- Hocuspocus websocket URL (`NEXT_PUBLIC_HOCUSPOCUS_URL` equivalent for the target environment)

For local doct dev, the websocket URL is usually:

```text
ws://localhost:1234
```

For hosted environments, it is usually a `wss://...` URL from doct's `NEXT_PUBLIC_HOCUSPOCUS_URL`.

## Minimal workflow

1. Resolve the document id.
2. Read the current markdown body via `GET /api/documents?id=<id>` with `Accept: text/plain`.
3. Connect to Hocuspocus with the raw PAT.
4. Wait for sync.
5. Mutate the Yjs document:
   - body edit → `applyMarkdownToYjsDoc`
   - text comment → `createCommentAnchor` or `createCommentAnchorFromQuote`, then `addComment`
6. Optionally create a named version after the content change.
7. Re-read the document body over REST to verify the persisted result.

## Canonical code pattern

Run from the doct repo with `pnpm exec tsx` so imports resolve correctly.

```ts
import { randomUUID } from "node:crypto";
import { HocuspocusProvider, HocuspocusProviderWebsocket } from "@hocuspocus/provider";
import * as Y from "yjs";
import WebSocket from "ws";
import {
  addComment,
  createCommentAnchorFromQuote,
} from "@/lib/editor/yjs-comments";
import { applyMarkdownToYjsDoc } from "@/packages/hocuspocus-server/src/services/SyncHandler";

const HOCUSPOCUS_URL = process.env.DOCT_HOCUSPOCUS_URL!;
const TOKEN = process.env.DOCT_ACCESS_TOKEN!;
const DOCUMENT_ID = process.env.DOCT_DOCUMENT_ID!;
const AGENT_ID = process.env.DOCT_ACTOR_ID!; // user_... or agent_...
const NEXT_MARKDOWN = process.env.DOCT_NEXT_MARKDOWN;
const COMMENT_TEXT = process.env.DOCT_COMMENT_TEXT;
const COMMENT_QUOTE = process.env.DOCT_COMMENT_QUOTE;

const ydoc = new Y.Doc();
const websocketProvider = new HocuspocusProviderWebsocket({
  url: HOCUSPOCUS_URL,
  autoConnect: false,
  WebSocketPolyfill: WebSocket,
});

const provider = new HocuspocusProvider({
  name: `document:${DOCUMENT_ID}`,
  document: ydoc,
  token: TOKEN,
  websocketProvider,
});

await new Promise<void>((resolve, reject) => {
  const timeout = setTimeout(() => reject(new Error("Timed out waiting for sync")), 20000);
  provider.on("synced", ({ state }: { state: boolean }) => {
    if (!state) return;
    clearTimeout(timeout);
    resolve();
  });
  websocketProvider.connect().catch(reject);
  provider.attach();
});

ydoc.transact(() => {
  if (NEXT_MARKDOWN != null) {
    applyMarkdownToYjsDoc(ydoc, NEXT_MARKDOWN);
  }

  if (COMMENT_TEXT && COMMENT_QUOTE) {
    const anchor = createCommentAnchorFromQuote({
      ydoc,
      selectedText: COMMENT_QUOTE,
    });

    if (!anchor) {
      throw new Error(`Could not anchor quote: ${COMMENT_QUOTE}`);
    }

    addComment(ydoc, {
      anchor: anchor.anchor,
      selectedText: anchor.selectedText,
      isResolved: false,
      resolvedBy: null,
      resolvedAt: null,
      createdBy: AGENT_ID,
      createdAt: new Date().toISOString(),
      comments: [
        {
          id: randomUUID(),
          text: COMMENT_TEXT,
          createdBy: AGENT_ID,
          createdAt: new Date().toISOString(),
          authorType: AGENT_ID.startsWith("agent_") ? "agent" : "user",
          authorUserId: AGENT_ID,
          authorPersonaVersionId: null,
          authorMetadata: {},
        },
      ],
      reactions: [],
    });
  }
}, AGENT_ID);

await new Promise((resolve) => setTimeout(resolve, 1500));
provider.destroy();
websocketProvider.destroy();
ydoc.destroy();
```

## Practical execution recipe

### Edit body text

1. Fetch current markdown.
2. Prepare the fully updated markdown.
3. Run the snippet with `DOCT_NEXT_MARKDOWN` set.
4. Re-fetch the body with `Accept: text/plain` and confirm the new text is present.

### Add a text comment

1. Fetch current markdown.
2. Choose a stable quote string from the current content.
3. Run the snippet with `DOCT_COMMENT_TEXT` and `DOCT_COMMENT_QUOTE` set.
4. Verify via doct UI or other realtime-aware tooling.

## Optional: create a named version after edit

If the user wants an explicit saved version after a text edit, call:

```bash
curl -sS -X POST "$DOCT_BASE_URL/api/documents/$DOCT_DOCUMENT_ID/versions" \
  -H "Authorization: Bearer $DOCT_ACCESS_TOKEN" \
  -H "X-Doct-Pat: Bearer $DOCT_ACCESS_TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"name":"Agent update"}'
```

## Verification checklist

- Did the websocket connection actually sync?
- Did the quote resolve unambiguously?
- Did the final REST re-read show the updated markdown?
- If commenting, can the user see the thread in doct UI?
- If the user asked for a durable milestone, did you create a named version?

## Failure modes

### 410 from REST text write

Expected. You used the wrong path. Switch to realtime/Yjs.

### Quote cannot be anchored

Use a more specific quote or include prefix/suffix context with `createCommentAnchorFromQuote`.

### Websocket auth rejected

Check:
- PAT validity
- workspace/document membership
- correct Hocuspocus URL
- revoked/expired token

### Need to inspect existing text comments

Public REST is intentionally insufficient. Prefer doct UI/browser automation or repo-local investigation.
