---
name: cmd-graduate
description: Graduate completed work from thoughts/ directory to permanent spec/ documentation. Use when a feature is complete and ready for long-term documentation.
---

# Graduate Completed Work

Move completed features from the working `thoughts/` directory to permanent `spec/` documentation.

## Usage

```
/skill:cmd-graduate <plan-slug-or-path>
```

## Output Locations

Graduated features move to:
- `spec/architecture/[feature].md` - Feature architecture documents
- `spec/architecture/README.md` - Architecture index (updated)
- `spec/adr-log.md` - Architectural decision records (if applicable)
- `CHANGELOG.md` - Implementation summaries appended

## Process

### 1) Resolve Source

If argument is:
- A path: use it directly
- A slug: resolve using repo-local active plan guidance; do not infer a markdown path

### 2) Read and Summarize

Read the completed plan and extract:
- Feature name and purpose
- Key architectural decisions
- Implementation approach
- Important technical details worth preserving

### 3) Create Architecture Document

Write to `spec/architecture/[feature-slug].md`:

```markdown
---
date: [YYYY-MM-DD]
author: [author from plan]
original_plan: <plan_path>
status: graduated
---

# [Feature Name]

## Purpose
[What this feature does]

## Architecture
[Key components and design]

## Decisions
[Important technical decisions made]

## Implementation Notes
[Technical details for future reference]

## Related
- Original plan: `<plan_path>`
- [Other related docs]
```

### 4) Update Architecture Index

Update `spec/architecture/README.md` to include the new feature.

### 5) Update Changelog

Append to `CHANGELOG.md`:

```markdown
## [YYYY-MM-DD] - [Feature Name]

- Graduated from: `<plan_path>`
- Summary: [Brief description]
- Architecture: `spec/architecture/[feature-slug].md`
```

### 6) Report

- Architecture document location
- Index update status
- Changelog entry added
