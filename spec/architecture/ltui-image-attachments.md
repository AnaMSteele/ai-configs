# ltui Image Attachments System

**Last Updated:** 2026-04-03
**Status:** ✅ Implemented

## Overview

`ltui` now includes a first-class issue-asset surface for Linear issues. The implementation adds `ltui issues attachments <issue>` for deterministic attachment discovery and optional local downloads, and extends `ltui issues view <issue>` with explicit attachment/image guidance fields so agents can discover screenshots without guessing.

The shipped behavior covers both native Linear link attachments and `uploads.linear.app` URLs discovered in issue descriptions and comments.

## CLI Contracts

### `ltui issues attachments <identifier>`

Implemented in `Nodaste-Lab/ltui/src/commands/issues.ts`.

Supported options:
- `--only-images`
- `--download-dir <dir>`
- `--overwrite`
- `--no-linear-attachments`
- `--no-upload-urls`
- `--no-scan-comments`

List output is deterministic:
- rows are sorted by `createdAt` descending, then `id` ascending
- optional text fields normalize to empty strings
- download fields are always present: `downloadPath`, `downloadStatus`, `downloadError`

For `--format json`, paginated list output is emitted as a JSON envelope:

```json
{
  "meta": {
    "cursorNext": "",
    "cursorPrev": "",
    "count": 1
  },
  "rows": [
    {
      "id": "..."
    }
  ]
}
```

### `ltui issues view <identifier>`

Issue detail output now emits:
- `ATTACHMENTS_PRESENT`
- `IMAGE_ATTACHMENTS_PRESENT`
- `IMAGE_ATTACHMENTS_FETCH_CMD`
- `IMAGE_ATTACHMENTS_DOWNLOAD_CMD`

The image probe pages through issue attachments until an image is found or the attachment connection is exhausted, and also checks `uploads.linear.app` references in the issue description and comments.

## Data Flow

1. Resolve the Linear issue by key or ID.
2. Build asset rows from:
   - `issue.attachments()`
   - `uploads.linear.app` URLs extracted from the description
   - `uploads.linear.app` URLs extracted from comments
3. Classify image-like assets by content type first, then by URL extension fallback.
4. Render deterministic list output with pagination metadata.
5. When download mode is enabled, stream each asset to disk and annotate the output row with final download status.

## Behaviors

- Agents can detect screenshots from `ltui issues view` without parsing prose.
- Agents can fetch attachment metadata independently with a stable command surface.
- Agents can limit results to image-like assets with `--only-images`.
- Agents can optionally download assets locally into a caller-controlled directory.
- Download attempts do not suppress row output; failures are surfaced in-row and through process exit code.

## Constraints

- Downloads are opt-in and occur only when `--download-dir` is supplied.
- Only `http` and `https` URLs are fetched.
- JSON list output uses a JSON envelope for paginated list commands.
- Attachment discovery includes uploads embedded in markdown, not only first-party Linear attachment nodes.

## Configuration

Implemented defaults in `Nodaste-Lab/ltui/src/commands/issues.ts`:
- download timeout: `30_000` ms
- maximum download size: `100 * 1024 * 1024` bytes

## Security

- Download directories must not be symlinks.
- Existing symlink targets are refused during overwrite/write selection.
- Filenames are sanitized before writing.
- Large downloads are capped with a byte-limit transform.
- `uploads.linear.app` downloads use the configured Linear API key as a bearer token.
- Downloaded files should be treated as untrusted input by downstream tooling.

## Testing

Verified in `Nodaste-Lab/ltui` with:
- `bun run test`

Relevant coverage includes:
- `Nodaste-Lab/ltui/src/__tests__/cli-args.test.ts`
- `Nodaste-Lab/ltui/src/__tests__/cli-regression.test.ts`
- `Nodaste-Lab/ltui/src/__tests__/output.test.ts`
- `Nodaste-Lab/ltui/src/test-utils/mockLinearClient.ts`

The current regression suite covers attachment command help, pagination envelopes, issue-detail guidance fields, and end-to-end command success.

## Integration Points

- `skills/linear/SKILL.md`
- `skills/linear/references/ltui-command-reference.md`
- `Nodaste-Lab/ltui/src/commands/issues.ts`
- `Nodaste-Lab/ltui/src/format.ts`

## Implementation Notes

- This implementation changed JSON pagination behavior from plaintext cursor headers to a JSON envelope for paginated JSON list output.
- The final implementation exceeded the original plan in one useful way by including upload URLs discovered in issue descriptions and comments, not only `issue.attachments()` rows.
- The original working plan was `thoughts/plans/ltui-image-attachments-plan.md` and is preserved in git history after graduation cleanup.
