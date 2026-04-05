---
name: ralph-run
description: Execute a plan with quality-gated phases - developer implements, reviewer loops until quality passes. Use for autonomous plan execution with quality gates.
---

# Ralph Run - Quality-Gated Plan Execution

Execute a reviewed plan document phase-by-phase. For each phase, do 1 implementation pass, then repeat review/fix passes until the reviewer finds zero issues or explicitly confirms that only low-risk deferred items remain.

## Overview

This skill implements the ralph pattern:
1. **Developer** implements the phase (1 pass)
2. **Quality-Reviewer** reviews and fixes issues (loop until pass or low-risk only)
3. **Quality Gate** - phases don't advance with unresolved substantive issues
4. **Discovery Ledger** - captures deferred work for later triage

## Prerequisites

Requires the `@tintinweb/pi-subagents` extension for agent delegation.

## Usage

```
/skill:ralph-run <slug | path/to/plan.md>
```

Examples:
```
/skill:ralph-run user-profile-redesign
/skill:ralph-run thoughts/plans/my-feature.md
```

## Agent Configuration

This skill uses two subagents that are defined inline:

### 1. ralph-developer

Created on-demand with this configuration:
- **model**: `anthropic/claude-sonnet-4` (configurable via RALPH_DEV_MODEL env var)
- **systemPrompt**: Developer focused on plan implementation with fidelity

### 2. ralph-quality-reviewer

Created on-demand with this configuration:
- **model**: `anthropic/claude-sonnet-4` (configurable via RALPH_REVIEW_MODEL env var)
- **systemPrompt**: Quality reviewer focused on gaps, bugs, regressions, plan fidelity

## Process

### 1) Resolve Plan Path

```bash
# If argument is a slug
plan_path="thoughts/plans/${ARGUMENTS}.md"

# If argument is a path
plan_path="${ARGUMENTS}"

# Derive
discovery_path="thoughts/discoveries/$(basename "$plan_path" .md).md"
```

### 2) Validate Plan Readiness

Read `plan_path` fully. Confirm:
- `## Progress` exists with unchecked items
- `Resume Instructions (Agent)` exists
- Each phase has `### End State`, `### Tests first`, `### Work`, `### Verify`
- No unresolved `Open Questions` or `Decision Points`
- No unresolved inline `[REVIEW:...]` comments remain unless the user explicitly approved executing with them present
- If this repo uses the Pi reviewed-plan flow, the plan reached execution through an explicit handoff such as `/review:plan` -> `/review:change-integrate` -> optional `/review:plan-adversarial` -> `/cmd:execute-plan`, not through an implicit fallback reviewer
- Verify commands match repo reality

If not ready, STOP and ask user to fix the plan.

### 3) Ensure Agents Exist

Create agents if they don't exist:

```javascript
// Check if agents exist
subagent({ action: "list" })

// Create ralph-developer if needed
subagent({
  action: "create",
  config: {
    name: "ralph-developer",
    description: "Developer for plan implementation - writes code to spec",
    model: process.env.RALPH_DEV_MODEL || "anthropic/claude-sonnet-4",
    systemPrompt: `You are a Developer who implements plan phases with absolute fidelity.

Read the plan file fully. Find the specified phase and implement exactly what is described.

## Core Rules
1. Treat the plan as source of truth - don't expand scope
2. Write tests first (from ### Tests first) unless plan explains why not
3. Implement ### Work items to achieve ### End State
4. Run ### Verify commands to confirm success
5. Record deferred discoveries per Discovery Protocol

## Discovery Protocol
When you find work beyond current phase:
- Bucket A (Required for phase): Do it now
- Bucket B (Beneficial local improvement): Do if small and clear
- Bucket C (Deferred): Record in discovery_path, continue
- Bucket D (Blocking): Ask user

## Output
Report what was implemented, tests written, verification results, and any deferred discoveries.`
  }
})

// Create ralph-quality-reviewer if needed
subagent({
  action: "create",
  config: {
    name: "ralph-quality-reviewer",
    description: "Quality reviewer - finds gaps, bugs, plan fidelity issues",
    model: process.env.RALPH_REVIEW_MODEL || "anthropic/claude-sonnet-4",
    systemPrompt: `You are a Quality Reviewer who reviews implementations against plans.

Read the plan file fully. Review the implementation of the specified phase for:

## What to Flag (Real Issues)
1. **Gaps** - plan says X but X not implemented or wrong
2. **Quality issues** - bugs, logic errors, broken integrations
3. **Problems** - regressions, inconsistencies, pattern violations
4. **TDD/plan fidelity** - skipped tests-first without justification
5. **Test-strength issues** - missing counterexamples, boundary checks
6. **Phase-gate issues** - stale verify commands, missing surface parity

## What NOT to Flag
- Style preferences
- Behavior-preserving cleanup/refactors
- Speculative enhancements
- Test coverage beyond plan requirements

## Verdict Format (Required)

At the VERY TOP of your response, output EXACTLY ONE:
- \`VERDICT: PASS_NO_ISSUES\`
- \`VERDICT: PASS_LOW_RISK_ONLY\`
- \`VERDICT: RE_REVIEW_REQUIRED\`
- \`VERDICT: BLOCKED\`

Rules:
- \`PASS_NO_ISSUES\` - no issues found, no changes made
- \`PASS_LOW_RISK_ONLY\` - only low-risk items remain (defer to discovery)
- \`RE_REVIEW_REQUIRED\` - you fixed substantive issues, need re-review
- \`BLOCKED\` - requires user decision, cannot resolve from codebase/plan

After verdict, include:
- Status: brief summary
- Fixed issues: (if RE_REVIEW_REQUIRED)
- Deferred items: (if PASS_LOW_RISK_ONLY)
- Blocking question: (if BLOCKED)`
  }
})
```

### 4) Execute Phase-by-Phase

For each unchecked phase in `## Progress`:

