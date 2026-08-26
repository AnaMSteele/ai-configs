# Codex Desktop asynchronous plan responder

Read this reference after registering or updating any reviewer-facing HTML plan from Codex Desktop.

## Required mechanism

Use the Codex app automation tool to create or update one active **heartbeat** automation attached to the current task. A five-minute heartbeat is the default unless the user asks for another cadence. Prefer an existing automation for the same Doct document over creating a duplicate.

Do not use a cron/new-task automation, a raw launchd `doct-agent plans listen` process, or a detached shell process. The heartbeat must wake a reasoning agent that can consume and complete queue work.

## Automation prompt

Substitute the exact values returned by registration and the durable local source path:

```text
Monitor and process browser-review comments for the Doct HTML plan "<TITLE>".

Target:
- Doct base URL: <BASE_URL>
- Workspace ID: <WORKSPACE_ID>
- Document ID: <DOCUMENT_ID>
- Local authoritative HTML source: <SOURCE_PATH>
- Working directory: <WORKING_DIRECTORY>

On each heartbeat:
1. Read the doct-document-ops skill and all applicable AGENTS.md files. Verify Doct auth, plan lifecycle, registered source path, and queue state.
2. If the document is missing or lifecycle is complete/canceled, release any live claim, delete this automation, and report that monitoring stopped.
3. Claim at most one pending item with `doct-agent plans agent next --no-wait --json` using the exact target IDs. If the queue is empty, finish quietly.
4. For a claim, read the entire local HTML source and the complete comment thread/dispatch context. Preserve unrelated user changes. Process exactly that claim; do not call `agent next` again for it.
5. Apply the smallest coherent plan edit that addresses the feedback. Validate the HTML and update the same Doct document from the durable source file; never create a replacement plan.
6. Add a visible reply, acknowledge with the returned claim ID and changed source file, and resolve only when the request is fully addressed. If safe completion is impossible, release the claim with an explicit reason.
7. After acknowledging or releasing, claim the next item one at a time until the queue is empty. Never pre-claim multiple items or leave a claim unacknowledged.
8. Notify the user only for material plan changes, decisions, or blockers.
```

## Completion gate

Before telling the user that asynchronous review is ready:

1. View the automation and confirm it is active, is a heartbeat attached to the current task, and contains the exact document/workspace/source identifiers.
2. Confirm `doct-agent plans lifecycle ... --state active --json` reports the durable source path.
3. Run one `plans agent next --no-wait --json` drain. Process any returned claim; do not leave it claimed for the future heartbeat.
4. Return the Doct URL and automation ID.

If the automation tool is unavailable, say that publication succeeded but asynchronous review is not configured. Do not substitute a session-bound listener and do not claim success.
