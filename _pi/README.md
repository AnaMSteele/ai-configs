# Pi Configuration

This directory contains Pi-specific resources:

- `prompts/` — prompt templates exposed as slash commands
- `agents/` — @tintinweb/pi-subagents-compatible agent definitions
- `extensions/` — Pi runtime extensions, including the maintained `/plan` and `/prd` mode workflows

Repo-owned shared installable Pi skills live in the repo-level `skills/` tree, and `skills/install-matrix.json` also inventories package-backed shared skills fetched via `npx skills`. The installed shared runtime location remains `~/.agents/skills`.

The prompt templates are copied from `_omp/commands`, and the agent definitions are ported from `_omp/agents` into the flat markdown format expected by `@tintinweb/pi-subagents`.

## Installation

These resources are installed by `install.sh` to Pi's global agent directory. There are two distinct Pi installation surfaces:

- repo-managed extensions: copied from this repo into `~/.pi/agent/extensions/`
- package-managed Pi installs: registered via `pi install` / `pi update` and visible in `pi list`

`pi list` only shows the package-managed set; it does not list repo-managed files like `todo.ts`, `simple-multi-status.ts`, `pi-plan-mode`, or `pi-prd-mode`. See [Package-managed Pi extensions](#package-managed-pi-extensions) below for the exact git and npm package set.

```bash
./install.sh --pi      # Install Pi prompt templates + subagents + extensions and sync shared skills
./install.sh --all     # Install everything, including Pi
```

Installed layout:

```text
~/.agents/skills/
├── ralph-run/
├── doct-document-ops/
└── ...

~/.pi/agent/
├── APPEND_SYSTEM.md
├── README.md
├── prompts/
│   ├── cmd:debug.md
│   ├── dev:plan.md
│   └── ...
├── agents/
│   ├── developer-mid.md
│   ├── developer-mm.md
│   ├── quality-reviewer.md
│   └── ...
└── extensions/
    ├── pi-plan-mode/
    │   └── index.ts
    ├── pi-prd-mode/
    │   └── index.ts
    ├── simple-multi-status.ts
    ├── percentage-compaction.ts
    └── todo.ts
```

The installer copies the repo-root `APPEND_SYSTEM.md` into `~/.pi/agent/APPEND_SYSTEM.md`. The same shared file is also installed to `~/.omp/agent/APPEND_SYSTEM.md` so Pi and OMP receive the same appended system guidance.

## Structure

```text
_pi/
├── README.md
├── prompts/            # Pi prompt templates / slash commands
│   └── *.md
├── agents/             # Pi subagent definitions for @tintinweb/pi-subagents
│   └── *.md
└── extensions/         # Pi runtime extensions
    ├── */index.ts
    └── *.ts

skills/
├── install-matrix.json # Shared skill inventory used by install.sh
└── */SKILL.md          # Repo-owned shared installable skills exposed to Pi via ~/.agents/skills
```

## Prompt Templates

Pi loads prompt templates from `~/.pi/agent/prompts/`.

Each Markdown file becomes a slash command using the filename:

- `cmd:debug.md` → `/cmd:debug`
- `cmd:execute-plan.md` → `/cmd:execute-plan`
- `dev:plan.md` → `/dev:plan`
- `dev:plan-from-prd.md` → `/dev:plan-from-prd`
- `prd:clarify-round.md` → `/prd:clarify-round`
- `review:change.md` → `/review:change`
- `review:prd.md` → `/review:prd`

Prompt templates in this repo are kept as top-level files in `_pi/prompts/`, so no extra nested prompt-directory discovery is required.

The `/plan` command is provided by the `pi-plan-mode` extension, and the `/prd` command is provided by the `pi-prd-mode` extension, not by prompt templates.

## Extensions

Pi loads runtime extensions from `~/.pi/agent/extensions/`.

This repo now ships a maintained `pi-plan-mode` extension that:

- powers `/plan` mode for `thoughts/` planning workflows,
- keeps planning-mode file writes scoped to `thoughts/`,
- offers `/review:plan` after plan edits,
- automatically follows a standard review with `/review:change-integrate` before any execution handoff,
- optionally offers `/review:plan-adversarial` as a second-pass challenge review after integration,
- offers both `/dev:run <plan>` and `/ralph:run <plan>` as post-review exit paths,
- stages those exit choices through `/cmd:execute-plan <plan> --target ...` so Pi can launch execution from a fresh session,
- keeps alternate review commands such as `/review:change-claude-code` as explicit opt-ins rather than hidden plan-mode fallbacks,
- disables `/plan` mode before dispatching into execution so implementation is not blocked by planning-only restrictions.

This repo also ships a maintained `pi-prd-mode` extension that:

- powers `/prd` mode for PRD/spec workflows,
- keeps PRD-mode writes scoped to `thoughts/plans/prd-*.md`, `thoughts/specs/spec-*.md`, and transient review artifacts under `thoughts/validation/prd-reviews/<prd-slug>/`,
- asks the model to compare each answer round against the intent/spec baseline and use `/prd:clarify-round` for the critical-thinker-first clarification loop,
- keeps `/review:prd` as an explicit review gate instead of auto-running it after edits,
- records PRD review approval in `thoughts/validation/prd-reviews/<prd-slug>/review-status.json`,
- prompts you to run `/review:prd` before handoff whenever the latest PRD review is missing, stale, or not approved,
- offers `/dev:plan-from-prd <prd>` as the reviewed-PRD handoff path,
- disables `/prd` before dispatching into the fresh planning session so PRD mode restrictions do not leak into execution planning.

This repo also ships `simple-multi-status.ts`, a lightweight multi-line status widget that auto-loads on install and shows:

- the active model,
- token, cache, and cost totals,
- multi-pass / multicodex status when present,
- current context-window usage,
- the current working directory.

This repo also ships `percentage-compaction.ts`, which gives you percentage-based control over context compaction:

- set a custom threshold (default 60%) for when compaction should trigger,
- warning notification when crossing the threshold,
- `/compact-status` to check current context usage,
- `/compact-now [instructions]` to trigger compaction manually,
- gates pi's auto-compaction to only occur at or above the threshold,
- **integrates with pi-vcc** for algorithmic (non-LLM) compaction when threshold is reached

To adjust the threshold, edit `COMPACTION_THRESHOLD_PERCENT` in the extension file (default is 60).
To use with pi-vcc, ensure pi-vcc is installed (`pi list` should show `npm:@sting8k/pi-vcc`).

**Note:** With pi-vcc installed, no additional compaction configuration is needed. The extension gates compaction at the percentage threshold, and pi-vcc handles the actual algorithmic compaction when triggered.

This repo also vendors Pi's `todo.ts` extension, which auto-loads on install and provides:

- a `todo` tool for branch-aware task tracking with **proactive planning guidance** — agents are encouraged to create comprehensive todo lists BEFORE beginning work,
- a `/todos` command for inspecting the current branch todo list,
- session-detail persistence so todo state follows Pi branching correctly,
- best practices baked into the tool description: decompose tasks into small steps, update progress as you go, keep todos specific and measurable.

## Subagents

Pi subagents load agent definitions from `~/.pi/agent/agents/`.

## Package-managed Pi extensions

In addition to the repo-managed files under `~/.pi/agent/extensions/`, `install.sh --pi` also registers Pi packages via `pi install` / `pi update`. These are the entries that appear in `pi list`.

Git-managed packages:
- `chrome-cdp-skill`
- `pi-rlm`

npm-managed packages:
- `@tintinweb/pi-subagents`
- `@aliou/pi-processes`
- `pi-web-access`
- `pi-mcp-adapter`
- `lsp-pi`
- `@fnnm/pi-ast-grep`
- `pi-updater`
- `pi-interactive-shell`
- `pi-powerline-footer`
- `@marckrenn/pi-sub-bar`
- `pi-side-agents`
- `pi-multi-pass`
- `pi-no-soft-cursor`
- `@tmustier/pi-files-widget`
- `@tmustier/pi-raw-paste`
- `@sting8k/pi-vcc`

Use `pi list` on a host to verify what is currently registered. To verify both surfaces together, run `scripts/verify-pi-install.sh` from this repo.

These files are based on `_omp/agents`, but normalized for the `@tintinweb/pi-subagents` loader:

- every agent has a `name`
- `tools` is flattened to a comma-separated built-in Pi tool list when possible
- unsupported OMP-only nested permission/tool metadata is omitted from the frontmatter used by `@tintinweb/pi-subagents`

Example installed agents:

- `developer-mid`
- `developer-mm`
- `quality-reviewer`
- `research`
- `plan-gpt5.4`
- `reviewer-plan-adversarial-gpt5.4`
- `reviewer-plan-adversarial-opus`
- `worktree-creator`

## Skills Overview

### Ralph / execution
- `ralph-run` — quality-gated execution loop
- `ralph-run-simple` — simpler single-pass execution

### Git / workflow
- `cmd-create-pr`
- `cmd-start-linear-issue`
- `cmd-start-linear-issue-branch`

### Development
- `cmd-research`
- `cmd-debug`
- `dev-plan`
- `cmd-graduate`
- `doct-document-ops` — doct document operations, including publishing coding plans under personal `Coding Plans`
- `sentry-cli` — investigate Sentry orgs, projects, issues, and recent events; optionally mute/resolve/unresolve issues after confirmation

### Context / review
- `cmd-create-handoff`
- `cmd-resume-handoff`
- `review-plan`
- `review-plan-adversarial`
- `review-change`
- `review-change-integrate`
- `review-change-kimi`
- `review-change-opus`
- `review-change-claude-code` — direct Claude Code review-only pass via pi-interactive-shell hands-free launch, then backgrounded

## Usage

Prompt templates:

```text
/cmd:debug login flake in CI
/dev:plan feature-name
/prd
/prd:clarify-round thoughts/plans/prd-my-feature.md
/review:plan thoughts/plans/my-plan.md
/review:plan-adversarial thoughts/plans/my-plan.md
/review:prd thoughts/plans/prd-my-feature.md
/review:change thoughts/plans/my-plan.md
/review:change-kimi thoughts/plans/my-plan.md
/review:change-opus thoughts/plans/my-plan.md
/review:change-claude-code thoughts/plans/my-plan.md
/cmd:execute-plan thoughts/plans/my-plan.md
/dev:plan-from-prd thoughts/plans/prd-my-feature.md
/cmd:send-plan-to-doct thoughts/plans/my-plan.md
```

## Reviewed-plan handoff

Use `/cmd:execute-plan <plan>` after a reviewed plan is ready to continue.

Canonical reviewed-plan flow:

```text
/dev:plan <plan>
/review:plan <plan>
/review:change-integrate <plan>
/review:plan-adversarial <plan>   # optional
/cmd:execute-plan <plan>
```

Optional second pass: run `/review:plan-adversarial <plan>` after `/review:change-integrate <plan>` when you want an explicit challenge review before execution.

- It is the canonical wrapper for choosing between `/dev:run <plan>` and `/ralph:run <plan>`.
- In Pi `/plan` mode, the extension offers both execution paths as post-review exit choices and stages this handoff command for the selected target.
- When that extension path is used, `/plan` mode is disabled before execution so planning-only tool restrictions do not leak into implementation.
- In Pi, the handoff command starts a fresh session and then launches the selected execution flow from that clean context.
- `/review:change-claude-code` remains available for an explicit manual review request, but it is not part of the automatic `/plan`-mode review-to-execution path.

Use `/dev:plan-from-prd <prd>` after a reviewed PRD delta is ready to become an execution plan.

The sequence below is the end-to-end reviewed-PRD path from PRD entry through handoff. Clarification continues in `/prd` and `/prd:clarify-round` until complete before the operator runs `/review:prd`.

```text
/prd
/review:prd thoughts/plans/prd-my-feature.md
/dev:plan-from-prd thoughts/plans/prd-my-feature.md
```

- It is the canonical wrapper for turning a reviewed PRD delta into a fresh single-file plan session.
- In Pi `/prd` mode, the typical sequence is `/prd` → update the PRD with the latest user answers → `/prd:clarify-round` → repeat that clarification loop as needed → `/review:prd` when a wider review is worthwhile → `/dev:plan-from-prd <prd>` after an approved review result.
- `/review:prd` is the explicit review gate before `/dev:plan-from-prd`.
- `/review:prd` writes seven per-reviewer files under `thoughts/validation/prd-reviews/<prd-slug>/`, integrates the combined findings back into the PRD, keeps `integration-ledger.md` plus `review-status.json`, and removes the seven reviewer output files after integration.
- `/dev:plan-from-prd` validates that `thoughts/validation/prd-reviews/<prd-slug>/review-status.json` exists, is approved, and is not older than the PRD.
- If the latest review result for the same PRD is `needs_changes`, resolve the inline `[REVIEW:...]` comments in that PRD and rerun `/review:prd <prd-path>`.
- If the latest review result for the same PRD is `review_failed`, inspect `thoughts/validation/prd-reviews/<prd-slug>/integration-ledger.md` for the failed reviewer row(s) and notes, resolve the failed review-cycle cause(s), and rerun `/review:prd <prd-path>`.
- If the latest review result for the same PRD is stale, or the same PRD does not yet have a current approved review result, rerun `/review:prd <prd-path>` before handoff.
- The extension does not auto-run `/review:prd`; that gate is explicit and should happen only once the intent is clarified.
- When the handoff path is used, `/prd` mode is disabled before planning so PRD-only tool restrictions do not leak into execution planning.
- In Pi, the handoff command starts a fresh session and then continues the planning work from that clean context.

Skills:

```text
/skill:ralph-run user-profile-redesign
/skill:cmd-start-linear-issue-branch ENG-123
/skill:doct-document-ops
/skill:sentry-cli
```

## Notes

- Pi global resources live under `~/.pi/agent/`, not `~/.pi/`.
- Repo-managed extensions live in `~/.pi/agent/extensions/`; package-managed installs are reported by `pi list`.
- `~/.pi/agent/APPEND_SYSTEM.md` is installed from the repo-root `APPEND_SYSTEM.md` shared with OMP.
- Project-local Pi resources can also live under `.pi/prompts/`, `.pi/skills/`, `.pi/agents/`, and `.pi/extensions/`.
- Pi natively auto-discovers both `~/.agents/skills/` and `~/.pi/agent/skills/`; this repo uses `~/.agents/skills/` as the canonical shared runtime location and reserves `~/.pi/agent/skills/` for Pi-local-only entries. Repo-owned skill payloads come from `skills/`, while package-backed entries are fetched per `skills/install-matrix.json`.
- `@tintinweb/pi-subagents`-compatible agent definitions install to `~/.pi/agent/agents/`.
