# ltui Image Attachment Fetching Plan

## Objective

Add first-class attachment retrieval to `ltui` so agents can reliably discover and fetch screenshots/images from Linear issues, and receive deterministic instructions directly from `ltui issues view` when image attachments are present.

## Requested Outcomes

1. `ltui issues view <issue>` emits explicit guidance fields when image attachments exist.
2. `ltui` provides a command to fetch issue attachments (metadata and optional file download).

## Scope

In scope:
- New `ltui issues attachments` command under existing issues surface.
- Image-presence hints in `ltui issues view` output.
- Deterministic output contracts for agent parsing.
- Mock client and tests updated to cover the new flow.
- Skill/reference docs updated so agents know how to use it.

Out of scope:
- Changing Linear permissions/auth model.
- Upload pipeline redesign.
- Non-issue attachment entities.

## Output Contract (Deterministic)

- Structured output (`table`, `tsv`, `json`) goes to `stdout` only.
- Errors, warnings, and human-readable diagnostics go to `stderr` only.

Decision: `--format json` output is JSON-only (no plaintext pagination header). For list-style commands, emit a single JSON object envelope with both pagination metadata and rows.

JSON list envelope schema:

```json
{
  "meta": {
    "cursorNext": "<cursor or empty string>",
    "cursorPrev": "<cursor or empty string>",
    "count": 2
  },
  "rows": [
    { "id": "...", "title": "..." }
  ]
}
```

Notes:
- This replaces the existing `CURSOR_NEXT/CURSOR_PREV/COUNT` plaintext header for `--format json`.
- For `--format tsv|table`, keep the existing plaintext pagination header + body.

[REVIEW:Kimi Reviewer] GAP: The plan requires “pagination metadata + list body” while also requiring `--format json` be parseable for agent parsing. In this repo, pagination meta is currently emitted as 3 plaintext lines (see `tools/ltui/src/format.ts`) and tests/spec expect that behavior. Decide and document the attachments contract explicitly:
- Option A (status quo): meta header lines on `stdout` + JSON array body on `stdout` (agents must strip first 3 lines before JSON parsing)
- Option B (breaking change): JSON-only on `stdout` for `--format json` (meta must move to `stderr` or be embedded as a JSON envelope)
- Attachment rows are sorted by `createdAt` descending, then `id` ascending for tie-breaking.
- Missing optional fields are normalized to empty strings (`""`) in table/tsv/json rows.
- `downloadStatus` is one of: `downloaded`, `exists`, `failed`, ``.
- `downloadError` is an empty string unless `downloadStatus=failed`.

[REVIEW:GPT5.4] INCORRECT/AMBIGUITY: In the current `ltui` codebase, list commands print pagination metadata (`CURSOR_NEXT`, `CURSOR_PREV`, `COUNT`) to `stdout` *before* the list body even when `--format json`, which means the overall output stream is not valid JSON. This plan both (a) requires “pagination metadata + list body” and (b) later asks for “parseable JSON rows” checks. Pick and document the contract for attachments: meta+json (agent parses 3-line meta header then JSON) vs json-only output (would be a deliberate convention change). [/REVIEW]

[REVIEW:GPT5.4] AMBIGUITY: `downloadStatus` includes an empty backticked value (``) as a state. Spell this out as “empty string” and tie it to a condition (e.g., when `--download-dir` is omitted) so implementers don’t emit `null`/omit the key and accidentally break the deterministic schema. [/REVIEW]

## Proposed CLI Contract

### 1) `ltui issues attachments <issue-id-or-key>`

[REVIEW:Kimi Reviewer] AMBIGUITY: The plan assumes `issue.attachments({ first, after })` exists in the Linear SDK, but doesn't verify this. Need to confirm the actual SDK method name and parameters. The Linear SDK typically uses different naming conventions (e.g., `attachments()` vs `issue.attachments()`). Research the actual SDK schema before implementation. [/REVIEW]

