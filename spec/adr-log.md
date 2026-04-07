# Architectural Decision Records

This document captures key architectural decisions and their rationale.

## ADR 0002: Add an OpenCode-native `review:plan` wrapper on top of existing reviewer surfaces
**Status:** Accepted (implemented and verified)
**Date:** 2026-04

**Context:** OpenCode already had stronger single-reviewer review commands (`review:change-gpt5.4` and `review:change-k2.5`) but lacked an explicit `review:plan` entrypoint. Pi had a reviewed-plan wrapper, but its prompt depended on Pi-specific reviewer agents, model strings, and transport assumptions that should not be copied into OpenCode unchanged.

**Decision:**
- Add `_opencode/commands/review:plan.md` as a review-only wrapper command instead of replacing the existing `review:change*` commands.
- Reuse the existing OpenCode reviewer agents `reviewer-gpt5.4` and `reviewer-kimi` plus their current provider/model configuration.
- Normalize the reviewed plan path once, launch both reviewer legs in parallel with `Task`, wait for both results, and stop before `/review:change-integrate`.
- Report reviewer-leg failures explicitly instead of silently falling back to another reviewer.

**Alternatives considered:**
- Copy `_pi/prompts/review:plan.md` literally, including Pi-only `reviewer-plan-*` agents and Pi model/provider strings.
- Add compatibility aliases such as `review:change-kimi.md` as part of the same change.
- Expand the change to include adversarial review, PRD workflow parity, or Pi interactive review transports.

**Current state:**
- `_opencode/commands/review:plan.md`
- `_opencode/commands/review:change-gpt5.4.md`
- `_opencode/commands/review:change-k2.5.md`
- `_opencode/agents/reviewer-gpt5.4.md`
- `_opencode/agents/reviewer-kimi.md`
- `install.sh`

---

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
