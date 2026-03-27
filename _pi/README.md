# Pi Configuration

This directory contains Pi-specific resources:

- `prompts/` — prompt templates exposed as slash commands
- `skills/` — Agent Skills invoked via `/skill:name`
- `agents/` — pi-subagents-compatible agent definitions

The prompt templates are copied from `_omp/commands`, and the agent definitions are ported from `_omp/agents` into the flat markdown format expected by pi-subagents.

## Installation

These resources are installed by `install.sh` to Pi's global agent directory:

```bash
./install.sh --pi      # Install Pi prompt templates + skills + subagents
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
│   ├── cmd-commit-push/
│   ├── ralph-run/
│   └── ...
└── agents/
    ├── developer.md
    ├── quality-reviewer.md
    └── ...
```

## Structure

```text
_pi/
├── README.md
├── prompts/            # Pi prompt templates / slash commands
│   └── *.md
├── skills/             # Pi skills (Agent Skills format)
│   └── */SKILL.md
└── agents/             # Pi subagent definitions for pi-subagents
    └── *.md
```

## Prompt Templates

Pi loads prompt templates from `~/.pi/agent/prompts/`.

Each Markdown file becomes a slash command using the filename:

- `cmd:debug.md` → `/cmd:debug`
- `dev:plan.md` → `/dev:plan`
- `review:change.md` → `/review:change`

Prompt templates in this repo are kept as top-level files in `_pi/prompts/`, so no extra nested prompt-directory discovery is required.

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
- `cmd-commit-push`
- `cmd-create-pr`
- `cmd-start-linear-issue`
- `cmd-start-linear-issue-branch`

### Development
- `cmd-research`
- `cmd-debug`
- `dev-plan`
- `cmd-graduate`

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
```

Skills:

```text
/skill:ralph-run user-profile-redesign
/skill:cmd-commit-push "feat: add new feature"
/skill:cmd-start-linear-issue-branch ENG-123
```

## Notes

- Pi global resources live under `~/.pi/agent/`, not `~/.pi/`.
- Project-local Pi resources can also live under `.pi/prompts/`, `.pi/skills/`, and `.pi/agents/`.
- Pi auto-discovers `~/.pi/agent/skills/` and `~/.pi/agent/prompts/`.
- pi-subagents-compatible agent definitions install to `~/.pi/agent/agents/`.