Behavior:
- Resolves issue by id/key (same behavior as existing issues commands).
- Fetches issue attachments via Linear SDK: `issue.attachments({ first, after, before, last, includeArchived, orderBy, filter })`.
- Supports global output flags (`--format`, `--fields`, `--limit`, `--cursor`).
- Emits standard pagination metadata + list body.

Options:
- `--only-images` (optional): return only attachments classified as images.
- `--download-dir <dir>` (optional): download matching attachments into local directory.
- `--overwrite` (optional): overwrite existing downloaded files.

List columns (default):
- `id`
- `title`
- `url`
- `sourceType`
- `subtitle`
- `contentType` (derived: `String((attachment.metadata as any)?.contentType ?? "")`)
- `isImage` (`true|false`)
- `createdAt`
- `downloadPath` (empty unless `--download-dir`)
- `downloadStatus` (`downloaded|exists|failed|`)
- `downloadError` (empty unless failed)

[REVIEW:Kimi Reviewer] GAP: The column `sourceType` and `subtitle` fields need to be confirmed against the actual Linear SDK Attachment schema. The mock client currently doesn't include attachment data in issue fixtures - this needs to be added to support meaningful testing. Also, `contentType` may not be reliably populated by Linear - need to verify if this field exists or if we must infer from URL/extension only. [/REVIEW]

Download behavior:
- Filename sanitization blocks path traversal and strips unsafe path segments.
- Collision handling is deterministic suffixing (`name.ext`, `name-1.ext`, `name-2.ext`, ...).
- If `--overwrite` is set, target file path is replaced directly.
- Command exits non-zero on one or more failed downloads; still prints full row output.
- Skipped existing files (without `--overwrite`) remain exit code `0` and use `downloadStatus=exists`.
- Download timeout and max file size limits are enforced to prevent hangs/OOM.
- Only `http`/`https` URLs are fetched.
- Linear private storage support: if the URL host is `uploads.linear.app`, include `Authorization: Bearer <LINEAR_API_KEY>` when downloading (see Linear "File storage authentication"). Optionally, request signed file URLs by setting LinearClient header `public-file-urls-expire-in`.

[REVIEW:Kimi Reviewer] RISK: The collision suffixing algorithm isn't fully specified. Need clarity on:
1. What happens if `name-99.ext` also exists? Is there an upper bound?
2. How are filename extensions determined when URL has query params (e.g., `image.png?v=123`)?
3. What character encoding handling is expected for non-ASCII filenames?

Also, the max file size limit value is not specified - needs a concrete number (suggest 100MB default). [/REVIEW]

### 2) `ltui issues view <issue>` enhancements

Add deterministic fields to `ISSUE_DETAIL` block (append after existing keys):
- `ATTACHMENTS_PRESENT: true|false`
- `IMAGE_ATTACHMENTS_PRESENT: true|false`
- `IMAGE_ATTACHMENTS_FETCH_CMD: <command>` (only when image attachments exist)
- `IMAGE_ATTACHMENTS_DOWNLOAD_CMD: <command>` (only when image attachments exist)

Detection requirements:
- `IMAGE_ATTACHMENTS_PRESENT` must not produce false negatives due to pagination.
- Use an exhaustive probe:
  - Page through all attachments until an image is found (early-exit) OR the connection is exhausted (`pageInfo.hasNextPage=false`).
  - If the probe completes without finding an image, it is safe to emit `IMAGE_ATTACHMENTS_PRESENT: false`.

[REVIEW:GPT5.4] RISK: “bounded paging” inherently permits false negatives if images exist after the bound, which contradicts the stated requirement. If the SDK cannot filter/count, the only way to guarantee “no false negatives” is to page until an image is found OR the connection is exhausted (i.e., if you return `false`, you must have checked all pages). If you keep a bound for performance, adjust the requirement and consider emitting an explicit “probe incomplete/unknown” signal. [/REVIEW]

Example emitted guidance:
- `IMAGE_ATTACHMENTS_FETCH_CMD: ltui issues attachments ENG-42 --only-images --format json`
- `IMAGE_ATTACHMENTS_DOWNLOAD_CMD: ltui issues attachments ENG-42 --only-images --download-dir ./.ltui-attachments/ENG-42`

