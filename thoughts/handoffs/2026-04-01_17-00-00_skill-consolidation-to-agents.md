---
date: 2026-04-01 17:00:00
author: pi
repo: /home/anichols/code/ai-configs
git_commit: a9e31f1fb81e9b2a76f9f5c2ed3668cdc05427d4
branch: main
type: handoff
status: active
---

# Handoff: consolidate shared skills into `skills/` and install via `~/.agents/skills`

## Current context
The user wants `~/code/ai-configs` to become the canonical source of truth for all **installable/shared** skills across Pi, OpenCode, OMP, and related agent harnesses.

Key policy decision from user:
- `skills/` should be the **single canonical shared/installable** skill source.
- Dotted directories like `.agents/` are **repo-local only** and should be reserved for agent behavior when operating *against the `ai-configs` repo itself*.
- Shared skills should install into `~/.agents/skills`.
- Other agent-specific locations should use symlinks pointing back to `~/.agents/skills`.
- OMP should rely on `~/.agents/skills` rather than maintaining a separate divergent skill tree.

## Important findings already established

### 1) Current repo layout already has multiple competing skill trees
Relevant trees in `~/code/ai-configs`:
- `skills/`
- `.agents/skills/`
- `opencode/skills/`
- `_pi/skills/`
- `_omp/...` assets also exist, though `_omp` appears to be more command/agent focused than a clean shared skill source.

This means there is already drift / duplication risk about which tree is canonical.

### 2) Existing installer behavior is not aligned with the desired model
`install.sh` currently still includes behavior that copies OpenCode skills directly into:
- `~/.config/opencode/skills`

There are also docs that assume direct-copy OpenCode skill installation, e.g.:
- `OPENCODE_ONBOARDING.md`
- `opencode/OPENCODE_ONBOARDING.md`
- `opencode/QUICKSTART.md`

### 3) Repo currently has local uncommitted changes unrelated to this handoff
At handoff time, `~/code/ai-configs` was already dirty:
```bash
 M AGENTS.md
 M _pi/README.md
 M _pi/prompts/review:plan.md
 M install.sh
?? _pi/skills/sentry-cli/
```
Do **not** assume a clean tree before starting. First inspect whether these changes are intentional in-flight work that must be preserved.

### 4) Home-directory skills were audited on this machine
Outside the repo, I audited the current machine's installed skill locations.

#### `~/.agents/skills`
- 17 skills
- effectively pi-compatible already
- `tdd-test-writer` is valid and loadable
- only minor nit before fix was `ccore` lacking explicit `name:`; pi can tolerate this, but it was corrected locally

#### `~/.config/opencode/skills`
- 28 skills
- mostly usable
- had a few naming/frontmatter issues (`design-skill`, `playwright-skill`, `template`) that were corrected locally on this machine

#### `~/.omp`
- 48 `SKILL.md` files found
- many looked like memory-derived / ad hoc skill notes rather than clean shared skills
- many originally lacked compliant frontmatter and some had invalid underscore directory names
- these were corrected locally on this machine as a one-off compliance pass

**Important:** those home-directory fixes were made directly in `~/.agents`, `~/.config/opencode`, and `~/.omp` on this machine. They are **not yet represented canonically in `ai-configs`**. Treat the repo as the source of truth to be repaired, not the home directory.

## Design direction agreed with user
Recommended approach was accepted:

### Canonical source
- All shared/installable skills live in:
  - `skills/<skill-name>/...`

### Repo-local-only skills
- Keep repo-local-only behavior in dotted dirs, e.g.:
  - `.agents/skills/...`
- Those should **not** be treated as part of the installable shared skill cohort.

### Install model
- Install shared skills to:
  - `~/.agents/skills/<skill-name>`
- Then create symlinks from consumer-specific locations back to `~/.agents/skills`, e.g.:
  - `~/.config/opencode/skills/<skill-name> -> ~/.agents/skills/<skill-name>`
- OMP should rely on `~/.agents/skills` rather than its own divergent skill copies.
- Pi already reads `~/.agents/skills`, so no pi-specific adapter layer is desired.

## Recommended execution plan

