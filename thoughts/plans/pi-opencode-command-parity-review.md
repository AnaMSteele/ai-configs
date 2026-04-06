# Pi → OpenCode command parity review

## Status

research-ready

## Goal

Evaluate which command updates present under `_pi/prompts/` should be adopted under `_opencode/commands/` to match current best practice without regressing the stronger OpenCode-specific command contracts that already exist.

## Non-goals

- Blindly copying every Pi prompt into OpenCode.
- Porting Pi-only runtime assumptions such as `interactive_shell`, Pi plan-mode handoff behavior, or Pi-specific subagent names without checking OpenCode support.
- Replacing OpenCode commands that are already stricter or more complete than the Pi versions.
- Adding duplicate entrypoints that expose the same behavior under multiple names unless a phase explicitly decides that naming parity is worth the maintenance cost.

## Current State (Validated)

- `_pi/prompts/` contains several command surfaces that do not exist in `_opencode/commands/`: `review:plan.md`, `review:plan-adversarial.md`, `review:prd.md`, `dev:plan-from-prd.md`, `prd:clarify-round.md`, `dev:run-high.md`, `ralph:run-high.md`, `dev:run-direct.md`, `review:change-claude-code.md`, `review:change-codex-cli.md`, `review:change-kimi.md`, and `dev:parallel-team.md`.
- `_opencode/commands/` contains OpenCode-only surfaces that are not in Pi, notably `cmd:workplanner.md`, `cmd:commit-push.md`, and the dynamic wrappers `cmd:wrap-gpt5.4.md`, `cmd:wrap-k2.5.md`, and `cmd:wrap-opus.md`.
- Several shared OpenCode commands are already more current than the Pi copies:
  - `_opencode/commands/dev:plan.md` has readiness-state gating, explicit planning-only restrictions, shared planning-workflow guidance, dependency-evaluation requirements, stronger phase structure, and stricter no-execution boundaries that the Pi `dev:plan.md` does not yet include.
  - `_opencode/commands/review:change.md` and `_opencode/commands/review:change-integrate.md` already require `### Tests first`, product-intent alignment, dependency-evaluation checks, and removal of unresolved decision sections; the Pi copies are less strict.
  - `_opencode/commands/ralph:run.md` is more advanced than the Pi version because it adds the discovery ledger, phase-level reassessment rules, explicit verdict protocol, and stronger repeat-review memory.
  - `_opencode/commands/cmd:execute-plan.md` already contains the OpenCode-specific guardrail `Do not promise Pi-specific context reset behavior on this surface`, which should be preserved.
- `_opencode/agents/` already has reusable reviewers and execution agents for some parity work (`reviewer-gpt5.4.md`, `reviewer-kimi.md`, `quality-reviewer.md`, `developer.md`), but it does **not** currently have Pi-only support agents such as `developer-high`, `reviewer-plan-*`, `reviewer-plan-synthesis`, `prd-critical-thinker`, `prd-researcher`, or the seven `reviewer-prd-*` agents.

## Dependency Inventory

This repository currently lacks the following Pi-style support pieces that matter to parity decisions:

- Execution-capability gap: `developer-high.md` is missing, so `dev:run-high` and `ralph:run-high` are not drop-in ports.
- Plan-review gap: `reviewer-plan-synthesis.md` is missing, so any adversarial plan-review surface would need an OpenCode-native redesign.
- PRD workflow gap: `prd-critical-thinker.md`, `prd-researcher.md`, and the `reviewer-prd-*` family are missing, along with the associated review-artifact contract.
- Naming-parity gap: `review:plan.md` is missing, but OpenCode already has `review:change-gpt5.4.md` and `review:change-k2.5.md` as the actual review surfaces.
- Capability-variant gap: `ralph:run-mm.md` already exists, so any new routing decision must account for the existing MiniMax variant instead of ignoring it.

## Evaluation Summary

### Update or add in `_opencode` now