## Implementation Plan

[REVIEW:Kimi Reviewer] GAP (execution readiness): Add an explicit pre-implementation “SDK/schema verification” step (either a Phase 0 or a Work item in Phase 1) to confirm the Linear SDK attachment API shape, supported filters (count/exists), and what fields are reliably present (`contentType`, `subtitle`, etc.). Several later phases depend on these unknowns; without a concrete contract, implementation will thrash. [/REVIEW]

[REVIEW:GPT5.4] GAP (execution readiness): The plan’s phases are `### Phase N:` headers, but the review rubric/other agents often expect `## Phase N:`. Also `### End State/Work/Verify` are currently the same heading level as the phase header, which can confuse tooling/readers. If you rely on automation around phases/progress mapping, align heading levels (or explicitly note that this repo’s plan parser tolerates `###`). [/REVIEW]

### Phase 1: Attachment Retrieval + Deterministic Metadata

### End State
- `issues attachments` exists, returns attachment rows, and follows deterministic output contract.
- Null/missing fields are normalized consistently.

### Work
- Add attachment row model and render columns in `tools/ltui/src/commands/issues.ts`.
- Implement `issues attachments` command registration, options, and action handler.
- Add image classification helper:
  - Primary: `(attachment.metadata as any)?.contentType` starts with `image/`.
  - Fallback: image-like URL extension (`.png`, `.jpg`, `.jpeg`, `.gif`, `.webp`, `.svg`).
  - Support cursor/limit passthrough and existing `renderList` output behavior.
- Define explicit sort order (`createdAt` desc, tie-breaker `id` asc).
- Normalize optional fields (`sourceType`, `subtitle`, `contentType`) to empty strings.
- Keep structured output on `stdout` and diagnostics on `stderr`.

[REVIEW:Kimi Reviewer] GAP: The Work section doesn't explicitly include updating the mock client. However, Phase 4 mentions mock updates. This should be acknowledged as a dependency - Phase 1's manual verification cannot succeed without mock data. Suggest adding a note that mock fixtures must be updated before manual checks can pass.

Also MISSING: The image classification needs to handle case-insensitive extension matching (`.PNG`, `.Jpg`). Need to specify `toLowerCase()` normalization. [/REVIEW]

### Verify
[REVIEW:GPT5.4] WRONG REFERENCE: `tools/ltui/package.json` defines `test` as `bun run build && node --test dist/**/*.test.js`; `bun run test -- issues` is not a documented/supported scoped invocation. Replace with an exact command that actually works in this repo (e.g., `bun run test`) and, if you want phase-scoped runs, document the `node --test dist/<pattern>` invocation explicitly. [/REVIEW]

- `bun run test -- issues` (or closest scoped test target) passes for attachments command behavior.
- Manual check: `ltui issues attachments <ISSUE_KEY> --format json` emits parseable JSON rows and no logs on `stdout`.

[REVIEW:GPT5.4] INCORRECT: As written, “parseable JSON rows” will fail if you keep the existing convention of prefixing list output with pagination meta on `stdout`. Reword the check to match the chosen contract (e.g., “JSON body is parseable after stripping the 3-line meta header”). [/REVIEW]
- Manual check: output order is stable across repeated runs with identical fixture data.

### Phase 2: Download Safety + Failure Semantics

### End State
- Optional download mode is safe by default and deterministic under collisions/failures.

[REVIEW:Kimi Reviewer] CRITICAL GAP: Phase 2 Work section mentions "Guard against symlink/special-file writes" but doesn't specify HOW. Need explicit requirements:
1. Use `fs.lstat()` before writing to detect symlinks
2. Refuse to write if destination is a symlink, device file, or directory
3. Document the specific error code thrown (suggest `validation_error` or `download_error`)

Also missing: retry logic for transient network failures. At minimum, should have 1-2 retries with exponential backoff. [/REVIEW]

