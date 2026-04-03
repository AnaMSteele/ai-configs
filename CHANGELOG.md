# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

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
