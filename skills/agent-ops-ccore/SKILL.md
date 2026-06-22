---
name: agent-ops-ccore
description: Use Ana's Agent Ops ccore space as shared agent guidance, runbook, and skill-reference context. Trigger when an agent needs cross-agent operating guidance, local runbooks, reusable skill notes, or instructions that should be shared across Claude, Codex, Pi, Hermes, OpenCode, and related agents.
---

# Ana Agent Ops Ccore

Use this skill when you need reusable cross-agent guidance from Ana's local ccore space.

## Implemented Access Path

The implemented access path on this machine is the local `ccore` CLI, not MCP.

```bash
ccore health
ccore space list
```

Target space:

```text
Display name: Ana Agent Ops
Space ID: 6444a494-a7c4-49c2-9ce0-2c6f25764087
Default node: http://127.0.0.1:8787
```

The installed `ccore` binary currently does not expose `ccore mcp`. Do not claim MCP access is available unless `ccore --help` shows it in the live environment.

## Authority And Precedence

Use Ana Agent Ops as shared baseline context only.

Precedence:

1. Current user instruction.
2. Repo-local `AGENTS.md`, `CLAUDE.md`, and product/data-safety docs.
3. Ana Agent Ops ccore shared guidance.
4. General shared skills and model defaults.

If ccore guidance conflicts with repo-local rules, follow the repo-local rule and mention the conflict.

## Read Workflow

Start with health and space discovery:

```bash
ccore health
ccore space list
```

Then query or inspect the Agent Ops space:

```bash
ccore query 6444a494-a7c4-49c2-9ce0-2c6f25764087 "reviewed HTML plan workflow"
ccore doc list 6444a494-a7c4-49c2-9ce0-2c6f25764087
ccore doc show <document-id>
```

Use UUIDs when names are ambiguous. Prefer the smallest read that answers the question.

## Write Policy

Default to read-only.

Agents may write new Agent Ops runbooks, skill notes, or operating guidance only when Ana explicitly asks for ccore writeback or when the active task specifically includes creating/updating ccore guidance.

When writing is allowed:

1. Read existing related guidance first to avoid duplicates.
2. Create or update the smallest focused document.
3. Verify the result with `ccore doc show`.
4. Report document IDs and changed guidance in the final answer.

Example create command:

```bash
ccore doc new 6444a494-a7c4-49c2-9ce0-2c6f25764087 "Runbook Title" "<markdown content>" --kind note --content-type text/markdown
```

## Safety Boundaries

Do not perform sync, hub, credential, invite, delete, archive, restore, or direct SQLite operations unless Ana explicitly asks for that operation.

Account discovery may report degraded or stale catalog state even when local reads work. Treat that as a reason to avoid sync/hub operations, not as a reason to bypass safeguards.

Do not put production secrets, credentials, private tokens, or product data dumps into Agent Ops guidance.

## What Belongs In Ana Agent Ops

- Cross-repo agent operating procedures.
- Local tool runbooks.
- Reusable skill notes.
- Reviewed-plan workflow guidance.
- Recovery notes for local agent tooling.
- Shared conventions that apply across `heddle`, `doct`, `ai-configs`, and related repos.

What does not belong there:

- Repo-specific constraints that should live in that repo's `AGENTS.md` or `CLAUDE.md`.
- Production data or secrets.
- One-off task state better kept in `thoughts/`, Linear, or a current handoff.