1. **Add `review:plan.md` as a wrapper entrypoint**
   - Why: Pi now has a standard, explicit plan-review entrypoint. OpenCode currently has only the generic `review:change*` family, so reviewed-plan flow is less discoverable.
   - Port shape: do **not** copy the Pi file literally. Create an OpenCode-native wrapper that normalizes the reviewed plan argument and routes users toward the existing `review:change-gpt5.4` or `review:change-k2.5` surfaces. Do **not** create a new review implementation or introduce Pi-only agent names.
   - Behavioral contract: when a user runs `/review:plan <plan-path>`, the command should make it clear that one of the existing OpenCode review commands will handle the plan, using the same normalized plan argument. It must not attempt standalone review logic or mention Pi-only reviewer infrastructure.
   - Constraint: avoid Pi-only wording about Pi subagent tool surfaces.

2. **Optionally add `review:change-kimi.md` as a compatibility alias**
   - Why: Pi exposes `review:change-kimi`; OpenCode currently exposes `review:change-k2.5.md` but already points at `agent: reviewer-kimi`.
   - Recommendation: treat this as a naming convenience only if the name mismatch is actively causing user confusion, repeated correction, or support overhead. Otherwise, keep the canonical `review:change-k2.5.md` surface.
   - Threshold test: do not add the alias unless there is concrete evidence that the alternate name reduces friction more than it increases maintenance burden.

### Add later only with supporting infrastructure

3. **Add a plan-capability split only if OpenCode wants Pi-style execution routing**
   - Candidate commands: `dev:run-direct.md`, `dev:run-high.md`, `ralph:run-high.md`.
   - Why: Pi distinguishes direct execution, default delegated execution, and high-capability execution. OpenCode currently has the direct `/dev:run`, one quality-gated `/ralph:run`, and already has a MiniMax variant `/ralph:run-mm.md`.
   - Blocker: `_opencode/agents/` does not currently contain `developer-high.md`, so `dev:run-high` and `ralph:run-high` are not drop-in ports.
   - Recommendation: only pursue this if OpenCode wants a unified capability-selection surface. If so, first survey existing capability variants (`ralph:run-mm`), then decide whether to consolidate under a single entrypoint with model flags or keep separate explicit commands.

4. **Port the PRD workflow only as one cohesive package**
   - Candidate commands: `prd:clarify-round.md`, `review:prd.md`, `dev:plan-from-prd.md`.
   - Why: Pi now has a coherent PRD clarification → review → plan handoff pipeline.
   - Blocker: OpenCode does not currently have the required PRD agents or review artifact contract (`prd-critical-thinker`, `prd-researcher`, `reviewer-prd-intent`, `reviewer-prd-bdd-flows`, `reviewer-prd-dependencies`, `reviewer-prd-no-stubs`, `reviewer-prd-product-principles`, `reviewer-prd-scope-stage-fit`, `reviewer-prd-security-privacy-reliability`, `review-status.json`, and the integration ledger flow).
   - Recommendation: if OpenCode wants PRD parity, port the commands **and** the missing agents/status-artifact contract together. Do not cherry-pick only one command.

5. **Consider `review:plan-adversarial.md` only after `review:plan.md` exists**
   - Why: the Pi command is useful as an explicit second-pass challenge review.
   - Blocker: the Pi version depends on a synthesis step (`reviewer-plan-synthesis`), external-review transport behavior, and multi-agent coordination infrastructure that OpenCode lacks.
   - Recommendation: redesign this for OpenCode rather than porting the Pi file verbatim.

### Do not port as current best practice for OpenCode

6. **Do not replace OpenCode's shared core prompts with the Pi versions**
   - Keep `_opencode/commands/dev:plan.md`, `review:change.md`, `review:change-integrate.md`, `ralph:run.md`, and `cmd:execute-plan.md` as the current source of truth.
   - Reason: the OpenCode versions are already stricter, more complete, or better adapted to OpenCode runtime behavior.

7. **Do not port Pi's interactive-review transport commands directly**
   - Commands: `review:change-claude-code.md`, `review:change-codex-cli.md`.
   - Reason: these are built around Pi's `interactive_shell` workflow and explicit backgrounded TUI lifecycle rules. They are not portable as-is to OpenCode.
   - VALIDATED: Confirmed Pi-specific dependencies exist in `_pi/prompts/review:change-claude-code.md` (references `interactive_shell` and TUI backgrounding). The recommendation to not port is sound.

