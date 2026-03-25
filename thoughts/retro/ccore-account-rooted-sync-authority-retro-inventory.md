# ccore account-rooted sync authority retrospective inventory

## Purpose

This document inventories the evidence trail for the ccore account-rooted sync authority change set: why it mattered, how the implementation landed, what still broke after merge, and what evidence another agent should inspect before judging whether the rework was sufficient.

This is a retrospective inventory, not a design spec. It is intended to let a fresh reviewer independently audit the historical arc and identify follow-up improvement opportunities.

## Plain-language summary of the issue

The historical problem was a sync-authority model rooted at the account level that required coordinated changes across the core authority model, node persistence/migrations, HTTP and runtime wiring, CLI/MCP surfaces, and the hub contract/spec/test surface.

The implementation successfully introduced the account-rooted authority model, but the follow-through needed additional repair work after the main feature merged. The confirmed repair sequence shows that some important validation and refresh behavior still diverged from the intended source-of-truth handling, especially around membership refresh and verification against raw hub payload data.

## Scope and evidence boundaries

### Confirmed
- Primary historical topic: ccore account-rooted sync authority implementation and follow-up repairs.
- Recommended primary arc: `1534acdba0abd5773ec8cf57669c795936df79f5` (`Add account-rooted sync authority migration plan with explicit hub contract coverage requirements`) through `20add4a3fc2ead7aadbd83f43c592e10eebcb91e` (`fix: verify membership refresh against raw hub payload`).
- Branch-contained arc: `1534acdba0abd5773ec8cf57669c795936df79f5` through `c7fb6bc5ecba4bdeaf3943edb15623b983de9551`.
- Main implementation commit: `32f1e4689b680224bdbc8cfb03577593119ca453` (`feat: add account-rooted sync authority`).
- Merge commit: `265f5c8c59e31c9a36ad3e85c6b5251119d44bba`.
- Post-merge fixes: `1aa413b10f7f2f9549efa40006f31da215177daf` and `20add4a3fc2ead7aadbd83f43c592e10eebcb91e`.
- Original implementation evidence is overwhelmingly in OpenCode.
- Oh My Pi evidence appears after merge and focuses on rollout validation and remediation.

### Bounded inferences
- The feature likely required more than a narrow data-model change because the touched-file inventory spans storage, runtime, API, CLI/MCP, hub contract tests, smoke coverage, architecture/spec docs, discovery notes, and plan/test-matrix artifacts.
- The post-merge fixes strongly suggest the initial landing had contract or validation gaps that were not fully caught before merge, even though planning and review coverage existed.
- The review process appears stronger on up-front planning than on final proof that runtime refresh logic matched raw upstream payload semantics.

### Negative finding within searched scope
- No direct repo-scoped Claude/Opus review session tied to this authority work was found in the searched OpenCode/OMP evidence window. This is a negative result within the searched evidence only, not a global claim that no such review ever existed.

## Chronology

### 1. Planning and readiness
- `1534acdba0abd5773ec8cf57669c795936df79f5` established the migration-plan baseline with explicit contract-coverage requirements.
- The planning and review trail includes readiness review, plan commit/branch creation, and multiple plan-review sessions tied to the sync-authority plan document.

### 2. Initial implementation and branch completion
- `32f1e4689b680224bdbc8cfb03577593119ca453` is the main implementation commit for account-rooted sync authority.
- The branch-contained arc continues through `c7fb6bc5ecba4bdeaf3943edb15623b983de9551`, which is the confirmed branch-side repair point associated with PR feedback.

### 3. Merge to mainline
- `265f5c8c59e31c9a36ad3e85c6b5251119d44bba` is the merge commit.

### 4. Post-merge remediation
- `1aa413b10f7f2f9549efa40006f31da215177daf` repaired behavior spanning CLI entrypoints, node DB handling, and HTTP surface.
- `20add4a3fc2ead7aadbd83f43c592e10eebcb91e` narrowed onto `crates/ccore-node/src/db.rs` with the explicit fix summary `fix: verify membership refresh against raw hub payload`.
- The repair sequence confirms that merge did not end the investigation; rollout validation and remediation continued afterward.

## Implementation and rework arc

### Confirmed implementation arc
The main implementation introduced account-rooted sync authority across these confirmed surfaces:
- authority model and exports in `crates/ccore-core`
- node schema/migrations and DB/runtime/HTTP wiring in `crates/ccore-node`
- CLI and MCP wrappers/tests in `crates/ccore-cli`
- hub contract implementation/tests/smoke coverage in `packaging/cloudflare/hub`
- architecture/spec/discovery/plan artifacts in `spec/` and `thoughts/`

