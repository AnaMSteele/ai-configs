# OMP surfaces

This tree contains the repo-managed OMP runtime surfaces installed by `install.sh --omp`:

- `commands/` → prompt-backed OMP commands installed to `~/.omp/agent/commands/`
- `agents/` → OMP agent definitions installed to `~/.omp/agent/agents/`
- `extensions/` → repo-managed OMP extensions installed to `~/.omp/agent/extensions/`

## Planning entrypoint

Use `/aplan` for the repo-managed OMP planning workflow in this repository.

- `/aplan` is provided by `_omp/extensions/aplan/index.ts`
- built-in `/plan` remains untouched and should continue to coexist
- reviewed-plan execution continues to route through the prompt-backed `/cmd:execute-plan` command
- `/review:plan` and `/review:plan-adversarial` remain the review surfaces used by `/aplan`

## Legacy note about `_omp/agents/aplan.md`

That file is kept only as a compatibility/documentation shim so repo-local guidance can point users to `/aplan`. It is not the preferred planning surface anymore.
