---
description: Execute work using parallel team with fan-out pattern - 3 developers per group + selector, TDD-driven, with iterative quality loop
argument-hint: '<specification> [--groups=N] [--strategy=a,b,c]'
---

# Parallel Team Execution with Fan-Out

Execute complex implementation work using a parallel team structure:
- **Phase 1**: TDD Test Writer creates failing (red) tests
- **Phase 2**: Parallel fan-out to N groups, each with 3 developers (different strategies) + 1 quality-reviewer (selector)
- **Phase 3**: Integrate selected implementations from all groups
- **Phase 4**: Final quality-reviewer iterates with developer until clean

## Arguments

- `$ARGUMENTS`: Specification of work to implement (file path, description, or plan slug)
- `--groups=N` (optional): Number of parallel groups (default: 3, max: 5)
- `--strategy=a,b,c` (optional): Comma-separated strategy names for the 3 developers (default: conservative,aggressive,balanced)

## Execution Flow

### Phase 0: Parse Arguments and Setup

Parse input specification:
- If file path: read specification from file
- If slug: read from `thoughts/plans/<slug>.md`
- If plain text: treat as inline specification

Determine parallelization:
```bash
GROUPS=${GROUPS:-3}
STRATEGIES=${STRATEGIES:-"conservative,aggressive,balanced"}
```

### Phase 1: TDD Test Writer - Create Red Tests

Spawn developer-mm (in test-writer mode) to create comprehensive failing tests:

```
Task(
  subagent_type="developer-mm",
  description="Write failing tests for specification (TDD RED phase)",
  prompt="""
  Specification: $SPECIFICATION
  
  You are in TDD RED PHASE mode. Write comprehensive FAILING tests that:
  - Cover all acceptance criteria from the specification
  - Include edge cases and error conditions
  - Use project-standard testing framework (check CLAUDE.md/TESTING.md)
  - Are in test files at appropriate locations
  - Will FAIL when run against current codebase (no implementation yet)
  
  Do NOT implement any production code - only write failing tests.
  Run tests to confirm they fail (RED).
  Return: List of test files created and what each test verifies.
  """


Wait for test writer to complete. Capture:
- Test file paths
- Expected behavior defined by tests

### Phase 2: Parallel Group Fan-Out

Launch N parallel groups. Each group operates independently.

**For each group i in 1..N:**

#### Group Task Structure

```
# Launch group in parallel with other groups
Task(
  subagent_type="general",
  description="Parallel implementation group $i",
  prompt="""
  You are Group $i of $GROUPS implementing: $SPECIFICATION
  
  Red tests have been written. Your job:
  1. Read the red tests to understand requirements
  2. Coordinate 3 parallel developer implementations
  3. Have quality-reviewer select the best
  
  ## Step 1: Spawn 3 Developers (Parallel)
  
  Launch 3 Task() calls simultaneously with developer-mm:
  
  **Developer A (Conservative Strategy):**
  ```
  Task(
    subagent_type="developer-mm",
    description="Group $i - Conservative implementation",
    prompt=f"""
    Specification: $SPECIFICATION
    Strategy: CONSERVATIVE
    - Use ONLY patterns already existing in the codebase
    - NO new dependencies
    - Prefer copy-paste-modify from existing similar features
    - Optimize for stability and maintainability
    
    Red tests exist at: [test file paths]
    Make ALL these tests PASS (GREEN phase).
    
    Constraints:
    - Zero linting violations
    - Follow project conventions from CLAUDE.md
    - Handle all errors appropriately
    - Write minimal code to make tests pass
    """
  )
  ```
  
  **Developer B (Aggressive Strategy):**
  ```
  Task(
    subagent_type="developer-mm",
    description="Group $i - Aggressive implementation",
    prompt=f"""
    Specification: $SPECIFICATION
    Strategy: AGGRESSIVE
    - PRIORITIZE performance and modern patterns
    - New dependencies allowed with explicit justification
    - Explore newer features (streaming, async, etc.)
    - Optimize for speed and innovation
    
    Red tests exist at: [test file paths]
    Make ALL these tests PASS (GREEN phase).
    
    Constraints:
    - Zero linting violations
    - Follow project conventions from CLAUDE.md
    - Handle all errors appropriately
    - Can refactor existing patterns if justified
    """
  )
  ```
  
  **Developer C (Balanced Strategy):**
  ```
  Task(
    subagent_type="developer-mm",
    description="Group $i - Balanced implementation",
    prompt=f"""
    Specification: $SPECIFICATION
    Strategy: BALANCED
    - Prefer EXISTING patterns in the codebase
    - ONE new dependency allowed if it significantly improves code
    - Balance stability with reasonable innovation
    - Default to conservative, allow one strategic optimization
    
    Red tests exist at: [test file paths]
    Make ALL these tests PASS (GREEN phase).
    
    Constraints:
    - Zero linting violations
    - Follow project conventions from CLAUDE.md
    - Handle all errors appropriately
    - Best practices from both worlds
    """
  )
  ```
  
  Wait for all 3 developers to complete.
  
  ## Step 2: Quality Reviewer - Select Best Implementation
  
  Spawn quality-reviewer to evaluate all 3 implementations:
  
  ```
  Task(
    subagent_type="quality-reviewer",
    description="Group $i - Select best implementation",
    prompt=f"""
    Review 3 implementations of: $SPECIFICATION
    
    Implementation A (Conservative): [file paths, summary]
    Implementation B (Aggressive): [file paths, summary]
    Implementation C (Balanced): [file paths, summary]
    
    All must pass the red tests.
    
    Evaluate on:
    1. Code quality and maintainability
    2. Performance characteristics
    3. Alignment with project patterns
    4. Error handling robustness
    5. Test coverage completeness
    
    Select ONE implementation to keep.
    
    Return:
    - Selected strategy (A/B/C)
    - File paths of selected implementation
    - Brief justification for selection
    - List of rejected implementations with reasons
    """
  )
  ```
  
  Capture the selected implementation from this group.
  """
)
```

Wait for ALL N groups to complete. Collect:
- Group 1 selected implementation
- Group 2 selected implementation
- ...
- Group N selected implementation

### Phase 3: Integration

Integrate all N selected implementations into a cohesive solution:

```
Task(
  subagent_type="developer-mm",
  description="Integrate selected implementations",
  prompt=f"""
  Integrate $GROUPS selected implementations into one cohesive solution.
  
  Selected implementations:
  - Group 1 (Strategy X): [files]
  - Group 2 (Strategy Y): [files]
  - ...
  
  Integration requirements:
  1. Resolve any conflicts between implementations
  2. Ensure all red tests still pass
  3. Maintain consistent style and patterns
  4. Produce clean, unified codebase
  
  Return: Final integrated file paths and summary.
  """
)
```

### Phase 4: Final Quality Loop (Iterative)

Run quality-reviewer in a loop until clean:

```
QUALITY_PASSES = 0
MAX_PASSES = 5

