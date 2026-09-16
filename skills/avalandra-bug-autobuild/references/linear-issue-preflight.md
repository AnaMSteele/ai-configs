# Linear Issue Creation Preflight for Autobuild

Use this guidance whenever Ana asks an agent to create a Linear issue, especially for Avalandra, ava, or ccore2, or when the issue will use automation-triggering state or labels such as `Ready to Pull` or `autobuild`.

Rule: draft and finalize the Linear issue body before creating the issue or applying automation triggers.

Required behavior:

1. Resolve the live Linear team, project, state, labels, and assignee with LTUI. For Avalandra/ava/ccore2, the current project is `Avalandra / ava / ccore2` (`15e09906-70ec-494d-8320-a9e259a8fc49`).
2. Draft the full issue content first: title, user story, product context, implementation notes, acceptance criteria, labels, assignee, project, and intended state.
3. Show Ana the issue body before creation when the issue will receive `autobuild`, will be placed in `Ready to Pull`, or contains inferred product or implementation requirements.
4. Ask Ana to confirm or edit the body before running `ltui issues create`.
5. Only after confirmation, create the issue using LTUI and apply automation-triggering labels and state.
6. If Ana explicitly says to create immediately, keep the body concise and final; do not include speculative requirements that would send an autonomous builder in the wrong direction.

Current Avalandra convention: capture-only defects begin in `Backlog`, unassigned, with no invented generic `Bug` label. `autobuild` is applied last, after assignment to Aaron and movement to `Ready to Pull`.

Why: Linear automation may immediately change state and start autobuild work. The issue description must be final enough for an autonomous build before those triggers are applied.

Related runbooks in Ana Agent Ops:

- `Avalandra Lightweight Bug to Linear Autobuild Runbook`
- `Linear LTUI and Support Bundle Upload Protocol`
