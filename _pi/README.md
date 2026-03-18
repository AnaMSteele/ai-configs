# Pi Skills

This directory contains pi-specific skills that provide equivalent functionality to the opencode command system.

## Installation

These skills are installed to `~/.pi/skills/` by the `install.sh` script:

```bash
./install.sh --pi      # Install Pi skills only
./install.sh --all     # Install everything including Pi skills
```

After installation, skills are auto-discovered by pi and available via `/skill:name`.

## Structure

```
_pi/
├── README.md           # This file
└── skills/             # Pi skills (Agent Skills format)
    ├── cmd-commit-push/
    │   └── SKILL.md
    ├── ralph-run/
    │   └── SKILL.md
    └── ...
```

After installation:
```
~/.pi/
├── README.md           # Documentation
└── skills/             # Installed skills
    ├── cmd-commit-push/
    ├── ralph-run/
    └── ...
```

## Skills Overview

### Ralph/Execution Skills

| Skill | Description | Opencode Equivalent |
|-------|-------------|---------------------|
| `ralph-run` | Full quality-gated execution with developer+reviewer loop | `/ralph:run` |
| `ralph-run-simple` | Single-pass version (1 dev + 1 review) | - |

### Git Utility Skills

| Skill | Description | Opencode Equivalent |
|-------|-------------|---------------------|
| `cmd-commit-push` | Commit all changes and push to remote | `/cmd:commit-push` |
| `cmd-create-pr` | Create GitHub pull request | `/cmd:create-pr` |
| `cmd-start-linear-issue` | Start Linear issue with worktree | `/cmd:start-linear-issue` |
| `cmd-start-linear-issue-branch` | Start Linear issue on branch only | `/cmd:start-linear-issue-branch` |

### Development Skills

| Skill | Description | Opencode Equivalent |
|-------|-------------|---------------------|
| `cmd-research` | Research codebase area | `/cmd:research` |
| `cmd-debug` | Debug investigation | `/cmd:debug` |
| `dev-plan` | Materialize execution plan | `/dev:plan` |
| `cmd-graduate` | Graduate completed work to spec/ | `/cmd:graduate` |

### Context Management Skills

| Skill | Description | Opencode Equivalent |
|-------|-------------|---------------------|
| `cmd-create-handoff` | Create handoff document | `/cmd:create_handoff` |
| `cmd-resume-handoff` | Resume from handoff | `/cmd:resume_handoff` |

### Review Skills

| Skill | Description | Opencode Equivalent |
|-------|-------------|---------------------|
| `review-change` | Review changes against plan | `/review:change` |
| `review-change-integrate` | Integrate review feedback | `/review:change-integrate` |

## Usage

After installation, invoke skills with `/skill:name`:

```bash
# Ralph execution
/skill:ralph-run user-profile-redesign
/skill:ralph-run-simple my-feature

# Git workflow
/skill:cmd-commit-push "feat: add new feature"
/skill:cmd-create-pr

# Linear integration
/skill:cmd-start-linear-issue-branch ENG-123

# Development
/skill:cmd-research "how does auth work"
/skill:dev-plan "feature-name"
/skill:cmd-debug "login failing"

# Context management
/skill:cmd-create-handoff "pausing for today"

# Reviews
/skill:review-change thoughts/plans/my-plan.md
```

## Ralph-Run Architecture

The `ralph-run` skill leverages the pi-subagents extension to implement quality-gated execution:

1. **Creates agents on-demand** using `subagent({ action: "create" })`:
   - `ralph-developer` - implements plan phases
   - `ralph-quality-reviewer` - reviews and fixes issues

2. **Orchestrates the quality loop**:
   - Developer implements phase
   - Reviewer reviews with verdict format
   - Loop continues until `PASS_NO_ISSUES`, `PASS_LOW_RISK_ONLY`, or `BLOCKED`

3. **Verdict-driven flow**:
   - `PASS_NO_ISSUES` → advance to next phase
   - `PASS_LOW_RISK_ONLY` → record deferred items, advance
   - `RE_REVIEW_REQUIRED` → run another review pass
   - `BLOCKED` → stop and ask user

4. **Discovery ledger** captures deferred work for later triage

## Agent Configuration

The ralph-run skill creates these agents on first use:

### ralph-developer
- **model**: `anthropic/claude-sonnet-4` (configurable via `RALPH_DEV_MODEL`)
- **purpose**: Implements plan phases with fidelity

### ralph-quality-reviewer  
- **model**: `anthropic/claude-sonnet-4` (configurable via `RALPH_REVIEW_MODEL`)
- **purpose**: Reviews implementations with strict verdict format

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `RALPH_DEV_MODEL` | `anthropic/claude-sonnet-4` | Model for developer agent |
| `RALPH_REVIEW_MODEL` | `anthropic/claude-sonnet-4` | Model for quality reviewer |

## Differences from Opencode

1. **Command syntax**: Pi uses `/skill:name` instead of `/cmd:name`
2. **Structure**: Pi skills are directories with SKILL.md files (Agent Skills spec)
3. **Auto-discovery**: Pi discovers skills from `~/.pi/skills/` automatically
4. **No plugins**: Pi doesn't use the opencode plugin system
5. **Subagent-based**: Ralph pattern uses pi's subagent tool for delegation

## Adding New Skills

To add a new skill:

1. Create a directory: `mkdir _pi/skills/my-skill`
2. Create SKILL.md: `touch _pi/skills/my-skill/SKILL.md`
3. Add frontmatter:
   ```yaml
   ---
   name: my-skill
   description: What this skill does and when to use it
   ---
   ```
4. Write the skill instructions below the frontmatter
5. Re-run `./install.sh --pi` to install

See the [Agent Skills specification](https://agentskills.io/specification) for details.

## Integration with Other Tools

The pi skills work alongside:
- OpenCode commands in `~/.config/opencode/`
- Claude skills in `~/.claude/skills/`
- Project-level skills in `.pi/skills/` (if configured)
