# OMP surfaces

This tree contains the repo-managed OMP runtime surfaces installed by `install.sh --omp`:

- `commands/` → prompt-backed OMP commands installed to `~/.omp/agent/commands/`
- `agents/` → OMP agent definitions installed to `~/.omp/agent/agents/`
- `extensions/` → repo-managed OMP extensions installed to `~/.omp/agent/extensions/`

## Planning entrypoint

Use `/aplan` for the repo-managed OMP planning workflow in this repository.

- `/aplan` is provided by `_omp/extensions/aplan/index.ts`
- interactive `/aplan` rewrites into built-in `/plan` so it enters native plan mode immediately instead of behaving like a long-running prompt command
- built-in `/plan` remains untouched and continues to coexist
- reviewed-plan execution continues to route through the prompt-backed `/cmd:execute-plan` command
- `/review:plan` and `/review:plan-adversarial` remain the review surfaces referenced by the `/aplan` bootstrap instructions

## Legacy note about `_omp/agents/aplan-legacy.md`

The legacy shim was renamed off the `/aplan` name so the runtime extension owns `/aplan` unambiguously. Keep `_omp/agents/aplan-legacy.md` only for historical guidance; it is not a command entrypoint.