### Phase 1: inventory and classification
1. Inventory all skill directories in:
   - `skills/`
   - `.agents/skills/`
   - `opencode/skills/`
   - `_pi/skills/`
   - any relevant `_omp` skill-like assets if present
2. Classify each as one of:
   - shared/installable canonical skill
   - repo-local-only skill
   - obsolete duplicate
   - agent-specific wrapper/doc that should not live in shared `skills/`
3. Produce a duplication map by skill name and by content similarity.

### Phase 2: canonicalize into `skills/`
1. Move or merge all shared/installable skills into `skills/`.
2. Preserve full skill payloads, not just `SKILL.md`:
   - `references/`
   - `scripts/`
   - assets
   - package files if part of the skill
3. Normalize all shared skill names to pi/Agent Skills compliant directory names.
4. Update each shared `SKILL.md` to compliant frontmatter if needed.

### Phase 3: reduce duplicates and redefine local-only trees
1. Remove shared/installable duplicates from:
   - `opencode/skills/`
   - `_pi/skills/` when they are just duplicated shared skills
2. Keep `.agents/skills/` only for repo-local skills that matter when an agent is operating against `ai-configs` itself.
3. If an agent-specific tree still needs a path to exist in-repo for tests/docs/tooling, make it a deliberate mirror or symlink strategy rather than a separate hand-maintained source.

### Phase 4: installer refactor
Refactor `install.sh` so that:
1. shared skills install to `~/.agents/skills`
2. OpenCode skill installation becomes symlink-based from `~/.config/opencode/skills` to `~/.agents/skills`
3. OMP does not create a separate divergent installable skill source if it already reads `~/.agents/skills`
4. `--skills` semantics clearly mean shared skills, not Claude-only skills
5. any legacy direct-copy behavior is either removed or intentionally retained only where symlinks are impossible

### Phase 5: docs and references
Update docs to match the new source-of-truth model:
- `README.md`
- `SETUP.md`
- `OPENCODE_ONBOARDING.md`
- `opencode/OPENCODE_ONBOARDING.md`
- `opencode/QUICKSTART.md`
- any README under `_pi/` or agent-specific areas that references old skill locations
- any commands/docs that hardcode `~/.config/opencode/skills/...` paths when they should resolve via shared install conventions

### Phase 6: validation
Validate on at least this machine:
1. shared skills install into `~/.agents/skills`
2. symlinks exist and resolve correctly from OpenCode locations
3. Pi sees shared skills via `~/.agents/skills`
4. OpenCode sees the symlinked shared skills
5. OMP behavior is still correct when relying on `~/.agents/skills`
6. no broken relative-path assumptions inside skills after relocation

## Specific cautions
- Some skills contain extra files and scripts; do not move only `SKILL.md`.
- Relative paths inside skill docs matter. When relocating skills, verify internal references still resolve.
- The local one-off compliance edits done outside the repo may be useful as reference, but avoid blindly copying home-directory state back into the repo without reviewing whether it reflects the desired canonical structure.
- Be careful with the already-dirty `ai-configs` worktree before making broad install/doc changes.

## Suggested first commands in `~/code/ai-configs`
```bash
cd ~/code/ai-configs
git status --short
find skills .agents/skills opencode/skills _pi/skills -maxdepth 2 -name 'SKILL.md' 2>/dev/null | sort
rg -n "~/.config/opencode/skills|~/.agents/skills|opencode/skills|_pi/skills|install.*skills|Installing .*skills" install.sh README.md SETUP.md OPENCODE_ONBOARDING.md opencode -S
```

## Desired end state
- `skills/` is the only canonical shared/installable skill source in the repo
- `.agents/skills/` is reserved for repo-local-only agent behavior
- install flow populates `~/.agents/skills`
- OpenCode consumes shared skills via symlinks to `~/.agents/skills`
- OMP relies on `~/.agents/skills`
- duplicated skill trees are removed or made explicitly generated
- docs consistently describe the new model

## Notes for the next agent
This work should indeed be done from `~/code/ai-configs`, not from `/home/anichols/code/doct-1`.

If you need to reference the machine-local compliance pass, inspect:
- `~/.agents/skills`
- `~/.config/opencode/skills`
- `~/.omp`

But prefer rebuilding the correct structure from repo sources instead of treating the home dirs as authoritative.
