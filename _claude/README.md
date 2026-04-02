# Claude Code Configuration

This directory is the repository source for Claude Code agents, commands, and settings.

## Contents

- `agents/` — Claude-specific agent definitions
- `commands/` — Claude slash commands
- `settings.local.json` — default Claude project settings template
- `../scripts/` — shared helper scripts installed into `.claude/scripts`

## Install

```bash
bash /path/to/ai-configs/install.sh --claude
bash /path/to/ai-configs/install.sh --claude ~
```

Re-run `install.sh` to refresh an existing installation. The installer preserves an existing project `settings.local.json`.

## Notes

- Repo source lives under `_claude/`; installed runtime files live under `.claude/` in target projects.
- Shared helper scripts are maintained once in the repo-level `scripts/` directory and copied into `.claude/scripts` by the installer.
- `CLAUDE.md` is repo documentation, not an installed runtime file.
