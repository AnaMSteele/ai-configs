---
name: sentry-cli
description: Investigate Sentry issues and recent events with sentry-cli, and perform safe issue hygiene actions when explicitly asked. Use when the user wants to inspect Sentry orgs/projects, list or summarize issues, investigate production incidents, review unresolved errors, check recent events/tags/releases, or mute/resolve/unresolve issues with confirmation.
---

# Sentry CLI investigation

Use this skill when the user wants to work with Sentry through the `sentry-cli` command line.

Default posture: **investigate first, change issue state only on explicit user request**.

## Capabilities

Primary `sentry-cli` workflows:
- verify auth and config
- discover organizations and projects
- list issues with Sentry search queries
- inspect recent events and tags
- summarize issue clusters, recency, severity, and likely next steps
- optionally change issue state with:
  - `sentry-cli issues mute`
  - `sentry-cli issues resolve`
  - `sentry-cli issues unresolve`

## Guardrails

- Do not mutate issue state unless the user explicitly asks.
- Before any `mute`, `resolve`, or `unresolve` action:
  1. show the exact command you plan to run
  2. identify the org, project, and issue selection
  3. ask for confirmation
  4. only run the command after confirmation
- Do not use broad `--all` mutations unless the user clearly asked for a bulk action.
- Do not assume an environment filter unless the user asked for one. If they say "production", add `environment:production` to the query. Otherwise investigate across environments.
- Keep secrets out of output. It is fine to report whether auth works; do not print auth tokens.

## Resolve the target

Prefer this order:

1. Use org/project explicitly provided by the user.
2. If omitted, try repo-local clues:
   - `next.config.*` Sentry plugin config
   - `sentry.server.config.*`, `sentry.edge.config.*`, `instrumentation-client.*`
   - env var names such as `SENTRY_ORG`, `SENTRY_PROJECT`, `SENTRY_ENVIRONMENT`
3. If still unknown, discover with CLI:

```bash
sentry-cli info --config-status-json
sentry-cli organizations list
sentry-cli projects list -o <org>
```

## Investigation workflow

### 1. Verify auth

```bash
sentry-cli info
# or machine-readable:
sentry-cli info --config-status-json
```

If auth fails, stop and tell the user what needs to be configured.

### 2. Discover org/project if needed

```bash
sentry-cli organizations list
sentry-cli projects list -o <org>
```

### 3. List relevant issues

Start with a tight query. Good defaults:

```bash
sentry-cli issues list -o <org> -p <project> --query 'is:unresolved' --pages 1 --max-rows 20
```

If the user asked about production:

```bash
sentry-cli issues list -o <org> -p <project> --query 'is:unresolved environment:production' --pages 1 --max-rows 20
```

Other useful queries:

```bash
sentry-cli issues list -o <org> -p <project> --query 'level:error is:unresolved'
sentry-cli issues list -o <org> -p <project> --query 'level:fatal is:unresolved'
sentry-cli issues list -o <org> -p <project> --query 'environment:production'
sentry-cli issues list -o <org> -p <project> --query 'release:<sha-or-version>'
```

### 4. Inspect recent events for context

Use recent events to capture environment, release, tags, and repeated reasons:

```bash
sentry-cli events list -o <org> -p <project> --pages 1 --max-rows 20
sentry-cli events list -o <org> -p <project> -T --pages 1 --max-rows 20
sentry-cli events list -o <org> -p <project> -T -U --pages 1 --max-rows 20
```

Important: `events list` is recent-event oriented and may not line up 1:1 with the exact issue rows you just listed. Use it to spot tags like `environment`, `release`, `surface`, `reason`, `handled`, and severity trends.

### 5. Summarize findings

Always give the user a compact summary:
- org + project investigated
- query used
- top unresolved issues by severity/recency
- whether the problem is production-only, development-only, or mixed
- repeated titles / clusters
- likely next actions

## Issue hygiene actions

Only after explicit user request and confirmation.

### Mute one issue

```bash
sentry-cli issues mute -o <org> -p <project> -i <issue-id>
```

### Resolve one issue

```bash
sentry-cli issues resolve -o <org> -p <project> -i <issue-id>
```

### Unresolve one issue

```bash
sentry-cli issues unresolve -o <org> -p <project> -i <issue-id>
```

### Bulk actions

Prefer query-driven review first, then present the exact command for confirmation. Example:

```bash
sentry-cli issues resolve -o <org> -p <project> -s unresolved --all
```

Bulk actions are high risk. Use them only when the user clearly asked for them.

## Output style

When investigating, structure the response as:

```markdown
## Sentry investigation
- Org: ...
- Project: ...
- Query: ...

## Top issues
1. SHORT-ID — title — status/level — last seen
2. ...

## Patterns
- ...

## Recommended next steps
- ...
```

When proposing a state-changing action, structure the response as:

```markdown
I found the target issue(s): ...
Planned command:
`...`

Please confirm if you want me to run it.
```

## Notes

- `sentry-cli` is strongest for issue and event investigation plus issue-state hygiene.
- If the user asks for alert-rule management or unsupported Sentry objects, say that the CLI surface is limited and propose a follow-up via Sentry API or UI if needed.
