---
description: Execute work using parallel team with fan-out pattern - 3 developer-mm agents per group + selector, TDD-driven, with iterative quality loop
argument-hint: '<specification> [--groups=N] [--strategy=a,b,c]'
---

# Parallel Team Execution with Fan-Out

Execute complex implementation work using a parallel team structure:

- **Phase 1**: TDD Test Writer creates failing (red) tests
- **Phase 2**: Parallel fan-out to N groups, each with 3 `developer-mm` agents (different strategies) + 1 quality-reviewer selector
- **Phase 3**: Integrate selected implementations from all groups
- **Phase 4**: Final quality-reviewer iterates with `developer-mm` until clean

## Arguments

- `$ARGUMENTS`: Specification of work to implement (file path, description, or plan slug)
- `--groups=N` (optional): Number of parallel groups (default: 3, max: 5)
- `--strategy=a,b,c` (optional): Comma-separated strategy names for the 3 `developer-mm` agents (default: conservative,aggressive,balanced)

## Execution Flow

### Phase 0: Parse Arguments and Setup

Parse the input specification:

- If file path: read specification from file
- If slug: read from `thoughts/plans/<slug>.md`
- If plain text: treat as inline specification

Determine parallelization:

- `GROUPS=${GROUPS:-3}`
- `STRATEGIES=${STRATEGIES:-"conservative,aggressive,balanced"}`

Use the actual Pi tool surface:

- launch workers with `Agent`
- wait with `get_subagent_result(..., wait: true)`
- run every parallel implementation worker with `isolation: "worktree"` so candidates cannot overwrite each other
- do not use placeholder `Task(...)` syntax

### Phase 1: TDD Test Writer (RED)

Launch one `developer-mm` agent to create the failing tests first.

Required prompt shape:

> Specification: `$SPECIFICATION`
>
> You are in TDD RED PHASE mode. Write comprehensive failing tests that:
> - cover all acceptance criteria from the specification
> - include edge cases and error conditions
> - use the project-standard testing framework
> - live in appropriate test files
> - fail against the current codebase before implementation
>
> Do not implement production code.
> Run the tests to confirm they fail.
> Return the created test files, the commands run, and the failing evidence.

Wait for the test writer to complete before moving to Phase 2.

Capture:

- test file paths
- commands used to demonstrate RED
- expected behavior defined by the tests

### Phase 2: Parallel Group Fan-Out

Launch `N` groups in parallel. Each group works independently.

For each group:

1. Read the specification and the red tests.
2. Launch 3 parallel `developer-mm` implementation agents using the requested strategies.
3. Each implementation agent must run in its own isolated worktree (`isolation: "worktree"`).
4. Wait for all 3 results.
5. Launch one `quality-reviewer` to select the best implementation from that group.
6. Return the selected implementation, rejected alternatives, the selector rationale, and the winning worktree/branch reference.

#### Developer roles per group

Every group must use these three `developer-mm` variants:

- **Conservative**
  - prefer existing repo patterns
  - no new dependencies
  - optimize for stability and maintainability
- **Aggressive**
  - prioritize performance and modern patterns
  - allow a new dependency only with explicit justification
  - optimize for speed and innovation
- **Balanced**
  - default to existing patterns
  - allow one strategic improvement when clearly justified
  - balance stability with targeted modernization

Each implementation prompt must require:

- make all red tests pass
- zero linting violations
- project-convention alignment
- robust error handling
- a truthful summary of what still fails, if anything
- the worker’s isolated worktree path or branch reference
- the touched file list
- the verification commands and results

#### Group selector

After the three `developer-mm` implementations finish, launch one `quality-reviewer` for that group.

The selector must review the candidates as separate isolated outputs. Do not compare mixed shared-checkout state.

Selector responsibilities:

- compare all 3 implementations using their isolated worktree/branch references plus returned file lists and verification evidence
- reject any implementation that does not actually pass the red tests
- choose exactly one implementation to carry forward
- explain the choice in terms of maintainability, correctness, performance, alignment with repo patterns, and error handling

#### Group failure rule

If all 3 implementations in a group fail:

- mark the group as failed
- include the failure reasons in the group summary
- continue with other successful groups

### Phase 3: Integration

After all groups finish, integrate the selected implementations into one cohesive solution.

Use a `developer-mm` integrator prompt that requires:

- reading the selected isolated worktree outputs and merging only the chosen candidates into the main solution
- resolving conflicts between selected group outputs
- preserving the passing test behavior from the chosen implementations
- keeping style and patterns consistent
- rerunning the relevant tests after integration
- returning final file paths plus verification results

If some groups failed entirely, integrate only from the successful groups and say so explicitly.

### Phase 4: Final Quality Loop

Run a final quality loop until clean or until you hit the iteration limit.

- reviewer: `quality-reviewer`
- fixer: `developer-mm`
- max passes: 5

Loop contract:

1. Run `quality-reviewer` on the integrated implementation.
2. If the review says clean, stop.
3. If it reports issues, launch `developer-mm` to fix those specific issues.
4. Re-run verification.
5. Repeat until clean or max passes reached.

Do not claim success while substantive quality findings remain unresolved.

## Output

After completion, provide:

```markdown
## Parallel Team Execution Complete

### Configuration
- Groups: <N>
- Strategies: <strategy list>
- Quality iterations: <count>

### Results by Group
| Group | Selected Strategy | Outcome | Reason |
| --- | --- | --- | --- |
| 1 | conservative/aggressive/balanced | selected/failed | ... |

### Final Output
- Integrated implementation: [file paths]
- Test results: pass/fail
- Quality status: clean/needs review
- Lint status: pass/fail

### Next Steps
- If clean: work complete
- If max quality iterations reached: manual review required
```

## Safety Limits

- Max groups: 5
- Max quality loop iterations: 5
- All implementations must pass the red tests to be eligible for selection
- Zero linting tolerance across all selected and integrated code
