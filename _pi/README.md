# Pi Configuration

This directory contains Pi-specific resources:

- `prompts/` — prompt templates exposed as slash commands
- `skills/` — Agent Skills invoked via `/skill:name`

The prompt templates are copied from `_omp/commands` so Pi gets the same command library, using Pi's prompt-template system.

## Installation

These resources are installed by `install.sh` to Pi's global agent directory:

```bash
./install.sh --pi      # Install Pi prompt templates + skills only
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
└── skills/
    ├── cmd-commit-push/
    ├── ralph-run/
    └── ...
```

## Structure

```text
_pi/
├── README.md
├── prompts/            # Pi prompt templates / slash commands
│   ├── .arch/
│   └── *.md
└── skills/             # Pi skills (Agent Skills format)
    └── */SKILL.md
```

## Prompt Templates

Pi loads prompt templates from `~/.pi/agent/prompts/`.

Each Markdown file becomes a slash command using the filename:

- `cmd:debug.md` → `/cmd:debug`
- `dev:plan.md` → `/dev:plan`
- `review:change.md` → `/review:change`

The installer also updates `~/.pi/agent/settings.json` so nested prompt directories like `prompts/.arch/` are discovered.

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
- Project-local Pi resources can also live under `.pi/prompts/` and `.pi/skills/`.
- Pi auto-discovers `~/.pi/agent/skills/` and `~/.pi/agent/prompts/`.
