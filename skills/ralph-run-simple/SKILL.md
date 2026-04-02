---
name: ralph-run-simple
description: Execute a plan with a single implementation+review pass per phase. Simpler alternative to ralph-run when full quality gating isn't needed.
---

# Ralph Run (Simple)

Execute a plan with one implementation pass and one review pass per phase. No looping - assumes quality from the start.

## Usage

```
/skill:ralph-run-simple <slug | path/to/plan.md>
```

## Process

### 1) Resolve and Read Plan

```bash
# Resolve plan path
if [ -f "$ARGUMENTS" ]; then
  plan_path="$ARGUMENTS"
else
  plan_path="thoughts/plans/${ARGUMENTS}.md"
fi

# Read the plan
read "$plan_path"
```

### 2) Ensure Agents

Check/create the two required agents:

```javascript
// Check existing agents
const agents = await subagent({ action: "list" });

// Create if not exists
if (!agents.includes("ralph-developer")) {
  await subagent({
    action: "create",
    config: {
      name: "ralph-developer",
      description: "Plan implementation specialist",
      model: "anthropic/claude-sonnet-4",
      systemPrompt: `You implement plan phases with fidelity. Read the plan, find the specified phase, and implement exactly what is described in ### Tests first, ### Work, and ### End State. Ask only for truly unresolvable decisions. Run verify commands and report results.`
    }
  });
}
```

### 3) Execute Phases

For each unchecked phase:

**Implement:**
```javascript
await subagent({
  agent: "ralph-developer",
  task: `Implement phase N of ${plan_path}. Read plan fully, implement per ### Tests first, ### Work, ### End State. Run ### Verify commands.`
});
```

**Review (once):**
```javascript
await subagent({
  agent: "ralph-quality-reviewer",
  task: `Review phase N of ${plan_path}. Check for gaps, bugs, plan fidelity. Output verdict at top: VERDICT: PASS or VERDICT: ISSUES_FOUND with details.`
});
```

### 4) Mark Complete

Flip checkboxes in ## Progress for each completed phase.

## When to Use

- Small, well-understood plans
- When you want to review results yourself
- Faster execution (no review loop)
- Prototyping phases

## When NOT to Use

Use `/skill:ralph-run` instead when:
- Plan has strict quality requirements
- You need autonomous fixing of issues
- Multiple review passes are expected
- Production code with high stakes