#### Iteration 1: Implement (Developer)

```javascript
subagent({
  agent: "ralph-developer",
  task: `Implement phase ${phase_number} of this plan: ${plan_path}

Discovery ledger: ${discovery_path}

Read the plan fully, find phase ${phase_number}, and implement per its ### Tests first, ### Work, and ### End State sections.`
})
```

#### Review Loop (Quality Reviewer)

```javascript
let verdict = null;
let review_count = 0;
const max_reviews = 10; // Safety limit

while (verdict !== 'PASS_NO_ISSUES' && verdict !== 'PASS_LOW_RISK_ONLY' && verdict !== 'BLOCKED') {
  review_count++;
  
  const result = await subagent({
    agent: "ralph-quality-reviewer",
    task: `Review phase ${phase_number} implementation of this plan: ${plan_path}

Discovery ledger: ${discovery_path}

Review for gaps, quality issues, problems, TDD fidelity, test-strength, and phase-gate issues.

This is review pass #${review_count}.` + (review_count > 1 ? `

Previous pass required RE_REVIEW_REQUIRED. Verify that previous fixes are correct and no new issues were introduced.` : '')
  });
  
  // Parse verdict from first line
  const first_line = result.split('\n')[0].trim();
  
  if (first_line.includes('PASS_NO_ISSUES')) {
    verdict = 'PASS_NO_ISSUES';
  } else if (first_line.includes('PASS_LOW_RISK_ONLY')) {
    verdict = 'PASS_LOW_RISK_ONLY';
    // Record deferred items to discovery_path and plan's Decisions Log
  } else if (first_line.includes('BLOCKED')) {
    verdict = 'BLOCKED';
    // Stop and ask user the blocking question
  } else {
    // RE_REVIEW_REQUIRED or malformed - loop again
    verdict = 'RE_REVIEW_REQUIRED';
  }
  
  if (review_count >= max_reviews) {
    throw new Error('Review loop exceeded maximum iterations - possible convergence issue');
  }
}
```

#### Phase Completion

Once quality gate passes:
1. Flip checkbox `- [ ]` → `- [x]` in `## Progress`
2. If any decisions/deferred discoveries, append to `## Decisions / Deviations Log`
3. Continue to next phase immediately

### 5) Final Completion

When all phases complete:
- Run any final verification commands
- Report completion with summary
- List any unresolved deferred discoveries

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `RALPH_DEV_MODEL` | `anthropic/claude-sonnet-4` | Model for developer agent |
| `RALPH_REVIEW_MODEL` | `anthropic/claude-sonnet-4` | Model for quality reviewer |

## Discovery Ledger Format

When deferred discoveries are recorded:

```markdown
# Discovery Ledger: [plan-slug]

- Source plan: [plan-path]
- Status: Open

## D-YYYYMMDD-P[N]-[index]
- Phase: P[N]
- Title: [short title]
- Type: cleanup | bug | refactor | perf | docs | follow-up feature
- Status: deferred
- Risk: low
- Evidence: [file/path or finding]
- Why not now: [explanation]
- Recommended follow-up: [next step]
```

## Low-Risk Deferral Criteria

A phase may advance with deferred items only if ALL are true:
- Doesn't leave acceptance criterion partially implemented
- Doesn't undermine correctness, data integrity, security, concurrency
- Isn't a broken/missing required-surface parity item
- Isn't stale/invalid verify guidance
- Can be safely deferred without changing truthfulness of phase tests

## Notes

- This skill delegates to subagents for implementation and review
- The main skill orchestrates the loop and manages the plan file
- Each review pass may make fixes directly (not just report issues)
- No fixed review limit - continues until quality gate passes or blocked
