# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [OpenCode `review:plan` wrapper] - 2026-04-06

### Added

- Added `_opencode/commands/review:plan.md` as a first-class OpenCode reviewed-plan entrypoint.
- The new wrapper normalizes a single plan path, launches the existing GPT5.4 and Kimi review legs in parallel, and returns a combined review-only summary.

### Changed

- OpenCode reviewed-plan flow is now discoverable without requiring users to invoke the lower-level `review:change*` surfaces directly.
- Runtime verification clarified that OpenCode command changes must be installed into `~/.config/opencode/commands` before `opencode run` sees them.

### Technical Notes

- The wrapper intentionally reuses `_opencode/commands/review:change-gpt5.4.md`, `_opencode/commands/review:change-k2.5.md`, `reviewer-gpt5.4`, and `reviewer-kimi` instead of adding Pi-specific `reviewer-plan-*` agents.
- Verified against the completed plan and live CLI behavior; the wrapper launched both review legs and stopped before integration, while the Kimi leg failed in this environment with `ProviderModelNotFoundError` and is documented as an operational constraint.

## [ltui image attachments] - 2026-04-03

### Added

- Added `ltui issues attachments <issue>` for deterministic asset discovery across Linear attachments and `uploads.linear.app` links found in issue descriptions/comments.
- Added `ATTACHMENTS_PRESENT`, `IMAGE_ATTACHMENTS_PRESENT`, `IMAGE_ATTACHMENTS_FETCH_CMD`, and `IMAGE_ATTACHMENTS_DOWNLOAD_CMD` fields to `ltui issues view`.

### Changed

- Paginated JSON list output now uses a JSON envelope with `meta` and `rows` instead of plaintext pagination headers for JSON mode.
- Linear skill docs now include attachment retrieval/download examples and an explicit untrusted-file warning.

### Technical Notes

- Downloads are opt-in, streamed to disk, guarded against unsafe paths/symlinks, and capped by timeout and max-size checks.
- Verified with `bun run test` in `tools/ltui`, including attachment and JSON-envelope regression coverage.

<!--
Entries are added by /cmd:graduate after completing features.
Format:
## [Feature Name] - YYYY-MM-DD
### Added/Changed/Fixed
- Description of change
-->