while QUALITY_PASSES < MAX_PASSES:
    
    # Run final quality review
    Task(
      subagent_type="quality-reviewer",
      description="Final quality review - iteration $QUALITY_PASSES",
      prompt=f"""
      Review the integrated implementation: [file paths]
      
      Specification: $SPECIFICATION
      
      Check for:
      - Security issues
      - Performance problems
      - Data loss risks
      - Code quality issues
      - Testing gaps
      - Error handling gaps
      
      Return:
      - Status: CLEAN or NEEDS_FIX
      - If NEEDS_FIX: list specific issues with file:line references
      - If CLEAN: confirm all quality gates pass
      """
    )
    
    if review.status == "CLEAN":
        break
    
    # If issues found, spawn developer-mm to fix
    Task(
      subagent_type="developer-mm",
      description="Fix quality issues - iteration $QUALITY_PASSES",
      prompt=f"""
      Fix the following quality issues in the integrated implementation:
      
      Issues from quality-reviewer:
      [list all issues with file:line references]
      
      Requirements:
      - Address ALL issues
      - Maintain zero linting violations
      - Ensure all tests still pass
      - Follow project conventions
      
      Return: Summary of fixes made.
      """
    )
    
    QUALITY_PASSES += 1

if QUALITY_PASSES >= MAX_PASSES:
    Report: "Quality loop reached max iterations. Manual review required."
```

## Output

After completion, provide:

```
## Parallel Team Execution Complete

### Configuration:
- Groups: $GROUPS
- Strategies: $STRATEGIES
- Quality iterations: $QUALITY_PASSES

### Results by Group:
| Group | Selected Strategy | Reason |
|-------|------------------|--------|
| 1 | [strategy] | [brief justification] |
| 2 | [strategy] | [brief justification] |
| ... | ... | ... |

### Final Output:
- Integrated implementation: [file paths]
- Test results: [pass/fail]
- Quality status: [clean/needs review]
- Lint status: [pass/fail]

### Next Steps:
[If quality loop maxed out, recommend manual review. Otherwise, work is complete.]
```

## Example Usage

```bash
# Default: 3 groups with conservative/aggressive/balanced strategies
/dev:parallel-team "Implement user authentication API"

# 5 groups for larger work
/dev:parallel-team "Build payment processing system" --groups=5

# Custom strategies
/dev:parallel-team "Optimize database queries" --strategy=minimal,cached,indexed

# From plan file
/dev:parallel-team thoughts/plans/auth-implementation.md
```

## Edge Cases

### All Strategies in a Group Fail
If all 3 developers in a group fail to produce passing tests:
- Quality-reviewer marks group as FAILED
- Other groups continue
- Integration phase works with remaining successful groups
- Report includes failed group analysis

### Quality Reviewer Cannot Decide
If quality-reviewer cannot select a clear winner:
- Request brief justification for top 2 choices
- Select based on project priorities (maintainability > performance for most projects)
- Log ambiguity for post-execution review

### Integration Conflicts
If selected implementations have irreconcilable conflicts:
- Document conflicts
- Spawn emergency integration review with quality-reviewer
- May require re-running specific groups with adjusted strategies

## Safety Limits

- Max groups: 5 (resource constraint)
- Max quality loop iterations: 5 (prevents infinite loops)
- All implementations must pass red tests to be considered
- Zero linting tolerance across all code
