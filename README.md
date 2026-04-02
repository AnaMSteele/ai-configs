# AI Configs

Shared configuration repo for:

- Claude Code
- Codex
- Gemini CLI
- Oh My Pi (`_omp`)
- Pi (`_pi`)
- OpenCode

It packages prompt/command surfaces, agent definitions, shared skills, helper scripts, and install tooling in one place.

## Repository layout

```text
ai-configs/
├── _claude/      # Claude source config
├── _codex/       # Codex source config
├── _gemini/      # Gemini source config
├── _omp/         # OMP source config
├── _opencode/    # OpenCode source config
├── _pi/          # Pi source config
├── scripts/      # Shared helper scripts fanned out by install.sh
├── skills/       # Canonical shared installable skills
├── tools/        # Distributable CLIs (for example ltui)
├── docs/         # Fetched/reference docs kept in repo
├── thoughts/     # Working plans, handoffs, research, validation
└── install.sh    # Main installer / updater
```

Convention:
- `_<tool>/` directories are the committed source-of-truth trees.
- `.<tool>/` directories are treated as local runtime/install artifacts and are gitignored.
- Shared helper scripts live once in `scripts/` and are copied to installed runtime locations by `install.sh`.

## Install

Project install:

```bash
git clone <repository-url> ~/ai-configs
cd ~/ai-configs
pip3 install -r requirements.txt

cd /path/to/your/project
bash ~/ai-configs/install.sh --all
```

Single-surface installs:

```bash
bash ~/ai-configs/install.sh --claude
bash ~/ai-configs/install.sh --codex
bash ~/ai-configs/install.sh --gemini
bash ~/ai-configs/install.sh --omp
bash ~/ai-configs/install.sh --pi
bash ~/ai-configs/install.sh --opencode
bash ~/ai-configs/install.sh --skills
bash ~/ai-configs/install.sh --tools
```

Global install:

```bash
bash ~/ai-configs/install.sh --all ~
```

## What the installer does

- installs Claude config into `.claude/`
- installs Gemini config into `.gemini/`
- installs project Codex config into `.codex/`
- mirrors Codex prompts into `~/.codex/prompts`
- mirrors shared helper scripts into the runtime locations that need them
- installs OMP to `~/.omp/agent/`
- installs Pi to `~/.pi/agent/`
- installs OpenCode resources to `~/.config/opencode/`
- syncs canonical shared skills into `~/.agents/skills`
- copies `APPEND_SYSTEM.md` into Pi and OMP runtime locations
- preserves local settings files where appropriate

To update an existing install, run the same `install.sh` command again.

## Key directories

### `_claude/`
Claude-specific agents, commands, and default settings.

### `_codex/`
Codex prompt files plus config templates. Global Codex prompt discovery is handled by the installer.

### `_gemini/`
Gemini TOML command definitions plus the `GEMINI.template.md` persona template.

### `_omp/`
Native OMP commands and agents.

### `_pi/`
Pi prompts, subagents, extensions, and package-backed Pi helpers.

### `_opencode/`
OpenCode commands, agents, prompts, repo-local-only skills, onboarding docs, and helper scripts.

### `scripts/`
Canonical shared helper scripts used across multiple runtimes.

Current shared scripts include:
- `docs-fetch.py`
- `docs-fetch-batch.py`
- `markdown-converter.py`
- review helpers

### `skills/`
Canonical shared skill tree. This is the only primary shared-skill source in the repo.

### `tools/ltui/`
Token-efficient Linear CLI for AI agents.

## Skills and tools

Shared skills install to:

```text
~/.agents/skills/
```

Consumer-specific compatibility links are created where needed, but `~/.agents/skills` is the canonical shared runtime location.

`ltui` lives under `tools/ltui/` and can be installed with:

```bash
bash ./install.sh --tools
```

## Working docs

The repo keeps long-lived and working documentation separate:

- `spec/` — permanent architecture and ADR-style material
- `thoughts/` — plans, research, handoffs, validation, retro notes
- `docs/` — fetched framework/library docs

## Notes

- This repo intentionally no longer tracks accumulated local runtime trees like `.claude/`, `.gemini/`, `.codex/`, `.opencode/`, `.agent/`, or `.agents/`.
- If older notes or scripts reference pre-cleanup paths such as `claude/...`, `codex/...`, `gemini/...`, or `opencode/...`, use the underscored source paths instead.
- Installed runtime paths remain the normal dot-directories used by each tool.

## More specific docs

- `_pi/README.md`
- `_opencode/OPENCODE_ONBOARDING.md`
- `_opencode/QUICKSTART.md`
- `AGENTS.md`
- `CLAUDE.md`
