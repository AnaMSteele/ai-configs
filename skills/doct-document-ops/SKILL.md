---
name: doct-document-ops
description: Interact with doct documents and browser-review plans via doct-agent, REST, and Hocuspocus/Yjs. Use when asked to open a doct URL, list doct workspaces or documents, view or edit a doct document, supervise or repair an asynchronous plan listener, process plan comments, or publish any product, coding, implementation, research, or review plan as HTML to the Shared workspace with a session-independent agent responder.
---

# Doct document operations

Use this skill when the user wants work done **inside doct itself** rather than only in local markdown files.

## CLI freshness

Install and update `doct-agent` through Homebrew only. From the canonical doct checkout:

```bash
git pull --ff-only
brew tap local/doct "$(pwd)"
brew reinstall --build-from-source local/doct/doct-agent
```

Do not use `~/.cargo/bin/doct-agent`, copy Cargo artifacts into another bin directory, or create wrapper binaries. Compatibility notices from the deployed service are authoritative; source SHAs are diagnostic only.

## Default approach

1. Resolve the target document or destination.
2. Resolve auth.
3. Choose the correct write path:
   - **View/list/lookup** → `doct-agent`.
   - **Metadata-only updates** (title, rename, move, settings) → `doct-agent` when available, otherwise supported REST.
   - **Full text body replacement** → `doct-agent documents replace-body --file`.
   - **Append-only text edits** → `doct-agent collab edit --append-markdown`.
   - **Anchored surgical text edits** → `doct-agent collab anchored <replace|insert-before|insert-after|delete>`.
   - **Text comments** → `doct-agent collab comments` when available; otherwise realtime Hocuspocus/Yjs.
   - **Publish any plan document** → author a durable HTML source file, use `scripts/publish-coding-plan.sh --json`, then configure a session-independent agent responder.

## Required destination: all plan documents

If the user asks to **send, publish, copy, or save any plan document to doct**, always use this destination:

- workspace: the **Shared** doct workspace
- parent document title: **Coding Plans**
- new document type: **HTML plan**
- placement: create the new plan as a **child document** under `Coding Plans`

This applies to product plans, coding plans, implementation plans, execution plans, research plans, review plans, and strategy/roadmap plans. Do not publish a newly created plan document into the Personal workspace. If Shared cannot be resolved, stop with the exact workspace-resolution failure instead of falling back to Personal.

### Required format: HTML by default

Every newly authored plan must default to one complete, standalone HTML document. Do not publish a Markdown-only plan, rename a Markdown file to `.html`, or create a sibling Markdown version as the primary plan artifact.

The HTML plan must:
- include `<!doctype html>`, `<html>`, `<head>`, `<title>`, and `<body>`
- use semantic sections and stable `id` attributes so review comments can point to durable anchors
- include embedded CSS that is readable without external assets, with dark mode as the default presentation
- contain no scripts

If the source material is Markdown, first render it into a genuine HTML plan that satisfies these requirements. Keep the authoritative `.html` source at a durable absolute path; a temporary file or stdin-only source cannot support asynchronous teammate review. Repository-local HTML plan contracts and templates take precedence over this generic minimum.

### Coding-plan workflow

1. If the plan is in a local file, read it fully first.
2. Author or render the plan as one complete `.html` document. Preserve the source plan's substance while improving navigation and reviewability.
3. Derive a title from `<title>` or the first `<h1>`; otherwise use the file basename or ask if the title matters.
4. Publish from the durable source file and preserve the full registration payload:

```bash
bash "$SKILL_DIR/scripts/publish-coding-plan.sh" --file /absolute/path/to/plan.html --json
```

5. Set plan lifecycle to `active` and drain already-pending work with `plans agent next --no-wait --json`. Process and acknowledge any claim before continuing.
6. Configure or update a **session-independent agent responder** for this exact document, workspace, and source file. In Codex Desktop, use a recurring heartbeat automation attached to the current task; read `references/codex-heartbeat-listener.md` and follow it exactly.
7. Verify that the responder is active, its prompt contains the exact document/workspace/source identifiers, and the registered `sourcePath` equals the durable HTML file.
8. Return the Doct URL, document id, and responder/automation id to the user. Do not say the plan is ready for asynchronous review until this verification passes.

The publisher script automatically:
- rejects Markdown-only or fragmentary input
- rejects temporary stdin-only publication and registers the exact durable source path
- validates doct auth
- resolves and verifies the Shared workspace
- ensures the root document `Coding Plans` exists
- registers the new HTML plan beneath it through Doct's plan-review workflow
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

Use the actual `doct-agent` executable:

```bash
doct-agent auth status --all --json
```

If not logged in or the selected endpoint token is invalid, start agent auth:

```bash
doct-agent auth login --base-url https://doct.nodaste.com
# or develop:
doct-agent auth login --base-url https://doct.develop.nodaste.com
```

The CLI stores registrations by canonical endpoint under the platform config directory for `doct-agent`. It also stores the endpoint websocket URL after auth, so do not hardcode websocket fallbacks unless the live command output explicitly asks for an override.