### Confirmed follow-up rework arc
The rework happened in two phases:
1. Branch-side feedback and repair before or during PR finalization, culminating in `c7fb6bc5ecba4bdeaf3943edb15623b983de9551`.
2. Post-merge fixes on mainline, specifically `1aa413b10f7f2f9549efa40006f31da215177daf` and `20add4a3fc2ead7aadbd83f43c592e10eebcb91e`.

### What still failed after merge
### Confirmed
- After merge, membership refresh verification still needed correction against the raw hub payload, as shown directly by `20add4a3fc2ead7aadbd83f43c592e10eebcb91e`.
- The first post-merge fix also touched node DB and HTTP behavior together with CLI behavior, which confirms the issue was not isolated to one layer.

### Inferred
- The most plausible failure mode is that the system accepted or transformed refreshed membership state in a way that did not preserve the intended verification contract against upstream payload truth.
- Because the final fix is DB-only while the prior one spans CLI/HTTP/DB, the bug likely surfaced first as an end-to-end behavior mismatch and then was reduced to a more local persistence/verification defect.

## Commit inventory

| Role | Commit SHA | Summary |
| --- | --- | --- |
| Plan baseline | `1534acdba0abd5773ec8cf57669c795936df79f5` | `Add account-rooted sync authority migration plan with explicit hub contract coverage requirements` |
| Main implementation | `32f1e4689b680224bdbc8cfb03577593119ca453` | `feat: add account-rooted sync authority` |
| Branch repair endpoint | `c7fb6bc5ecba4bdeaf3943edb15623b983de9551` | Confirmed branch-contained end of the implementation arc |
| Merge commit | `265f5c8c59e31c9a36ad3e85c6b5251119d44bba` | Merge of the feature work |
| Post-merge fix 1 | `1aa413b10f7f2f9549efa40006f31da215177daf` | Confirmed remediation touching CLI, DB, and HTTP |
| Post-merge fix 2 | `20add4a3fc2ead7aadbd83f43c592e10eebcb91e` | `fix: verify membership refresh against raw hub payload` |

## Important touched files

### Main implementation surfaces
- `crates/ccore-core/src/authority.rs`
- `crates/ccore-core/src/lib.rs`
- `crates/ccore-node/migrations/0009_authority_state.sql`
- `crates/ccore-node/migrations/0010_space_key_epoch.sql`
- `crates/ccore-node/src/db.rs`
- `crates/ccore-node/src/http.rs`
- `crates/ccore-node/src/main.rs`
- `crates/ccore-node/src/sync_runtime.rs`
- `crates/ccore-cli/src/main.rs`
- `crates/ccore-cli/src/mcp/tools/account_wrappers.rs`
- `crates/ccore-cli/src/mcp/tools/node_backed.rs`
- `crates/ccore-cli/tests/mcp_stdio_spec.rs`
- `packaging/cloudflare/hub/src/index.ts`
- `packaging/cloudflare/hub/src/contracts/authority.test.ts`
- `packaging/cloudflare/hub/scripts/smoke.mjs`
- `spec/architecture/account-control-plane-and-invite-ux.md`
- `spec/architecture/sync-hub-delivery.md`
- `thoughts/discoveries/account-rooted-sync-authority.md`
- `thoughts/plans/account-rooted-sync-authority-test-matrix.md`
- `thoughts/plans/account-rooted-sync-authority.md`
- `thoughts/specs/v1-local-http-api.md`
- `thoughts/specs/v1-sync-hub.md`

### Confirmed feature-branch fix files
- `crates/ccore-cli/src/main.rs`
- `crates/ccore-cli/src/mcp/tools/account_wrappers.rs`
- `crates/ccore-node/src/db.rs`
- `packaging/cloudflare/hub/src/index.ts`

### Confirmed post-merge fix files
#### `1aa413b10f7f2f9549efa40006f31da215177daf`
- `crates/ccore-cli/src/main.rs`
- `crates/ccore-node/src/db.rs`
- `crates/ccore-node/src/http.rs`

#### `20add4a3fc2ead7aadbd83f43c592e10eebcb91e`
- `crates/ccore-node/src/db.rs`

## OpenCode evidence inventory