8. **Do not prioritize `dev:parallel-team.md`**
   - Reason: it is an experimental, Pi-specific fan-out orchestration surface rather than a default repo-wide best-practice command.

## Recommended implementation order

## Phase 1: Add missing standard review entrypoint

### End State

- `_opencode/commands/review:plan.md` exists.
- It standardizes reviewed-plan review in OpenCode without weakening existing `review:change*` rules.
- It reuses existing OpenCode reviewer surfaces only and does not introduce Pi-only agent names or new review infrastructure.

### Tests first

- Confirm `review:change-gpt5.4.md` and `review:change-k2.5.md` already exist with `ls _opencode/commands/review:change-gpt5.4.md _opencode/commands/review:change-k2.5.md` and are the canonical review surfaces available to the new wrapper.
- Confirm no existing `_opencode/commands/review:plan.md` file exists with `test ! -e _opencode/commands/review:plan.md`.
- Behavioral test: `/review:plan thoughts/plans/test.md` should route the user to one of the existing `review:change*` surfaces using the same normalized plan argument, and it should not attempt standalone review logic or mention Pi-only agent names.
- Counterexample test: the new command must not mention `reviewer-plan-adversarial`, `reviewer-plan-synthesis`, or any `prd-*` agents.

### Work

- Create an OpenCode-native `review:plan.md` wrapper that normalizes the reviewed plan argument and points to the existing review surfaces.
- Keep the flow review-only and stop before `/review:change-integrate`.
- Reuse OpenCode's stronger review criteria instead of copying the Pi prompt body wholesale.

### Verify

- Run `ls _opencode/commands/review:plan.md` after creation to confirm the file exists.
- Read `_opencode/commands/review:plan.md` and confirm it references actual OpenCode reviewer surfaces only.
- Confirm it does not mention Pi-specific agent tooling or automatic Claude fallback behavior.
- Run a test invocation in OpenCode with a throwaway plan path, e.g. `/review:plan thoughts/plans/test.md`, and confirm it presents the existing review surfaces rather than attempting a standalone review.

## Phase 2: Decide whether to add execution-capability routing

### End State

- A clear go/no-go decision exists for `dev:run-direct`, `dev:run-high`, and `ralph:run-high` in OpenCode.
- If the decision is yes, the missing supporting agent work is explicitly captured.
- Existing capability variants (`ralph:run-mm.md`) are accounted for in the routing decision.

### Tests first

- Confirm whether OpenCode wants `/dev:run` to stay direct or become delegated by default.
- Confirm whether a `developer-high` OpenCode agent exists (it currently does not).
- Confirm `_opencode/commands/ralph:run-mm.md` exists with `ls _opencode/commands/ralph:run-mm.md` and document its relationship to any new capability routing.
- Behavioral test: if the decision is to keep current semantics, verify that no new `dev:run-direct` command is created and that `/dev:run` remains the sole direct execution entrypoint.
- Regression-guard test: any new routing must not create duplicate entrypoints with identical behavior.

### Work

- Survey existing capability variants in `_opencode/commands/` (including `ralph:run-mm.md`).
- If keeping current semantics, document that no sync is required and explicitly recommend *not* adding `dev:run-direct` so the repo does not end up with two paths for the same behavior.
- If adopting Pi-style routing, first decide how to handle existing variants (preserve, consolidate, or rename), then add any high-capability routes together with the supporting agent definitions.
- If routing is adopted, add or update a regression guard test that enforces a single canonical direct execution path.

### Verify

- Read `_opencode/agents/` and confirm the required execution agents exist before adding matching commands.
- Ensure command naming matches actual runtime behavior.
- Verify no duplicate entrypoints with identical behavior are created.

## Phase 3: Port PRD workflow only as a full package

### End State

