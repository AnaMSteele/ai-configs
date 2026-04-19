# Codex Configuration

This directory is the repository source for Codex prompts and configuration templates.

## Contents

- `prompts/` — Codex prompt files
- `config.toml` — Codex config template
- `mcp-servers.toml` — MCP server snippets for Codex
- `../scripts/` — shared helper scripts installed into `~/.codex/scripts`

## Install

```bash
bash /path/to/ai-configs/install.sh --codex
bash /path/to/ai-configs/install.sh --codex ~
```

Re-run `install.sh` to refresh an existing installation.

## Notes

- Repo source lives under `_codex/`; installed runtime files live under `.codex/` in target projects and `~/.codex/` for global Codex resources.
- Shared helper scripts are maintained once in the repo-level `scripts/` directory and copied into `~/.codex/scripts` by the installer.
- Prompt files are mirrored to `~/.codex/prompts` because Codex discovers global prompts there.
- If you already have `~/.codex/config.toml`, merge new settings from `_codex/config.toml` instead of overwriting blindly.

## Canonical reviewed-plan workflow

Codex mirrors the core reviewed-plan flow used in Pi:

```text
/dev:plan <plan>
/dev:pm-review <plan> plan        # optional reshaping pass
/review:plan <plan>
/review:change-integrate <plan>
/cmd:execute-plan <plan>
```

Execution handoff targets:

- `/dev:run <plan>`
- `/ralph:run <plan>`
