---
date: 2026-05-04T00:28:58Z
author: codex
git_commit: 6cec7d64266f492942ecc5e671f6b77328e39c29
branch: main
repository: ai-configs
type: research
status: complete
tags: [linear, ltui, api-usage, rate-limits, grooming]
last_updated: 2026-05-04
---

# Research: Linear API Usage and ltui Grooming

## Research Question

Investigate how to reduce Linear API usage, especially for grooming large numbers of issues through `ltui`, using the current ltui implementation and Linear API docs.

## Summary

The largest API request multiplier is `ltui issues list`. It currently asks the SDK for an issue page, then maps every issue row by awaiting relation promises for team, state, project, assignee, and labels. Search is even more expensive because `client.searchIssues(...)` is followed by `client.issue(node.id)` for every search result before the same relation mapping runs.

Linear's API is GraphQL, with both request and complexity budgets. The practical optimization is to move high-volume read paths away from SDK-lazy entity access and toward explicit GraphQL selection sets shaped by the requested fields. `--fields id,identifier,title` should translate into a query that only selects those fields and should not touch team, state, project, assignee, labels, comments, history, or attachments.

## Detailed Findings

### Linear API Constraints

- Linear documents GraphQL rate limiting with request and complexity dimensions, surfaced through response headers.
- Linear documents filtering on paginated results, including nested filters and logical operators.
- Linear's GraphQL model lets clients request exactly the fields needed. This is the main lever `ltui` should use for large list/audit/grooming workflows.
- The installed `@linear/sdk` exposes `client.client.rawRequest(...)`, whose raw response includes headers. That means ltui can use the existing SDK dependency for custom GraphQL and live rate-limit visibility without introducing a separate HTTP client.

Sources:
- https://linear.app/developers/rate-limiting
- https://linear.app/developers/filtering
- https://linear.app/developers/graphql
- `tools/ltui/node_modules/@linear/sdk/dist/index.d.mts`

### Current `issues list` Request Shape

`issues list` builds a Linear filter, requests issues or search results, and then maps rows:

- `tools/ltui/src/commands/issues.ts:92` builds effective filters.
- `tools/ltui/src/commands/issues.ts:101` calls `client.searchIssues(...)` or `client.issues(...)`.
- `tools/ltui/src/commands/issues.ts:105` turns each search result into `client.issue(node.id)`, adding one request per result for search.
- `tools/ltui/src/commands/issues.ts:109` maps all nodes through `mapIssueToRow(...)`.
- `tools/ltui/src/commands/issues.ts:1112` awaits team, state, project, assignee, and labels for every row.

This means `--fields id,identifier,title` saves output tokens but does not prevent relation fetches, because field filtering happens after rows are already fully mapped.

### Current `issues view` Request Shape

`issues view` resolves a single issue, then always resolves related state/team/project/assignee and probes attachments/comments for image guidance:

- `tools/ltui/src/commands/issues.ts:262` resolves the issue.
- `tools/ltui/src/commands/issues.ts:272` resolves state/team/project/assignee.
- `tools/ltui/src/commands/issues.ts:294` probes assets, which can call `issue.attachments(...)` and `issue.comments(...)`.
- `tools/ltui/src/commands/issues.ts:331` fetches comments when requested.
- `tools/ltui/src/commands/issues.ts:345` fetches history when requested.

This is reasonable for a single selected issue, but it is costly inside loops across many candidate issues.

### Grooming Workflow Amplifier

`_opencode/commands/cmd:workplanner.md` is a representative large-grooming workflow:

- It lists up to 100 issues with `--fields identifier,title,state,updatedAt`.
- It filters candidate states locally after the list.
- It then loops candidates and runs `ltui issues view --include-comments --include-history` for each candidate until a terminal decision.

This pattern can spend many requests before doing useful work, especially when the issue list includes many candidates or comments/history/attachments are present.

## Recommendations

### 1. Make `issues list` Query-Shaped

Implement custom GraphQL for `issues list` using the selected fields. Use SDK `client.client.rawRequest` or `request` with explicit selection sets.

Examples:

- `--fields id,identifier,title,updatedAt` selects only scalar issue fields.
- `--fields state` adds `state { name }`.
- `--fields team` or `key` adds `team { key }`.
- `--fields project` adds `project { name slugId id }` only as needed.
- `--fields assignee` adds `assignee { name id email }` only as needed.
- `--fields labels` adds `labels(first: N) { nodes { name id } }` only as needed.

This is the highest-impact change.

### 2. Split "light list" From "rich list"

Make lightweight fields the default for list output, then require an explicit flag or field request for relation-heavy columns. A good default for grooming is:

```bash
ltui --limit 25 --format json --fields id,identifier,title,state,updatedAt issues list ...
```

`state` is usually useful for grooming, but labels/project/assignee should not be fetched unless they are filters or requested output.

### 3. Push More Grooming Filters Into Linear

When a grooming loop only wants `Backlog` and `Needs Feedback`, avoid fetching all project/label rows then filtering locally. ltui currently supports one `--state`; add one of:

- repeatable `--state`, compiled as `state: { or: [...] }`
- `--state-type`
- saved query definitions that support OR state sets

For the workplanner pattern, this turns one broad 100-row query into one or two narrow queries and reduces follow-up issue views.

### 4. Add a Two-Stage Context Command

Large grooming should select candidates from cheap fields, then fetch expensive context only for a bounded subset. ltui could expose:

```bash
ltui issues context ENG-123 --comments --history --attachments
```

or extend `issues view` with opt-in flags such as `--no-attachment-probe`. Today the attachment probe happens on every default view, which is useful but not free.

### 5. Expose Rate Headers

Add global options like:

```bash
ltui --show-rate-limit ...
ltui --rate-limit-json ...
```

Implementation path: use `rawRequest` for custom GraphQL paths and capture headers from `LinearRawResponse.headers`. For SDK convenience calls that do not expose headers directly, prefer custom GraphQL on high-volume commands.

### 6. Add Bounded Bulk Primitives

If agents need to groom or migrate many issues, make bulk operations explicit:

- require narrow filter or known ID list
- preview target count before mutation
- apply max default, for example 25
- sequential or very low concurrency
- stop/back off when remaining requests or complexity falls below a threshold
- write progress to a resumable local file

Do not rely on shell loops around `issues view` and `issues update` for high-volume operations.

### 7. Cache Stable Lookup Data Longer

The existing cache has a 300 second TTL for teams, projects, workflow states, labels, and users. For grooming, teams/states/labels/project refs are stable enough to cache longer, especially if cache invalidation is available:

- teams/states/labels/users: 1 to 24 hours
- projects by id/slug/name: 10 to 60 minutes
- issue list pages: optional, only for explicit `--cache`/`--cache-ttl`

Avoid caching issue detail by default unless stale reads are acceptable.

## Immediate Agent Guidance

Until ltui changes:

- Use narrow Linear filters before reading many rows.
- Keep `--limit` low while exploring.
- Do not assume `--fields` saves API requests.
- Avoid `--search` for bulk grooming if regular filters can express the target set, because search currently adds per-result issue lookups.
- Do not run `issues view --include-comments --include-history` across a broad candidate set. First select a tiny candidate batch from `issues list`.
- Prefer known ID/key lists for bulk operations.

## Code References

- `tools/ltui/src/commands/issues.ts:101` - issue list/search API call.
- `tools/ltui/src/commands/issues.ts:105` - search result per-node issue fetch.
- `tools/ltui/src/commands/issues.ts:1112` - row mapping awaits relation promises for every issue.
- `tools/ltui/src/commands/issues.ts:294` - default issue view probes assets.
- `tools/ltui/src/commands/issues.ts:331` - optional comments fetch.
- `tools/ltui/src/commands/issues.ts:345` - optional history fetch.
- `tools/ltui/src/linear.ts:21` - existing custom team lookup query pattern.
- `tools/ltui/src/cache.ts:1` - current local cache implementation.
- `_opencode/commands/cmd:workplanner.md:109` - broad candidate list.
- `_opencode/commands/cmd:workplanner.md:180` - per-candidate full context fetch.

## Open Questions

- Should `issues list` preserve the current relation-heavy default output for compatibility, or should the default become cheap and require explicit rich fields?
- Should attachment probing remain default on `issues view`, or become opt-in for API-budget-sensitive workflows?
- Should ltui add a general `graphql` command for debugging, or keep custom GraphQL internal to typed commands?