### Confirmed implementation/session chain
- `ses_303a0f9e5ffeK6LKdJtDg6Pgc4` — readiness review
- `ses_301209bb2ffeG49zDZeRXvv04s` — plan committed as `1534acd` and branch created
- `ses_300bd710effeNKXy3eHzdYbmkC` — initial migration execution
- `ses_2ff22b071ffera2WbISCUy4ZR6` — continued execution
- `ses_2f9d745ffffe2R4w5V3Dgykhbe` — final phase completion
- `ses_2f7897ed1ffeEEykXVhR38PCwH` — branch landing / PR opened with `32f1e46`
- `ses_2f475f83fffegeQ3xgI3BuKh2t` — PR feedback leading to `c7fb6bc`

### Confirmed plan-review sessions tied to `thoughts/plans/account-rooted-sync-authority.md`
- `ses_305f6b474ffekpC6GGZhbWe7Vb`
- `ses_3046e2c8effeMDYP1NRexoZ7VV`
- `ses_303ba6131ffeYXskxFeFEmQjr1`
- `ses_2fd8d90e1ffepuwLH9nQHPzOSR`
- `ses_304391f3cffeKmDJrHPMlZCuHY` — integrating review comments into sync plan

### What these sessions collectively confirm
- The implementation was not a single-shot code change; it was planned, reviewed, executed in phases, landed through PR flow, and then repaired in response to feedback.
- The evidence density is highest in OpenCode for the original implementation/rework arc.

## Oh My Pi evidence inventory

### Confirmed follow-on contexts
- `/Users/anichols/.omp/agent/sessions/-code-ccore/2026-03-20T19-15-49-756Z_149a788c5f3ffb3a/context.md`
- `/Users/anichols/.omp/agent/sessions/-code-ccore/2026-03-20T23-12-13-851Z_149aaea806dcb123/context.md`

### Confirmed interpretation of OMP evidence
- OMP evidence appears after merge.
- The OMP material focuses on rollout validation and remediation, not on the original bulk of implementation work.

## What is confirmed vs inferred

### Confirmed facts
- The account-rooted sync authority work spans planning, execution, PR iteration, merge, and post-merge repair.
- The main implementation commit is `32f1e4689b680224bdbc8cfb03577593119ca453`.
- The branch-contained arc ends at `c7fb6bc5ecba4bdeaf3943edb15623b983de9551`.
- The merge commit is `265f5c8c59e31c9a36ad3e85c6b5251119d44bba`.
- Post-merge repairs are `1aa413b10f7f2f9549efa40006f31da215177daf` and `20add4a3fc2ead7aadbd83f43c592e10eebcb91e`.
- `20add4a3fc2ead7aadbd83f43c592e10eebcb91e` explicitly addresses verification of membership refresh against raw hub payload.
- The original implementation evidence is concentrated in OpenCode sessions.
- The later remediation evidence is represented in OMP contexts.

### Bounded inferences worth testing
- The review gap was probably not absence of planning but insufficient end-to-end proof that refreshed authority/membership state stayed faithful to raw upstream contract data.
- A fresh reviewer should pay special attention to any code path that transforms, caches, verifies, or refreshes authority membership data between upstream payload receipt and local persistence.
- Cross-surface parity likely mattered: CLI, MCP, HTTP, runtime, and hub contract layers all appear in the touched-file set.

## How another agent should use this inventory

1. Start with the commit arc, not the codebase head, to avoid present-day drift.
2. Read the plan and discovery/spec artifacts before reading the fixes, so the intended contract is clear.
3. Use the OpenCode session chain to reconstruct decision flow and PR feedback.
4. Use the OMP contexts to reconstruct what failed late enough to require rollout validation/remediation.
5. Treat the negative finding about missing repo-scoped Claude/Opus review as bounded to the searched window only.

## How to re-verify this investigation

### 1. Reconstruct the commit arc with git history
Run these commands in the ccore repository:

```bash
git log --oneline --decorate --graph 1534acdba0abd5773ec8cf57669c795936df79f5^..20add4a3fc2ead7aadbd83f43c592e10eebcb91e
git show --stat 32f1e4689b680224bdbc8cfb03577593119ca453
git show --stat c7fb6bc5ecba4bdeaf3943edb15623b983de9551
git show --stat 1aa413b10f7f2f9549efa40006f31da215177daf
git show --stat 20add4a3fc2ead7aadbd83f43c592e10eebcb91e
git diff --name-only 1534acdba0abd5773ec8cf57669c795936df79f5..c7fb6bc5ecba4bdeaf3943edb15623b983de9551
git diff --name-only 265f5c8c59e31c9a36ad3e85c6b5251119d44bba^..20add4a3fc2ead7aadbd83f43c592e10eebcb91e
```

### 2. Re-read the plan/spec/discovery artifacts from the historical branch context
Inspect these files at or around the implementation arc:

```bash
git show 32f1e4689b680224bdbc8cfb03577593119ca453:thoughts/plans/account-rooted-sync-authority.md
git show 32f1e4689b680224bdbc8cfb03577593119ca453:thoughts/plans/account-rooted-sync-authority-test-matrix.md
git show 32f1e4689b680224bdbc8cfb03577593119ca453:thoughts/discoveries/account-rooted-sync-authority.md
git show 32f1e4689b680224bdbc8cfb03577593119ca453:thoughts/specs/v1-sync-hub.md
git show 32f1e4689b680224bdbc8cfb03577593119ca453:thoughts/specs/v1-local-http-api.md
```

### 3. Audit the session chain in OpenCode DB
Use `opencode db` with SQL queries; the useful evidence is in the `session` and `part` tables.

```bash
opencode db "select id, datetime(time_created/1000,'unixepoch','localtime') as created, title, directory from session where id in (
  'ses_303a0f9e5ffeK6LKdJtDg6Pgc4',
  'ses_301209bb2ffeG49zDZeRXvv04s',
  'ses_300bd710effeNKXy3eHzdYbmkC',
  'ses_2ff22b071ffera2WbISCUy4ZR6',
  'ses_2f9d745ffffe2R4w5V3Dgykhbe',
  'ses_2f7897ed1ffeEEykXVhR38PCwH',
  'ses_2f475f83fffegeQ3xgI3BuKh2t',
  'ses_305f6b474ffekpC6GGZhbWe7Vb',
  'ses_3046e2c8effeMDYP1NRexoZ7VV',
  'ses_303ba6131ffeYXskxFeFEmQjr1',
  'ses_2fd8d90e1ffepuwLH9nQHPzOSR',
  'ses_304391f3cffeKmDJrHPMlZCuHY'
 ) order by time_created;" --format tsv

opencode db "select p.session_id, datetime(p.time_created/1000,'unixepoch','localtime') as created, substr(json_extract(p.data,'$.text'),1,240) as text from part p where p.session_id='ses_301209bb2ffeG49zDZeRXvv04s' order by p.time_created;" --format tsv

opencode db "select p.session_id, datetime(p.time_created/1000,'unixepoch','localtime') as created, substr(json_extract(p.data,'$.text'),1,240) as text from part p where p.session_id='ses_2f475f83fffegeQ3xgI3BuKh2t' order by p.time_created;" --format tsv
```

Suggested checks while reviewing those sessions:
- confirm which session introduced each milestone commit
- confirm when PR feedback first called out the remaining gaps
- confirm whether any review explicitly validated refresh behavior against raw upstream payloads
- look for any repo-scoped Claude/Opus review reference; if none appears in this same search window, keep the finding phrased as a scoped negative result

### 4. Read the OMP follow-on contexts directly
Inspect the confirmed OMP context files:
- `/Users/anichols/.omp/agent/sessions/-code-ccore/2026-03-20T19-15-49-756Z_149a788c5f3ffb3a/context.md`
- `/Users/anichols/.omp/agent/sessions/-code-ccore/2026-03-20T23-12-13-851Z_149aaea806dcb123/context.md`

Useful local commands:

```bash
sed -n '1,220p' /Users/anichols/.omp/agent/sessions/-code-ccore/2026-03-20T19-15-49-756Z_149a788c5f3ffb3a/context.md
sed -n '1,220p' /Users/anichols/.omp/agent/sessions/-code-ccore/2026-03-20T23-12-13-851Z_149aaea806dcb123/context.md
```

### 5. Re-check the highest-risk code surfaces
After reconstructing the history, inspect these areas carefully in the relevant commits:
- `crates/ccore-node/src/db.rs`
- `crates/ccore-node/src/http.rs`
- `crates/ccore-node/src/sync_runtime.rs`
- `crates/ccore-cli/src/main.rs`
- `crates/ccore-cli/src/mcp/tools/account_wrappers.rs`
- `packaging/cloudflare/hub/src/index.ts`
- `packaging/cloudflare/hub/src/contracts/authority.test.ts`

Focus questions:
- Where is authority state sourced, transformed, persisted, refreshed, and verified?
- Which tests prove parity between upstream contract payloads and local membership-refresh behavior?
- Which assumptions were encoded in branch fixes versus post-merge fixes?

## Reviewer takeaways

- The evidence supports a real implementation-and-repair arc, not a one-commit feature.
- Planning/review artifacts existed, but the final repair history shows that contract-faithful refresh verification still escaped into post-merge remediation.
- A future reviewer should treat raw upstream payload fidelity and cross-surface parity as the central audit themes.