[REVIEW:GPT5.4] RE: [Kimi Reviewer] - SCOPE DRIFT: retries/backoff are not part of the stated Requested Outcomes/Acceptance Criteria. If you add retries, treat it as an explicit scope addition (documented decision + tests), otherwise keep to the specified timeout/max-size + error surfacing semantics. [/REVIEW]

### Work
- Add download helpers in `tools/ltui/src/commands/issues.ts`:
  - URL validation (`http/https` only).
  - Stream download to file.
  - Deterministic filename generation and sanitization.
  - Extension inference from URL/content-type.
- Implement path traversal protection for `--download-dir` filenames.
- Implement deterministic collision handling suffix strategy.
- Ensure `--download-dir` creates directories recursively.
- Enforce timeout and max file size limits for downloads.
- Guard against symlink/special-file writes in destination path handling.
- Set `process.exitCode = 1` if one or more downloads fail while still printing all rows.
- Keep `exists` (no overwrite) as non-failure with exit code `0`.

### Verify
- Tests cover path traversal attempts, collision handling, and partial failures.
- Tests assert exit code and `downloadStatus`/`downloadError` semantics.
- Manual check: `ltui issues attachments <ISSUE_KEY> --only-images --download-dir ./.ltui-attachments/<ISSUE_KEY>` downloads files safely.

[REVIEW:GPT5.4] GAP (testability): Phase 2/4 require asserting timeout/max-size and partial download failures. The plan doesn’t specify how downloads are mocked in `node --test` (compiled JS) tests. Call out an intended approach (e.g., spin up an in-test local HTTP server serving fixture bytes and slow responses; or inject a downloader/fetch implementation for stubbing) so the test work is executable and deterministic. [/REVIEW]

### Phase 3: Reliable View Guidance Signals

### End State
- `issues view` reliably indicates whether image attachments exist and emits command hints with no false negatives.

### Work
- Add attachment-presence probe in `issues view`.
- Implement reliable `IMAGE_ATTACHMENTS_PRESENT` detection:
  - Prefer direct filtered/count-based query when SDK supports it.
  - Otherwise page until first image is found (with safe upper bound and documented fallback behavior).
- Emit new `ISSUE_DETAIL` fields in stable key order after existing issue fields.
- Keep existing description/comments/history output unchanged.

[REVIEW:Kimi Reviewer] CRITICAL GAP: The "safe upper bound" for pagination is not specified. This is essential for the "no false negatives" requirement. Need:
1. Concrete max pages to check (suggest 10 pages = 500 attachments max)
2. Behavior when limit is reached but no image found (suggest: emit `IMAGE_ATTACHMENTS_PRESENT: unknown` or `potential`)
3. Documented performance impact - each page is an API call

Also MISSING: The actual GraphQL query/filter to use for attachment presence detection. Need to research if Linear SDK supports `filter: { sourceType: image }` or similar. [/REVIEW]

### Verify
- Test fixture where image exists beyond first page still yields `IMAGE_ATTACHMENTS_PRESENT: true`.

[REVIEW:GPT5.4] GAP: This verification implies the mock + command implementation must support real pagination semantics (honor `first`, `after`, and return meaningful `pageInfo.endCursor`). Today the mock client’s `connection()` always returns `endCursor: null` / `startCursor: null`, so paging-based tests will be hard to implement unless Phase 4 explicitly adds cursor behavior for attachments. [/REVIEW]
- `ltui issues view <ISSUE_KEY>` emits new keys in stable order.
- No regressions in existing comments/history output snapshots.

### Phase 4: Test Coverage + Mock Alignment

### End State
- Automated tests cover deterministic output, reliable image detection, and download safety.

### Work
- Update mock client in `tools/ltui/src/test-utils/mockLinearClient.ts` to expose `issue.attachments()` in the same shape used by production command code.
- Add CLI help assertion in `tools/ltui/src/__tests__/cli-args.test.ts` for `issues attachments` options.
- Extend regression test in `tools/ltui/src/__tests__/cli-regression.test.ts`:
  - Verify `issues attachments` succeeds and returns expected columns.
  - Verify pagination meta (`CURSOR_NEXT`, `COUNT`) for attachments command.
  - Verify `issues view` includes image guidance fields when fixtures have images.
