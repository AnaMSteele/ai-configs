---
name: avalandra-bug-autobuild
description: Capture, triage, draft, create, and optionally hand off Avalandra, ava, or ccore2 bugs to the Nodaste Linear autobuild flow. Use whenever Ana says "we found a bug," "file this Avalandra bug," "open a Linear bug," "send this bug to autobuild," or describes an Avalandra/ava/ccore2 defect that should be tracked. Branch between a lightweight self-contained bug brief, capture-only Linear issue, and the full reviewed-plan workflow; never require a full plan merely because the root cause is unknown.
---

# Avalandra Lightweight Bug to Linear Autobuild Runbook

Turn a reported Avalandra, ava, or ccore2 defect into a truthful Linear record and, when ready, a safe autobuild handoff. This skill owns capture and handoff; it does not implement the fix.

## Invocation

Treat these as equivalent entry points:

- `we found a bug`
- `file this Avalandra bug`
- `open a Linear bug for this`
- `send this bug to autobuild`
- `/skill:avalandra-bug-autobuild`

If the user is only asking whether an issue exists or requesting status, inspect and report without creating or updating anything.

## Authority and tools

1. Follow the current user instruction first, then repository-local `AGENTS.md`/`CLAUDE.md` and safety guidance.
2. Start with `ava health` and `ava auth status --json`, then retrieve the smallest relevant guidance from Ana's canonical Avalandra Agent Ops space (`spc_ee8732550dd8455e9c16de1bec636975`). Prefer:
   - `Avalandra Lightweight Bug to Linear Autobuild Runbook` (document `e323c627-9269-4baf-8013-e18be9a53c7f`)
   - `Linear Issue Creation Preflight for Autobuild`
   - `HTML Plan to Linear Autobuild Handoff Runbook` when the full-plan branch applies
   - `Linear LTUI and Support Bundle Upload Protocol` for support bundles
3. Use `/Users/anasteele/.local/bin/ltui` for every normal Linear read and write. Do not use Linear.app, a browser, a generic connector, or an ad hoc API call unless Ana explicitly overrides the LTUI-only rule.
4. Resolve live workflow state, project, labels, and assignee before mutation. The current Avalandra defaults are:
   - team: `NOD`
   - project: `Avalandra / ava / ccore2` (`15e09906-70ec-494d-8320-a9e259a8fc49`)
   - capture state: `Backlog`
   - pre-handoff state: `Staging to Pull`
   - trigger state: `Ready to Pull`
   - trigger label: `autobuild`
   - autobuild assignee: Aaron Nichols (`aaron@nodaste.com`)
5. Do not invent or create a generic `Bug` label. The `NOD` team currently has no such label; use only labels confirmed by a live lookup or explicitly requested by Ana.
6. Search live Avalandra Agent Ops knowledge when the report depends on shared product guidance. Search Linear for likely duplicates before creating a new issue.

## Workflow at a glance

1. Capture the observed facts and evidence.
2. Search for a duplicate or already-fixed issue.
3. Classify readiness using the three branches below.
4. Show Ana the readiness result and proposed Linear body.
5. Create a capture-only issue after approval when tracking should begin before handoff.
6. Attach and verify evidence while the issue remains non-triggering.
7. Apply autobuild triggers last only after the lightweight brief or full plan is ready and Ana has confirmed the handoff.
8. Read the issue back and report the exact result.

## Capture facts without inventing them

Collect what is available from the report, local diagnostics, screenshots, logs, and relevant repository state:

- affected Avalandra/ava/ccore2 surface
- concise observed failure
- expected behavior
- actual behavior
- environment, build/version, account/space, and timing when material
- reproduction steps or a reliable failure signal
- user impact and frequency
- regression status or last-known-good version when known
- screenshots, logs, support bundle, or related issue links
- a test oracle: what observable result proves the bug is fixed

Keep observed facts separate from hypotheses. A suspected cause can be useful, but it is not a requirement for direct autobuild and must not be presented as proven.

Do not block issue capture merely because the implementation location or root cause is unknown. Discovery of code paths and the eventual fix belongs to the build agent.

## Search for an existing issue

Use concrete symptom, error, and surface terms with narrow LTUI searches. Inspect likely matches before deciding.

If a likely duplicate exists, show Ana the match and recommend updating it instead of silently creating another issue. Do not attach evidence to an issue Ana did not name or approve when the match is ambiguous.

## Readiness branches

### Branch A — Ready for direct autobuild

Use a lightweight bug brief instead of a full reviewed plan when all of these are true:

- the actual failure and expected behavior are unambiguous;
- reproduction evidence or a reliable observable failure signal exists;
- the desired outcome is bounded to one coherent defect;
- acceptance criteria and a verification oracle can be written without inventing product behavior;
- no unresolved product, design, security, privacy, data-loss, migration, architecture, or public-contract decision could materially change the fix;
- repository-local guidance does not require a full plan for this class of change.

Unknown root cause, unknown file paths, or the need for normal code investigation do not force the full-plan branch.

### Branch B — Captured, not triggered

Use this branch when there is enough truthful information to track the bug but not enough to start autonomous work safely. Examples include:

- expected behavior is not yet confirmed;
- the only report is intermittent and has no preserved failure signal;
- the affected environment or version materially changes the diagnosis;
- the fix boundary or acceptance oracle is unclear;
- a likely duplicate needs Ana's decision.

After Ana approves the draft, create or retain the issue in `Backlog` under the Avalandra project. Do not assign Aaron, move it to `Ready to Pull`, or apply `autobuild`. Add the blocker summary described below and continue gathering the smallest missing fact.

