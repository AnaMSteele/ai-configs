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
├── skills/       # Repo-owned shared skills + install matrix for package-backed skills
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
- copies repo-managed OMP extensions into `~/.omp/agent/extensions/`
- installs Pi to `~/.pi/agent/`
- copies repo-managed Pi extensions into `~/.pi/agent/extensions/` (these do not appear in `pi list`)
- registers Pi-managed packages via `pi install` / `pi update`: git (`pi-dcp`, `chrome-cdp-skill`, `pi-rlm`) and npm (`pi-subagents`, `@aliou/pi-processes`, `pi-web-access`, `pi-mcp-adapter`, `lsp-pi`, `@fnnm/pi-ast-grep`, `pi-updater`, `pi-interactive-shell`, `pi-powerline-footer`, `pi-side-agents`, `pi-multi-pass`, `pi-no-soft-cursor`, `@tmustier/pi-files-widget`, `@tmustier/pi-raw-paste`)
- installs OpenCode resources to `~/.config/opencode/`
- syncs shared skills into `~/.agents/skills` from `skills/install-matrix.json`
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
OMP commands, agents, repo-managed extensions, and OMP-local docs. The repo-managed planning entrypoint is the `/aplan` extension, which is installed under `~/.omp/agent/extensions/` and coexists with built-in `/plan`.

### `_pi/`
Pi prompts, subagents, repo-managed extensions copied into `~/.pi/agent/extensions/`, and Pi package baseline documentation for the separate `pi list`-visible package set.

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
Repo-owned shared skill tree plus `skills/install-matrix.json`, which also inventories package-backed shared skills fetched via `npx skills` during install.

### `tools/ltui/`
Token-efficient Linear CLI for AI agents.

## Skills and tools

Shared skills install to:

```text
~/.agents/skills/
```

Consumer-specific compatibility links are created where needed, but `~/.agents/skills` is the canonical shared runtime location. Repo-owned payloads come from `skills/`; package-backed payloads are fetched per `skills/install-matrix.json`.

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

For a host-level verification of both Pi installation surfaces, run:

```bash
bash ./scripts/verify-pi-install.sh
```

## More specific docs

- `_pi/README.md`
- `_opencode/OPENCODE_ONBOARDING.md`
- `_opencode/QUICKSTART.md`
- `AGENTS.md`
- `CLAUDE.md`
