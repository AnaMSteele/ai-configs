---
name: html-plan-reviewer
description: Create, publish, and monitor HTML development plans with the local `plan-review` service. Use this skill whenever the user asks to create an HTML plan, publish/register a plan for browser review, use the HTML plan editor/reviewer, monitor plan comments, process reviewer annotations, or wire an agent workflow to plan-reviewer comments. Also use it when working with plans under `thoughts/plans/*.html` that should be served at `http://mbp.braid-python.ts.net:4317/` or another plan-reviewer URL.
---

# HTML Plan Reviewer Workflow

Use this skill to turn agent-authored HTML plans into reviewable browser artifacts, publish them to the local `plan-review` daemon, and monitor reviewer comments until they are acknowledged or resolved.

## Service assumptions

The tool is the Homebrew-installed `plan-review` CLI from the standalone `Nodaste-Lab/plan-reviewer` repository. `ai-configs` only owns this workflow skill; it no longer vendors the daemon, CLI, or Homebrew formula.

Default service URL on this host:

```bash
http://mbp.braid-python.ts.net:4317
```

Use that full Tailscale MagicDNS URL in all user-facing plan links. Shortnames such as `mbp`, `localhost`, and `127.0.0.1` are allowed only for private health checks or curl diagnostics, never for URLs shared with the user or browser-review handoff.

Local health check:

```bash
curl -fsS http://127.0.0.1:4317/health
```

If the service is not running, start it:

```bash
brew services start plan-reviewer
```

If it is not installed, install from the standalone `plan-reviewer` tap:

```bash
brew tap Nodaste-Lab/plan-reviewer https://github.com/Nodaste-Lab/plan-reviewer.git
brew install Nodaste-Lab/plan-reviewer/plan-reviewer
brew services start plan-reviewer
```

Source and development docs live at `https://github.com/Nodaste-Lab/plan-reviewer`.

The MVP is intentionally unauthenticated. Treat `0.0.0.0:4317` as trusted-network only.

## Create an HTML plan

When asked to create a plan for this reviewer:

1. Load this skill before writing or serving any `thoughts/plans/*.html` artifact, even if a repo-local planning skill is also loaded.
2. Load the repo's planning guidance, especially `AGENTS.md` and any planning workflow skill that applies.
3. Write the plan under `thoughts/plans/<slug>.html` unless repo-local instructions say otherwise.
4. Use an HTML document, not Markdown renamed as HTML.
5. Mandatory visual baseline: use a dark-mode default theme with an explicit dark background, light foreground, readable muted text, accessible accent/link colors, and `color-scheme: dark`. Do not create light-mode HTML plans unless the user explicitly asks for a light-mode artifact.
6. Mandatory URL baseline: every plan URL shown to the user, opened in the browser, posted to Linear, or recorded in handoff must use the full Tailscale MagicDNS name, not a shortname, `localhost`, or `127.0.0.1`. On this host the canonical base is `http://mbp.braid-python.ts.net:4317/`; if using a temporary alternate port, keep the hostname and change only the port, e.g. `http://mbp.braid-python.ts.net:4318/...`.
7. Add stable `id` attributes to sections, phases, acceptance criteria, diagrams, figures, mockups, and other likely comment targets.
8. Prefer semantic HTML: `section`, `article`, `figure`, `figcaption`, headings, lists, tables, and code blocks.
9. Keep plan-authored scripts, event handlers, forms, and active embeds out of the artifact; the reviewer shell owns interactivity.
10. Keep images as relative repo assets when possible, with useful `alt`, `width`, and `height` attributes.

Important reviewer-friendly structure:

- `## Progress` or equivalent should contain the phase checkboxes.
- Each phase should have a stable wrapper ID, for example `id="phase-p1-contracts"`.
- Acceptance criteria and BDD scenarios should have stable IDs, for example `id="ac-1"` and `id="bdd-retry-timeout"`.
- Add short context near diagrams and images so comments on visual elements are meaningful to the agent.

## Publish/register a plan

From the repo that owns the plan:

```bash
plan-review register thoughts/plans/<plan>.html --repo auto --branch auto --commit auto
```

For machine-readable output:

```bash
plan-review register thoughts/plans/<plan>.html --repo auto --branch auto --commit auto --json
```

By default, registration live-links the local source file. The repo file is authoritative; service blobs are derived cache/history. After this succeeds, editing the HTML file should automatically sync the latest render into the already-open review page. Use `--snapshot` only when the user explicitly wants a detached historical review.

The command prints:

- `Plan ID`
- `Index URL`
- `Review URL`
- `Source sync`
- `Watch command`

Open the review URL for browser annotation, or open the index:

```bash
plan-review index
open http://mbp.braid-python.ts.net:4317/
```