- Add/extend output contract tests in `tools/ltui/src/__tests__/output.test.ts` for stable attachment headers, field normalization, and key ordering.
- Add tests for:
  - Sort stability.
  - False-negative prevention in image detection.
  - Path traversal protection.
  - Deterministic collision suffixing.
  - Timeout/max-size failure handling.

[REVIEW:Kimi Reviewer] SCOPE DRIFT: The Work section references `cli-args.test.ts` and `output.test.ts` but these files don't exist in the codebase (only `cli-regression.test.ts` exists). This suggests the plan assumes a test structure that hasn't been created yet. Need to either:
1. Create these files as part of Phase 4, OR
2. Consolidate tests into existing `cli-regression.test.ts`

Recommend Option 1 (new files) for better organization, but this must be explicitly called out as file creation work.

Also MISSING: Unit test file location for download safety helpers. Suggest `src/__tests__/attachments.test.ts` for testing path traversal, collision logic, and image classification in isolation without full CLI overhead. [/REVIEW]

[REVIEW:Kimi Reviewer] INCORRECT (repo check): `tools/ltui/src/__tests__/cli-args.test.ts` and `tools/ltui/src/__tests__/output.test.ts` already exist. The real decision is whether to extend those existing tests vs keep everything in `cli-regression.test.ts`, and whether attachments needs a dedicated unit-style test file. Update the plan text to reflect the current test layout so Phase 4 is unambiguous. [/REVIEW]

[REVIEW:GPT5.4] RE: [Kimi Reviewer] - WRONG REFERENCE: In this repo, `tools/ltui/src/__tests__/cli-args.test.ts` and `tools/ltui/src/__tests__/output.test.ts` already exist. The plan’s references here are valid; the remaining question is whether these existing suites are the right place to extend for attachments coverage (vs adding a new focused test file). [/REVIEW]

### Verify
- `bun run test` passes.
- Targeted tests fail when output keys/order or download safety behavior are intentionally perturbed.

### Phase 5: Agent Docs + References

### End State
- Agent-facing docs include attachment retrieval workflow and command reference details.

### Work
- Update skill docs:
  - `opencode/skills/linear/SKILL.md`
  - `skills/linear/SKILL.md`
  with `issues attachments` examples and image workflow.
- Update command references:
  - `opencode/skills/linear/references/ltui-command-reference.md`
  - `skills/linear/references/ltui-command-reference.md`
  with full flags/options and examples.
- Add explicit warning that downloaded files are untrusted and should be treated accordingly.

[REVIEW:Kimi Reviewer] INCORRECT: The plan references `opencode/skills/linear/SKILL.md` and `opencode/skills/linear/references/ltui-command-reference.md`, but based on the codebase structure, the correct paths are:
- `skills/linear/SKILL.md` (exists at root level)
- `skills/linear/references/ltui-command-reference.md` (exists at root level)

There is no `opencode/skills/linear/` directory - this appears to be a copy-paste error. The plan should only reference the root-level `skills/` directory.

Also, the safety warning should explicitly mention that downloaded images may contain malicious content (steganography, polyglot files) and should not be processed by automated tools without validation. [/REVIEW]

[REVIEW:Kimi Reviewer] INCORRECT (repo check): `opencode/skills/linear/SKILL.md` and `opencode/skills/linear/references/ltui-command-reference.md` do exist in this repo, alongside `skills/linear/...`. The plan should clarify the intended doc update policy (update both copies vs designate one canonical source) to avoid drift. [/REVIEW]

[REVIEW:GPT5.4] RE: [Kimi Reviewer] - WRONG REFERENCE: `opencode/skills/linear/SKILL.md` and `opencode/skills/linear/references/ltui-command-reference.md` both exist in this repo (alongside the root-level `skills/linear/...` copies). The plan should keep both targets if the intent is to update both skill trees, or explicitly pick one to avoid drift. [/REVIEW]