- OpenCode either intentionally stays without the Pi PRD pipeline, or it gains the full reviewed-PRD contract end-to-end.
- The decision is documented with clear rationale and, if adopted, the required agents and artifact contract are present.

### Tests first

- Confirm whether OpenCode wants PRD-first planning as a supported workflow.
- Confirm the missing PRD agents and review artifact contracts are still absent.
- Behavioral test: if the decision is to port, verify that the following agents exist before any command work begins: `prd-critical-thinker`, `prd-researcher`, and at minimum the integration-focused `reviewer-prd-intent` agent.
- If the decision is not to port, the test is that the decision is recorded in `## Decisions / Deviations Log` and no PRD commands or agents are added.

### Work

- If the decision is to not port, document this as a postponed decision in `## Decisions / Deviations Log` with rationale.
- If parity is desired, port the PRD commands together with the missing agents and the status-artifact contract.
- Keep the handoff contract coherent: clarify → review → approved status artifact → plan materialization.

### Verify

- If the decision is no, verify the postponed decision is documented in `## Decisions / Deviations Log` and that no PRD command or agent files were added.
- If the decision is yes, verify every PRD command references only agents and artifacts that actually exist in `_opencode`.
- Confirm the workflow can be followed without any Pi-only runtime assumptions.

## Acceptance Criteria

1. The recommendation distinguishes commands that should be added from commands that should not overwrite stronger existing OpenCode prompts.
2. The recommendation identifies any missing agent/runtime dependencies that block direct parity.
3. The recommended order is actionable enough for a later implementation pass in `_opencode/commands/`.
4. The review avoids platform regressions by calling out Pi-only command surfaces that are not portable as-is.

## Verification Strategy

Use file-level inspection of `_pi/prompts/`, `_opencode/commands/`, and `_opencode/agents/` to decide whether each Pi command is:
- already superseded by a stronger OpenCode command,
- missing but directly portable,
- missing and requiring extra infrastructure,
- or intentionally Pi-specific.

Worked examples:
- `dev:plan` → determined to be superseded because `_opencode/commands/dev:plan.md` already has readiness-state gating, dependency-evaluation requirements, and stricter no-execution boundaries that the Pi version lacks.
- `review:plan` → determined to be missing but directly portable as a wrapper entrypoint because OpenCode already has `review:change-gpt5.4` and `review:change-k2.5` that provide the actual review behavior.

## Resume Instructions (Agent)

- Read this file fully before making updates.
- Start with the first unchecked item in `## Progress`.
- Preserve the rule that OpenCode should not regress stronger existing prompts just to mirror Pi naming.
- If a phase depends on a postponed decision in `## Decisions / Deviations Log`, resolve or restate that decision before implementation; do not treat the phase as ready for code work until its own tests and verify steps are actionable in the repo.

## Progress

- [ ] P1 - Add an OpenCode-native `review:plan` command.
- [ ] P2 - Decide whether to add execution-capability routing commands.
- [ ] P3 - Decide whether to port the full PRD workflow package.

## Decisions / Deviations Log

- 2026-04-06: Review concluded that parity should be selective. Shared core planning/execution prompts in `_opencode/commands/` are already stronger than the current Pi copies, so only missing workflow surfaces should be considered for porting.
- 2026-04-06 (POSTPONED): Does OpenCode want `/dev:run` to remain the direct path, or should it eventually match Pi's delegated default plus `/dev:run-direct`? This product-intent decision affects Phase 2 execution. Status: postponed pending maintainer decision.
- 2026-04-06 (POSTPONED): Is the Pi PRD workflow a desired OpenCode feature, or is that intentionally Pi-only for now? This product-intent decision affects Phase 3 execution. Status: postponed pending maintainer decision.

## Plan Changelog

- 2026-04-06: Initial review of Pi command deltas versus OpenCode best practice.
- 2026-04-06: Integrated review feedback: clarified `review:plan` as a wrapper entrypoint, added a dependency inventory, tightened phase-level behavioral tests and verify commands, added regression-guard language for routing decisions, refined PRD decision gates, and updated resume instructions to respect postponed decisions.
