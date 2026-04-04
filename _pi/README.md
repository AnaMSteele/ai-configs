# Pi Configuration

This directory contains Pi-specific resources:

- `prompts/` — prompt templates exposed as slash commands
- `agents/` — @tintinweb/pi-subagents-compatible agent definitions
- `extensions/` — Pi runtime extensions, including the maintained `/plan` mode workflow

Repo-owned shared installable Pi skills live in the repo-level `skills/` tree, and `skills/install-matrix.json` also inventories package-backed shared skills fetched via `npx skills`. The installed shared runtime location remains `~/.agents/skills`.

The prompt templates are copied from `_omp/commands`, and the agent definitions are ported from `_omp/agents` into the flat markdown format expected by `@tintinweb/pi-subagents`.

## Installation

These resources are installed by `install.sh` to Pi's global agent directory. There are two distinct Pi installation surfaces:

- repo-managed extensions: copied from this repo into `~/.pi/agent/extensions/`
- package-managed Pi installs: registered via `pi install` / `pi update` and visible in `pi list`

`pi list` only shows the package-managed set; it does not list repo-managed files like `todo.ts`, `simple-multi-status.ts`, or `pi-plan-mode`. See [Package-managed Pi extensions](#package-managed-pi-extensions) below for the exact git and npm package set.

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
│   ├── developer.md
│   ├── quality-reviewer.md
│   └── ...
└── extensions/
    ├── pi-plan-mode/
    │   └── index.ts
    ├── simple-multi-status.ts
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
- `review:change.md` → `/review:change`

Prompt templates in this repo are kept as top-level files in `_pi/prompts/`, so no extra nested prompt-directory discovery is required.

The `/plan` command is provided by the `pi-plan-mode` extension, not by a prompt template.

## Extensions

Pi loads runtime extensions from `~/.pi/agent/extensions/`.

This repo now ships a maintained `pi-plan-mode` extension that:

- powers `/plan` mode for `thoughts/` planning workflows,
- keeps planning-mode file writes scoped to `thoughts/`,
- offers `/review:plan` after plan edits,
- offers both `/dev:run <plan>` and `/ralph:run <plan>` as post-review exit paths,
- stages those exit choices through `/cmd:execute-plan <plan> --target ...` so Pi can launch execution from a fresh session,
- disables `/plan` mode before dispatching into execution so implementation is not blocked by planning-only restrictions.

This repo also ships `simple-multi-status.ts`, a lightweight multi-line status widget that auto-loads on install and shows:

- the active model,
- token, cache, and cost totals,
- multi-pass / multicodex status when present,
- current context-window usage,
- the current working directory.

This repo also vendors Pi's `todo.ts` example extension, which auto-loads on install and provides:

- a `todo` tool for branch-aware todo tracking,
- a `/todos` command for inspecting the current branch todo list,
- session-detail persistence so todo state follows Pi branching correctly.

## Subagents

Pi subagents load agent definitions from `~/.pi/agent/agents/`.

## Package-managed Pi extensions

In addition to the repo-managed files under `~/.pi/agent/extensions/`, `install.sh --pi` also registers Pi packages via `pi install` / `pi update`. These are the entries that appear in `pi list`.

Git-managed packages:
- `pi-dcp`
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

- `developer`
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
/review:plan thoughts/plans/my-plan.md
/review:plan-adversarial thoughts/plans/my-plan.md
/review:change thoughts/plans/my-plan.md
/review:change-kimi thoughts/plans/my-plan.md
/review:change-opus thoughts/plans/my-plan.md
/review:change-claude-code thoughts/plans/my-plan.md
/cmd:execute-plan thoughts/plans/my-plan.md
/cmd:send-plan-to-doct thoughts/plans/my-plan.md
```

## Reviewed-plan handoff

Use `/cmd:execute-plan <plan>` after a reviewed plan is ready to continue.

Optional second pass: run `/review:plan-adversarial <plan>` after `/review:plan <plan>` when you want an explicit challenge review before execution.

- It is the canonical wrapper for choosing between `/dev:run <plan>` and `/ralph:run <plan>`.
- In Pi `/plan` mode, the extension offers both execution paths as post-review exit choices and stages this handoff command for the selected target.
- When that extension path is used, `/plan` mode is disabled before execution so planning-only tool restrictions do not leak into implementation.
- In Pi, the handoff command starts a fresh session and then launches the selected execution flow from that clean context.

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