### Verify
- Docs include fetch + download examples and `stdout`/`stderr` parsing expectations.
- Docs include untrusted-file safety note.

## Validation Plan

Run from `tools/ltui/`:
- `bun run build`
- `bun run test`

Manual smoke checks (with real auth/profile):
- `ltui issues view <ISSUE_KEY>` shows new attachment hint fields.
- `ltui issues attachments <ISSUE_KEY> --only-images --format json` returns parseable rows.

[REVIEW:GPT5.4] INCORRECT (same as Phase 1): If list output includes pagination meta on `stdout`, this isn’t “parseable JSON” without pre-processing. Update the smoke check text to reflect the actual contract (meta+json vs json-only). [/REVIEW]
- `ltui issues attachments <ISSUE_KEY> --only-images --download-dir ./.ltui-attachments/<ISSUE_KEY>` downloads files.

## Acceptance Criteria

- Agents can detect from `issues view` that image attachments exist and receive explicit command(s) to fetch them.
- Agents can retrieve attachment metadata with deterministic output (stable columns/keys/order and stable stdout/stderr behavior).
- Agents can download image attachments locally when requested, with traversal/collision/timeout/size safeguards.
- New functionality is covered by tests and documented in skill/reference docs.

## Risks and Mitigations

- Attachment metadata may omit content-type.
  - Mitigation: use URL extension fallback for image classification and normalize missing fields.
- Some attachment URLs may require auth/session handling outside standard `fetch`.
- Files on Linear private storage (`https://uploads.linear.app/...`) require authentication.
  - Mitigation: send `Authorization: Bearer <apiKey>` for `uploads.linear.app` downloads OR configure the SDK client to request signed URLs via `public-file-urls-expire-in`.
- Downloading binary assets could increase runtime cost.
  - Mitigation: keep downloads opt-in (`--download-dir` only).
- Large file downloads could hang or exhaust memory.
  - Mitigation: enforce timeout + max file size and stream to disk.
- Downloaded files may contain malicious content.
  - Mitigation: document files as untrusted inputs for downstream agent workflows.

[REVIEW:Kimi Reviewer] GAP: Risk mitigation for "auth/session handling" is insufficient. Linear attachment URLs often require authentication cookies/tokens that `fetch` won't have access to. The mitigation says "surface errors" but doesn't address HOW to handle authenticated URLs. Need to research:
1. Does Linear provide public URLs for attachments or are they always auth-required?
2. If auth is required, can we pass the Linear API token as a header/cookie to the download request?
3. Should we implement a `--with-auth` flag or is this out of scope?

Current mitigation is essentially "fail gracefully" which doesn't actually solve the problem. Recommend clarifying scope: either implement auth header passing or document that only public URLs are supported. [/REVIEW]

## Progress

- [ ] P1 - Phase 1 complete: attachment retrieval + deterministic metadata.
- [ ] P2 - Phase 2 complete: download safety + failure semantics.
- [ ] P3 - Phase 3 complete: reliable view guidance signals.
- [ ] P4 - Phase 4 complete: tests + mock alignment.
- [ ] P5 - Phase 5 complete: docs + references.

[REVIEW:Kimi Reviewer] AMBIGUITY: The Progress checkboxes use stable IDs (P1-P5) which is good, but there's no "Resume from partial phase" guidance. If an agent is interrupted mid-phase, they must restart the entire phase. Consider adding sub-task checkboxes within each phase for finer-grained resumability, OR accept that phases are atomic work units.

Also MISSING: A task to run `bun run build` before final validation. The Validation Plan mentions it, but it's not in the phase work. [/REVIEW]

## Resume Instructions (Agent)

- Start at the first unchecked item in `## Progress`.
- Implement only the mapped phase work for that item.
- Run that phase `### Verify` before marking the progress item complete.
- Update `## Progress` immediately after each phase; do not batch updates.
- Continue directly to the next unchecked phase until all items are complete.
