# Pi Configuration

This directory contains Pi-specific resources:

- `prompts/` — prompt templates exposed as slash commands
- `skills/` — Agent Skills invoked via `/skill:name`
- `agents/` — pi-subagents-compatible agent definitions
- `extensions/` — Pi runtime extensions, including the maintained `/plan` mode workflow

The prompt templates are copied from `_omp/commands`, and the agent definitions are ported from `_omp/agents` into the flat markdown format expected by pi-subagents.

## Installation

These resources are installed by `install.sh` to Pi's global agent directory. The installer also registers selected package-managed Pi extensions with Pi itself: git packages such as `pi-dcp`, `chrome-cdp-skill`, and `pi-rlm`, plus npm packages such as `pi-multi-pass` and `pi-subagents`.

```bash
./install.sh --pi      # Install Pi prompt templates + skills + subagents + extensions
./install.sh --all     # Install everything, including Pi
```

Installed layout:

```text
~/.pi/agent/
├── README.md
├── prompts/
│   ├── cmd:debug.md
│   ├── dev:plan.md
│   └── ...
├── skills/
│   ├── ralph-run/
│   └── ...
├── agents/
│   ├── developer.md
│   ├── quality-reviewer.md
│   └── ...
└── extensions/
    └── pi-plan-mode/
        └── index.ts
```

## Structure

```text
_pi/
├── README.md
├── prompts/            # Pi prompt templates / slash commands
│   └── *.md
├── skills/             # Pi skills (Agent Skills format)
│   └── */SKILL.md
├── agents/             # Pi subagent definitions for pi-subagents
│   └── *.md
└── extensions/         # Pi runtime extensions
    └── */index.ts
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

## Subagents

Pi subagents load agent definitions from `~/.pi/agent/agents/`.

These files are based on `_omp/agents`, but normalized for the pi-subagents loader:

- every agent has a `name`
- `tools` is flattened to a comma-separated built-in Pi tool list when possible
- unsupported OMP-only nested permission/tool metadata is omitted from the frontmatter used by pi-subagents

Example installed agents:

- `developer`
- `quality-reviewer`
- `research`
- `plan-gpt5.4`
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

### Context / review
- `cmd-create-handoff`
- `cmd-resume-handoff`
- `review-change`
- `review-change-integrate`

## Usage

Prompt templates:

```text
/cmd:debug login flake in CI
/dev:plan feature-name
/review:change thoughts/plans/my-plan.md
/cmd:execute-plan thoughts/plans/my-plan.md
/cmd:send-plan-to-doct thoughts/plans/my-plan.md
```

## Reviewed-plan handoff

Use `/cmd:execute-plan <plan>` after a reviewed plan is ready to continue.

- It is the canonical wrapper for choosing between `/dev:run <plan>` and `/ralph:run <plan>`.
- In Pi `/plan` mode, the extension offers both execution paths as post-review exit choices and stages this handoff command for the selected target.
- When that extension path is used, `/plan` mode is disabled before execution so planning-only tool restrictions do not leak into implementation.
- In Pi, the handoff command starts a fresh session and then launches the selected execution flow from that clean context.

Skills:

```text
/skill:ralph-run user-profile-redesign
/skill:cmd-start-linear-issue-branch ENG-123
/skill:doct-document-ops
```

## Notes

- Pi global resources live under `~/.pi/agent/`, not `~/.pi/`.
- Project-local Pi resources can also live under `.pi/prompts/`, `.pi/skills/`, `.pi/agents/`, and `.pi/extensions/`.
- Pi auto-discovers `~/.pi/agent/skills/`, `~/.pi/agent/prompts/`, and `~/.pi/agent/extensions/`.
- pi-subagents-compatible agent definitions install to `~/.pi/agent/agents/`.