### Branch C — Full reviewed plan required

Route to the canonical reviewed-plan/autobuild workflow when the bug requires product or architecture decisions, spans multiple independently changeable surfaces, changes a public protocol or data model, involves destructive migration/recovery behavior, changes security/privacy/authentication boundaries, or repository-local guidance mandates a plan.

The Linear issue may still be opened early in `Backlog` after Ana approves the truthful capture body. Keep automation off until the full reviewed plan has passed its handoff gate.

Do not use code-size guesses or implementation uncertainty alone to force this branch.

## Mandatory user-visible readiness result

Before issue creation and again before applying triggers, report exactly one status:

### `Ready for direct autobuild`

Include:

- why a separate reviewed plan is unnecessary;
- the proposed title and full issue body;
- evidence that will be attached;
- intended team, project, state, assignee, and labels;
- an explicit request for Ana to confirm or edit the handoff.

### `Captured, not triggered`

Include:

- `Autobuild: OFF`;
- each missing fact or decision;
- why each gap prevents safe autonomous execution;
- the smallest concrete question or diagnostic that can clear the gap;
- whether a Linear issue exists and its exact non-trigger state;
- confirmation that `Ready to Pull` and `autobuild` were not applied.

### `Full plan required`

Include:

- `Autobuild: OFF`;
- the specific decision/risk boundary that requires planning;
- the existing or proposed Linear issue and its non-trigger state;
- the canonical reviewed-plan workflow that will be used next.

Never say only "not enough information." Make the blocker actionable.

If an issue already exists, add the same concise blocker summary as a Linear comment beginning with `[autobuild-blocked]`. When the blockers are cleared, add a follow-up comment beginning with `[autobuild-unblocked]`; do not rewrite history by deleting the earlier comment.

## Lightweight Linear bug brief

Use this structure for Branch A and as much of it as is truthful for Branch B:

```markdown
## Summary

## User impact

## Expected behavior

## Actual behavior

## Reproduction and evidence

## Scope guardrails

## Acceptance criteria

## Verification

## Autobuild readiness
This is a bounded bug fix. No separate reviewed implementation plan is required because ...
```

Write acceptance criteria as observable outcomes. Include regression coverage appropriate to the affected boundary. Mark genuinely unknown capture-only fields as unknown or pending; never fill them with speculation.

## Confirmation and creation gate

Show Ana the complete draft before creating an issue that is intended for autobuild or contains inferred behavior/scope. Ask for confirmation or edits before `ltui issues create`.

If Ana explicitly says to create immediately, keep the body concise and factual. Do not add speculative requirements. An instruction to create immediately does not waive the readiness gate for applying automation triggers.

For a capture-only issue:

1. Create it in `Backlog` under `NOD` and `Avalandra / ava / ccore2`.
2. Do not apply a generic `Bug` label; none currently exists for `NOD`.
3. Leave it unassigned unless Ana specifies an owner; do not assign Aaron merely to park an incomplete issue.
4. Verify state, project, assignee, and labels before reporting it captured.

## Evidence handling

Preserve the original evidence whenever possible:

- upload screenshots with descriptive titles and alt text;
- add external evidence as Linear links;
- use comments for compact logs and provenance;
- follow the Agent Ops support-bundle protocol for ZIP files;
- inspect attachments before handing them to downstream automation;
- avoid copying secrets, tokens, private session URLs, or unrelated data into Linear.

Verify the description, comments, and attachments while the issue is still in its non-trigger state.

## Direct-autobuild handoff

For Branch A, after Ana confirms the lightweight brief:

1. Create or update the issue in `Backlog` with the complete self-contained description under `Avalandra / ava / ccore2`.
2. Attach and verify all required evidence.
3. Add a discovery comment beginning with `[autobuild-plan] Lightweight bug brief — no separate reviewed plan required.` State that the description is the self-contained execution input and identify the verification oracle.
4. Move the issue to `Staging to Pull` and read it back to confirm that the description is complete, evidence is present, and it is still non-triggering.
5. Resolve the exact live assignee, trigger state, and trigger label.
6. Apply triggers last, in this order:
   - assign Aaron Nichols (`aaron@nodaste.com`);
   - move to `Ready to Pull`;
   - add `autobuild`.
7. Read the issue back again and verify the final state, assignee, labels, project, description, comments, and attachments.

If any mutation fails midway, inspect the live issue and resume from the first unfulfilled step. Do not blindly rerun the entire sequence.

## Recovery

- If automation was triggered before readiness or confirmation, immediately remove `autobuild` and return the issue to its previous non-trigger state, then report the correction.
- If new evidence reveals a product/architecture blocker after handoff, remove `autobuild`, return the issue to `Backlog` unless it remains a verified handoff candidate, add `[autobuild-blocked]`, and route to the full-plan branch.
- If an upload fails, leave the issue non-triggering and say exactly which evidence is missing.
- If authentication fails, stop mutations and ask Ana to sign in through the supported interface. Do not bypass authentication with direct database access.

## Completion report

Report:

- readiness status;
- issue key and URL, if created or reused;
- exact state, assignee, project, and labels;
- whether the description was verified complete;
- evidence/attachment count and any missing evidence;
- whether a lightweight brief or full reviewed plan governs the work;
- whether autobuild is ON or OFF;
- blockers and the next smallest action, when not ready;
- confirmation that no unrelated Linear fields or repository files changed.
