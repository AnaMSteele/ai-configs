# Architectural Decision Records

This document captures key architectural decisions and their rationale.

## ADR 0001: Add first-class issue attachment retrieval to ltui
**Status:** Accepted (implemented and verified)
**Date:** 2026-04

**Context:** `ltui` needed a deterministic way for agents to discover screenshots and other issue assets from Linear issues. The original working plan also needed JSON-safe pagination metadata for list-style JSON output and a safe way to download image assets locally.

**Decision:**
- Model issue assets as a union of Linear attachment nodes and `uploads.linear.app` URLs discovered in issue descriptions and comments.
- Extend `ltui issues view` with explicit attachment/image guidance fields rather than requiring agents to infer image availability from free-form text.
- Use a JSON envelope with `meta` and `rows` for paginated JSON list output.
- Keep downloads opt-in and enforce path, size, timeout, and symlink safety checks.

**Alternatives considered:**
- Keep `issues view` unchanged and require agents to scrape markdown or comments.
- Support only `issue.attachments()` and ignore uploaded file URLs embedded in descriptions/comments.
- Retain plaintext pagination headers for paginated JSON output instead of emitting a JSON envelope.

**Current state:**
- `tools/ltui/src/commands/issues.ts`
- `tools/ltui/src/format.ts`
- `tools/ltui/src/__tests__/cli-regression.test.ts`
- `tools/ltui/src/__tests__/output.test.ts`

---

<!--
Entries are prepended by /cmd:graduate after completing features.
Format:
## ADR NNNN: [Decision Title]
**Status:** Accepted
**Date:** YYYY-MM

**Context:** ...
**Decision:** ...
**Alternatives considered:** ...
**Current state:** ...
-->
