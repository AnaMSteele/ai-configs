# Avalandra Lightweight Bug to Linear Autobuild Runbook

## Purpose

Use this runbook when Ana says “we found a bug” or asks an agent to capture an Avalandra, ava, or ccore2 defect in Linear and potentially send it to autobuild without first producing a full reviewed implementation plan.

The central rule is: opening Linear and triggering autobuild are separate decisions. A truthful bug can be captured early in `Backlog`; automation starts only when the description and evidence form a self-contained execution brief.

## Canonical branches

### Ready for direct autobuild

Use the lightweight flow when actual versus expected behavior is clear, evidence or a reliable failure oracle exists, the desired outcome is bounded, observable acceptance criteria can be written, and no unresolved product, design, security, privacy, migration, data-loss, architecture, or public-contract decision could materially change the fix.

Unknown root cause, file paths, or implementation details do not require a full plan. Those are normal build-agent discovery.

### Captured, not triggered

Create or retain the issue in `Backlog` when it is a real bug worth tracking but a missing fact prevents safe autonomous work. Keep the issue unassigned and keep `Ready to Pull` and `autobuild` off. Tell Ana exactly what is missing, why it matters, and the smallest question or diagnostic that will clear it. If the issue exists, add an `[autobuild-blocked]` comment.

### Full reviewed plan required

Use the canonical HTML-plan/autobuild handoff when the work depends on unresolved product or architecture choices, crosses independently changeable surfaces, changes public protocols or stored data, affects destructive recovery/migration behavior, changes security/privacy/authentication boundaries, or repository-local guidance requires a plan.

The issue may be captured early in `Backlog`, but remains non-triggering until the plan handoff is verified.

## User-visible readiness contract

Before creation and before triggers, report one of:

- `Ready for direct autobuild`
- `Captured, not triggered` with `Autobuild: OFF`
- `Full plan required` with `Autobuild: OFF`

A blocked result must enumerate missing facts or decisions, explain why each prevents autonomous execution, ask the smallest clearing question, and state whether Linear exists and which trigger fields are absent. Never report only “not enough information.”

## Linear contract

- Use `/Users/anasteele/.local/bin/ltui` exclusively unless Ana explicitly overrides it.
- Search for likely duplicates before creation.
- Show Ana the complete draft before creating an issue intended for autobuild or containing inferred scope.
- Resolve all mutable Linear fields live before mutation. The current Avalandra defaults are:
  - team `NOD`
  - project `Avalandra / ava / ccore2`
  - project ID `15e09906-70ec-494d-8320-a9e259a8fc49`
  - project URL `https://linear.app/nodaste/project/avalandra-ava-ccore2-189445c46e65`
  - capture state `Backlog`
  - pre-handoff state `Staging to Pull`
  - trigger state `Ready to Pull`
  - trigger label `autobuild`
  - autobuild assignee Aaron Nichols (`aaron@nodaste.com`)
- The `NOD` team currently has no generic `Bug` label. Do not invent, create, or apply one unless Ana explicitly asks and a live lookup confirms it exists.
- For capture-only issues, do not assign Aaron merely to park incomplete work.
- Preserve original evidence, use descriptive image titles/alt text, and follow the Agent Ops support-bundle protocol for ZIPs.

## Lightweight description

The self-contained issue body should include:

- summary and user impact
- expected and actual behavior
- reproduction and original evidence
- scope guardrails
- observable acceptance criteria
- verification/test oracle
- an autobuild-readiness statement explaining why no separate reviewed plan is needed

Use facts, not invented requirements. A suspected cause must be labeled as a hypothesis.

## Capture sequence

For an approved capture-only issue:

1. Create it in `Backlog` under `NOD` and `Avalandra / ava / ccore2`.
2. Leave it unassigned unless Ana specifies an owner.
3. Do not apply `autobuild` or move it to `Ready to Pull`.
4. Read it back and verify project, state, assignee, labels, and description.

## Trigger sequence

After Ana confirms the brief and all evidence has been attached and verified while non-triggering:

1. Add `[autobuild-plan] Lightweight bug brief — no separate reviewed plan required.` and point to the description as the execution input.
2. Move the verified issue to `Staging to Pull` and read it back while it is still non-triggering.
3. Assign Aaron.
4. Move to `Ready to Pull`.
5. Add `autobuild` last.
6. Verify the full issue state, project, assignee, labels, description, comments, and attachments.

If a blocker appears later, remove the trigger, return the issue to its appropriate non-trigger state (normally `Backlog`), append `[autobuild-blocked]`, and route to the full-plan branch when appropriate.

## Related canonical guidance

- `Linear Issue Creation Preflight for Autobuild`
- `HTML Plan to Linear Autobuild Handoff Runbook`
- canonical package `html-plan-linear-autobuild-handoff`
- `Linear LTUI and Support Bundle Upload Protocol`