Registration normally upserts the same plan thread. Use `--new-thread` only when the user explicitly wants a fresh review thread instead of updating the existing plan.

## Monitor for comments

For an active agent session, prefer `plan-review watch` so reviewer annotations arrive as near-real-time events.

One-shot check:

```bash
plan-review watch <planId> --mode queue --once --timeout 30000 --json
```

Long-running monitor:

```bash
plan-review watch <planId> --mode queue --format browser-comment --json
```

Browser-comment payloads only, suitable for appending into an agent conversation or NDJSON handoff:

```bash
plan-review watch <planId> --mode queue --format browser-comment --conversation-out /tmp/plan-review-comments.ndjson --json
```

### Codex watcher pattern

Codex should not use `--once` when the user wants live monitoring. Start the long-running watch in a PTY session with the `exec_command` tool, using a command like:

```bash
plan-review watch <planId> --mode queue --format browser-comment --json
```

Use `yield_time_ms: 1000` so the tool returns a `session_id` instead of waiting forever. Keep the Codex turn active while monitoring, and poll the session with `write_stdin` using empty input. When a browser-comment event arrives, claim/process/ack it, then continue polling the same session. Before sending a final answer, stop the watcher or move monitoring to a durable handoff; do not leave a needed `exec_command` session running after the turn ends.

If monitoring needs to outlive the Codex turn, use a durable wrapper and a conversation file instead of an in-turn PTY:

```bash
mkdir -p ~/.plan-reviewer/watchers
tmux new-session -d -s plan-review-<planId> \
  'plan-review watch <planId> --mode queue --format browser-comment --conversation-out ~/.plan-reviewer/watchers/<planId>.ndjson --json'
```

Codex can then inspect `~/.plan-reviewer/watchers/<planId>.ndjson` or run `plan-review queue claim <planId> --one --json` when asked to resume.

For Pi or another harness with a background-process tool, run long-running watches through that tool rather than blocking the main conversation. Watch commands reconnect using saved state by default, so restarting the monitor should continue after the last seen sequence.

Fallback polling/queue snapshot:

```bash
plan-review queue list --plan-id <planId> --json
```

## Process comment queue

Comments are at-least-once. The safe agent loop is claim -> inspect/apply -> ack -> optionally resolve.

Claim one pending comment:

```bash
plan-review queue claim <planId> --one --json
```

Claim multiple comments:

```bash
plan-review queue claim <planId> --limit 5 --json
```

Acknowledge after incorporating or explicitly deciding on the comment:

```bash
plan-review ack <commentId> \
  --claim <claimId> \
  --note "Updated the plan" \
  --summary "Integrated reviewer feedback on phase boundaries" \
  --changed-files thoughts/plans/<plan>.html \
  --json
```

Resolve when the reviewer-visible issue is complete:

```bash
plan-review resolve <commentId> \
  --note "Done" \
  --summary "Plan now includes the missing verification gate" \
  --changed-files thoughts/plans/<plan>.html \
  --json
```

If you cannot act on a claimed comment before the lease expires, release it:

```bash
plan-review release <commentId> --json
```

Direct `ack` without a matching active claim can return `409 claim_required`; claim first unless you already have the claim ID from the event payload.

## Responding to reviewer annotations

For each comment:

1. Read the full plan file before editing.
2. Use the annotation context: selected DOM node, heading path, quoted text, image anchor, and reviewer note.
3. Decide whether the comment is a blocker, clarification, or optional suggestion.
4. Make the smallest plan change that addresses the comment without widening scope.
5. If `Source sync: active` was reported, save the file and let the service sync/reload the browser view; otherwise re-register manually.
6. Ack with a concise summary and changed files.
7. Resolve only when the comment is fully addressed, not merely seen.

If the plan was registered with `--snapshot`, or if source sync reports a failure, re-register manually after edits:

```bash
plan-review register thoughts/plans/<plan>.html --repo auto --branch auto --commit auto --json
```

Keep append-only decision/deviation logs intact when regenerating a plan. Do not delete reviewer-relevant history unless the user explicitly asks.

## Quick command sequence

```bash
# 1. Verify service
curl -fsS http://127.0.0.1:4317/health

# 2. Register plan
plan-review register thoughts/plans/<plan>.html --repo auto --branch auto --commit auto --json

# 3. Share/open review UI
open http://mbp.braid-python.ts.net:4317/

# 4. Monitor comments
plan-review watch <planId> --mode queue --format browser-comment --json

# 5. Claim and process
plan-review queue claim <planId> --one --json
plan-review ack <commentId> --claim <claimId> --note "Handled" --changed-files thoughts/plans/<plan>.html --json
plan-review resolve <commentId> --note "Resolved" --json
```
