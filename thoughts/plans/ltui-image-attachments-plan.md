# ltui Image Attachment Fetching Plan

## Objective

Add first-class attachment retrieval to `ltui` so agents can reliably discover and fetch screenshots/images from Linear issues, and receive deterministic instructions directly from `ltui issues view` when image attachments are present.

## Requested Outcomes

1. `ltui issues view <issue>` should emit explicit guidance fields when image attachments exist.
2. `ltui` should provide a command to fetch issue attachments (metadata and optional file download).

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

## Proposed CLI Contract

### 1) `ltui issues attachments <issue-id-or-key>`

Behavior:
- Resolves issue by id/key (same behavior as existing issues commands).
- Fetches issue attachments via SDK (`issue.attachments(...)`).
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
- `downloadStatus` (`downloaded|exists|failed:<reason>|`)

### 2) `ltui issues view <issue>` enhancements

Add deterministic fields to `ISSUE_DETAIL` block:
- `ATTACHMENTS_PRESENT: true|false`
- `IMAGE_ATTACHMENTS_PRESENT: true|false`
- `IMAGE_ATTACHMENTS_FETCH_CMD: <command>` (only when image attachments exist)
- `IMAGE_ATTACHMENTS_DOWNLOAD_CMD: <command>` (only when image attachments exist)

Example emitted guidance:
- `IMAGE_ATTACHMENTS_FETCH_CMD: ltui issues attachments ENG-42 --only-images --format json`
- `IMAGE_ATTACHMENTS_DOWNLOAD_CMD: ltui issues attachments ENG-42 --only-images --download-dir ./.ltui-attachments/ENG-42`

## Implementation Plan

### Phase 1 - Attachment Retrieval + Classification

- [ ] Add attachment row model + render columns in `tools/ltui/src/commands/issues.ts`.
- [ ] Implement `issues attachments` command registration, options, and action handler.
- [ ] Add image classification helper:
  - Primary: `metadata.contentType` starts with `image/`.
  - Fallback: image-like URL extension (`.png`, `.jpg`, `.jpeg`, `.gif`, `.webp`, `.svg`).
- [ ] Support cursor/limit passthrough and existing `renderList` output behavior.

### Phase 2 - Optional Download Support

- [ ] Add download helpers in `tools/ltui/src/commands/issues.ts`:
  - URL validation (`http/https` only).
  - Stream download to file.
  - Deterministic filename generation and sanitization.
  - Extension inference from URL/content-type.
- [ ] Ensure `--download-dir` creates directories recursively.
- [ ] Set `process.exitCode = 1` if one or more downloads fail, while still printing all rows.

### Phase 3 - View Output Guidance

- [ ] In `issues view`, query a small attachment page (e.g., first 25) for summary only.
- [ ] Emit new `ISSUE_DETAIL` fields listed above.
- [ ] Keep existing description/comments/history output unchanged.

### Phase 4 - Test Coverage

- [ ] Update mock client in `tools/ltui/src/test-utils/mockLinearClient.ts` to expose `issue.attachments()` with at least one image attachment fixture.
- [ ] Add CLI help assertion in `tools/ltui/src/__tests__/cli-args.test.ts` for `issues attachments` options.
- [ ] Extend regression test in `tools/ltui/src/__tests__/cli-regression.test.ts`:
  - Verify `issues attachments` succeeds and returns expected columns.
  - Verify `issues view` includes new image guidance fields when fixture has image.
- [ ] Add/extend output contract tests in `tools/ltui/src/__tests__/output.test.ts` for stable attachment headers/fields.

### Phase 5 - Agent Docs

- [ ] Update both skill docs:
  - `opencode/skills/linear/SKILL.md`
  - `skills/linear/SKILL.md`
  to include `issues attachments` examples and image workflow.
- [ ] Update both command references:
  - `opencode/skills/linear/references/ltui-command-reference.md`
  - `skills/linear/references/ltui-command-reference.md`
  with full flags/options and examples.

## Validation Plan

Run from `tools/ltui/`:

- [ ] `bun run build`
- [ ] `bun run test`

Manual smoke checks (with real auth/profile):
- [ ] `ltui issues view <ISSUE_KEY> --format detail` shows new attachment hint fields.
- [ ] `ltui issues attachments <ISSUE_KEY> --only-images --format json` returns parseable rows.
- [ ] `ltui issues attachments <ISSUE_KEY> --only-images --download-dir ./.ltui-attachments/<ISSUE_KEY>` downloads files.

## Acceptance Criteria

- Agents can detect from `issues view` that image attachments exist and receive explicit command(s) to fetch them.
- Agents can retrieve attachment metadata with deterministic output.
- Agents can download image attachments locally when requested.
- New functionality is covered by tests and documented in skill/reference docs.

## Risks and Mitigations

- Attachment metadata may omit content-type.
  - Mitigation: use URL extension fallback for image classification.
- Some attachment URLs may require auth/session handling outside standard `fetch`.
  - Mitigation: surface row-level `downloadStatus=failed:<reason>` and non-zero exit when failures occur.
- Downloading binary assets could increase runtime cost.
  - Mitigation: keep downloads opt-in (`--download-dir` only).
