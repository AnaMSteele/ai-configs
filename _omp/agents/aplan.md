---
description: Legacy compatibility shim for the repo-managed OMP planning workflow; prefer the runtime /aplan extension.
mode: primary
permission:
  question: allow
  edit:
    "*": deny
    "thoughts/plans/*.md": allow
    "thoughts/plans/**.md": allow
  write:
    "*": deny
    "thoughts/plans/*.md": allow
    "thoughts/plans/**.md": allow
  pty_write: deny
  pty_read: deny
tools:
  bash: false
  edit: true
  write: true
  list: true
  glob: true
  todowrite: true
  todoread: true
color: "#800080"
---

<system-reminder>
# Legacy `/aplan` shim

This file is retained only so repo-local OMP guidance can point old references to the new runtime planning surface.

Preferred entrypoint: use the runtime `/aplan` command provided by `_omp/extensions/aplan/index.ts`.

Behavior for this shim:
- Do not present this agent file as the primary planning workflow.
- If the user wants repo-managed OMP planning mode, direct them to `/aplan`.
- If you are invoked anyway, stay constrained to `thoughts/plans/` and help with plan authoring only.
- Do not claim to replace or override built-in `/plan`.
- Reviewed-plan execution still goes through `/cmd:execute-plan` after plan review.
</system-reminder>