### Environment overrides

Use these when needed:
- `DOCT_BASE_URL`
- `DOCT_AGENT_PAT` with an explicit `--base-url` / `DOCT_BASE_URL` for one-off automation

## Read operations

For common read/list tasks, use the actual `doct-agent` executable:

```bash
doct-agent workspaces list --json
doct-agent documents list --workspace-id <workspace-id> --json
doct-agent documents get --workspace-id <workspace-id> --path '<doc-path>' --text
doct-agent documents get --workspace-id <workspace-id> --path '<doc-path>' --json
doct-agent documents get --id <document-id> --text
doct-agent documents get --id <document-id> --json
```

If the selected endpoint is not the default, pass it explicitly:

```bash
doct-agent documents get --base-url https://doct.develop.nodaste.com --id <document-id> --text
```

Read `references/rest-and-cli.md` for exact lookup/read patterns.

## Browser-review plan listeners

Registration is not listener setup. A plan is ready for asynchronous teammate review only when a session-independent supervisor can wake an agent, claim one comment, apply the change, reply, acknowledge or release the claim, and continue after the publishing session ends.

After `doct-agent plans register --json`, preserve the complete returned `listenerInstructions` object. Non-default endpoints may be embedded in its commands.

1. Run the returned lifecycle command and drain already-pending work with the returned `plans agent next --no-wait --json` command.
2. Choose a supervisor that is independent of the current agent session:
   - **Codex Desktop**: create or update a recurring heartbeat automation attached to the current task. Use `references/codex-heartbeat-listener.md`.
   - **Other hosts**: use a host-native recurring job only if each wake launches an actual agent consumer with the plan source and claim context. If the host cannot provide that, report that asynchronous review is not configured.
3. A `plan_comment_dispatch` is already a claimed item. Read and execute its `replyCommand`, `ackCommand`, `resolveCommand`, and `releaseCommand`; do not call `plans agent next` for the same item.
4. Keep the responder active while plan lifecycle is `active`. Stop/delete it when the plan is complete, canceled, deleted, or the user asks to stop monitoring, after releasing any live claim.

A foreground/yielded `wakeCommand` is useful for immediate interactive review but is session-bound and does not satisfy the asynchronous requirement. A detached `doct-agent plans listen`, `nohup`, `screen`, or launchd job that only claims or prints dispatches is also invalid because it has no supervised agent consumer. `plans agent next --wait --json` is diagnostic or one-shot recovery only.

## Write operations

### Metadata-only changes

Safe over REST:
- create document
- rename document
- move document
- update title/status/settings/theme
- add comments to **non-text** documents
- create child documents under Shared workspace `Coding Plans`

### Text body edits

For full text replacement, prefer:

```bash
doct-agent documents replace-body --id <document-id> --file prepared.md --json
```

Do **not** send text document body updates through raw `POST /api/documents` or `PUT /api/documents/[id]`.
Those routes intentionally return `410` for unsupported text body writes.

For append-only edits, use `doct-agent collab edit --append-markdown`.
For anchored surgical edits, use `doct-agent collab anchored ...`.
Use the realtime path described in `references/text-doc-realtime.md` only when the consolidated CLI does not cover the operation.

### Text comments

Do **not** use `POST /api/documents/comments` for text documents.
That route intentionally returns `410` for text docs.

For initial anchored text comments, prefer:

```bash
doct-agent collab comments add --document-id <id> --selected-text 'target text' --body 'initial thread body'
```

Use the realtime path in `references/text-doc-realtime.md` for follow-up comment reply/resolve flows when the CLI does not cover the operation.

### Existing comments on text docs

Public REST routes intentionally do not expose text-doc comments cleanly:
- `GET /api/documents/[id]/comments` returns `410` for text docs
- `GET /api/documents/with-comments` reports `contentSource: yjs` but does not return text comments

If the user wants to inspect existing text comments, prefer:
1. doct UI/browser automation, or
2. repo-local doct internals / DB-backed investigation if direct API visibility is insufficient.

## Decision rules

- Use `doct-agent` for quick listing, id/path-based viewing, document creation, full text-body replacement, anchored edits, plan registration, and triage.
- Use REST when the operation is explicitly supported and not a text-body mutation.
- Use Hocuspocus/Yjs directly only for gaps not covered by `doct-agent`.
- Use `scripts/publish-coding-plan.sh --json` for every newly published plan document so the Shared-workspace, HTML-format, and durable-source defaults are enforced.
- Treat session-independent responder setup and verification as part of plan publication, not an optional follow-up.
- If the user wants visual verification inside doct, use browser automation after approval.

## References

- `references/rest-and-cli.md` — auth, lookup, list, view, metadata-safe REST patterns
- `references/text-doc-realtime.md` — exact realtime edit/comment workflow for text docs
- `references/codex-heartbeat-listener.md` — required Codex Desktop heartbeat automation for asynchronous plan comments
- `scripts/publish-coding-plan.sh` — registers an HTML plan child under Shared workspace `Coding Plans`; rejects non-Shared destinations and non-HTML input
