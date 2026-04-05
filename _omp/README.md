# OMP surfaces

This tree contains the repo-managed OMP runtime surfaces installed by `install.sh --omp`:

- `commands/` → prompt-backed OMP commands installed to `~/.omp/agent/commands/`
- `agents/` → OMP agent definitions installed to `~/.omp/agent/agents/`
- `extensions/` → repo-managed OMP extensions installed to `~/.omp/agent/extensions/`

## Planning entrypoint

Use `/aplan` for the repo-managed OMP planning workflow in this repository.

- `/aplan` is provided by `_omp/extensions/aplan/index.ts`
- interactive `/aplan` enters built-in `/plan` mode and queues the repo-managed planning workflow guidance for the next planning turn
- built-in `/plan` remains untouched; `/aplan` is the repo-managed entrypoint layered on top of it
- while `/aplan` is active, plan updates in `thoughts/plans/` can trigger `/review:plan`; if standard review leaves inline `[REVIEW:...]` comments, `/review:change-integrate` is auto-run before any exit prompt, and `/review:plan-adversarial` remains an optional follow-up review pass
- after review, `/aplan` offers fresh `/dev:run` and `/ralph:run` exit choices and prepares `/cmd:execute-plan <plan> --target ...` so execution starts outside `/aplan` mode

## Legacy note about `_omp/agents/aplan-legacy.md`

The legacy shim was renamed off the `/aplan` name so the runtime extension owns `/aplan` unambiguously. Keep `_omp/agents/aplan-legacy.md` only for historical guidance that points users back to the runtime `/aplan`; it is not a command entrypoint.
