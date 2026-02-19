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
- Attachment rows are sorted by `createdAt` descending, then `id` ascending for tie-breaking.
- Missing optional fields are normalized to empty strings (`""`) in table/tsv/json rows.
- `downloadStatus` is one of: `downloaded`, `exists`, `failed`, ``.
- `downloadError` is an empty string unless `downloadStatus=failed`.

## Proposed CLI Contract

### 1) `ltui issues attachments <issue-id-or-key>`

Behavior:
- Resolves issue by id/key (same behavior as existing issues commands).
- Fetches issue attachments via SDK (`issue.attachments({ first, after })` if available in SDK shape).
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
- `contentType`
- `isImage` (`true|false`)
- `createdAt`
- `downloadPath` (empty unless `--download-dir`)
- `downloadStatus` (`downloaded|exists|failed|`)
- `downloadError` (empty unless failed)

Download behavior:
- Filename sanitization blocks path traversal and strips unsafe path segments.
- Collision handling is deterministic suffixing (`name.ext`, `name-1.ext`, `name-2.ext`, ...).
- If `--overwrite` is set, target file path is replaced directly.
- Command exits non-zero on one or more failed downloads; still prints full row output.
- Skipped existing files (without `--overwrite`) remain exit code `0` and use `downloadStatus=exists`.
- Download timeout and max file size limits are enforced to prevent hangs/OOM.
- Only `http`/`https` URLs are fetched.

### 2) `ltui issues view <issue>` enhancements

Add deterministic fields to `ISSUE_DETAIL` block (append after existing keys):
- `ATTACHMENTS_PRESENT: true|false`
- `IMAGE_ATTACHMENTS_PRESENT: true|false`
- `IMAGE_ATTACHMENTS_FETCH_CMD: <command>` (only when image attachments exist)
- `IMAGE_ATTACHMENTS_DOWNLOAD_CMD: <command>` (only when image attachments exist)

Detection requirements:
- `IMAGE_ATTACHMENTS_PRESENT` must not produce false negatives due to pagination.
- Use a reliable existence check (SDK filter/count if available, otherwise bounded paging until first image).

Example emitted guidance:
- `IMAGE_ATTACHMENTS_FETCH_CMD: ltui issues attachments ENG-42 --only-images --format json`
- `IMAGE_ATTACHMENTS_DOWNLOAD_CMD: ltui issues attachments ENG-42 --only-images --download-dir ./.ltui-attachments/ENG-42`

## Implementation Plan

### Phase 1: Attachment Retrieval + Deterministic Metadata

### End State
- `issues attachments` exists, returns attachment rows, and follows deterministic output contract.
- Null/missing fields are normalized consistently.

### Work
- Add attachment row model and render columns in `tools/ltui/src/commands/issues.ts`.
- Implement `issues attachments` command registration, options, and action handler.
- Add image classification helper:
  - Primary: `metadata.contentType` starts with `image/`.
  - Fallback: image-like URL extension (`.png`, `.jpg`, `.jpeg`, `.gif`, `.webp`, `.svg`).
- Support cursor/limit passthrough and existing `renderList` output behavior.
- Define explicit sort order (`createdAt` desc, tie-breaker `id` asc).
- Normalize optional fields (`sourceType`, `subtitle`, `contentType`) to empty strings.
- Keep structured output on `stdout` and diagnostics on `stderr`.

### Verify
- `bun run test -- issues` (or closest scoped test target) passes for attachments command behavior.
- Manual check: `ltui issues attachments <ISSUE_KEY> --format json` emits parseable JSON rows and no logs on `stdout`.
- Manual check: output order is stable across repeated runs with identical fixture data.

### Phase 2: Download Safety + Failure Semantics

### End State
- Optional download mode is safe by default and deterministic under collisions/failures.

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

### Verify
- Test fixture where image exists beyond first page still yields `IMAGE_ATTACHMENTS_PRESENT: true`.
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
  - Mitigation: surface row-level `downloadStatus`/`downloadError` and non-zero exit on failed downloads.
- Downloading binary assets could increase runtime cost.
  - Mitigation: keep downloads opt-in (`--download-dir` only).
- Large file downloads could hang or exhaust memory.
  - Mitigation: enforce timeout + max file size and stream to disk.
- Downloaded files may contain malicious content.
  - Mitigation: document files as untrusted inputs for downstream agent workflows.

## Progress

- [ ] P1 - Phase 1 complete: attachment retrieval + deterministic metadata.
- [ ] P2 - Phase 2 complete: download safety + failure semantics.
- [ ] P3 - Phase 3 complete: reliable view guidance signals.
- [ ] P4 - Phase 4 complete: tests + mock alignment.
- [ ] P5 - Phase 5 complete: docs + references.

## Resume Instructions (Agent)

- Start at the first unchecked item in `## Progress`.
- Implement only the mapped phase work for that item.
- Run that phase `### Verify` before marking the progress item complete.
- Update `## Progress` immediately after each phase; do not batch updates.
- Continue directly to the next unchecked phase until all items are complete.
