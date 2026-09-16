---
name: agent-ops-ava
description: Use Ana's Avalandra Agent Ops space as the first-read source for shared agent guidance, runbooks, and reusable skill context. Trigger at the start of every session and whenever cross-agent operating guidance is needed.
---

# Ana Agent Ops in Avalandra

Use this skill at the start of every new session, before beginning task work, and whenever reusable cross-agent guidance may affect the task.

## Canonical Space

```text
Display name: Agent Ops
Handle: agent-ops
Organization: Nodaste
Organization ID: org_bc5d7f1e389c48ccb6746b414750a513
Space ID: spc_ee8732550dd8455e9c16de1bec636975
URL: https://nodaste.hub.avalandra.com/spaces/agent-ops
```

Avalandra is the canonical live source. The former Heddle `Ana Agent Ops` space is a legacy, read-only fallback for migration audits, provenance, or material that has not yet been ported.

## Session-Start Read Workflow

Start with gateway and identity checks:

```bash
ava health
ava auth status --json
```

Then run the smallest task-specific search, scoped to Agent Ops:

```bash
ava query run --data '{
  "scope": {
    "organization_id": "org_bc5d7f1e389c48ccb6746b414750a513",
    "space_ids": ["spc_ee8732550dd8455e9c16de1bec636975"]
  },
  "from": {"resource_kinds": ["entity"]},
  "text": {
    "query": "<current task or workflow>",
    "fields": ["/title", "/body"],
    "mode": "terms"
  },
  "page": {"limit": 20}
}' --json
```

If search does not surface enough context, inspect the document tree and read the smallest relevant document:

```bash
ava --organization org_bc5d7f1e389c48ccb6746b414750a513 \
  --space spc_ee8732550dd8455e9c16de1bec636975 \
  document tree --json

ava --organization org_bc5d7f1e389c48ccb6746b414750a513 \
  --space spc_ee8732550dd8455e9c16de1bec636975 \
  document get <document-id> --json
```

Use `ava onboard` or `~/.ava/SKILL.md` for the current Avalandra command contract. Do not assume a running host's static skill registry has refreshed after `ava onboard --skill`.

## Authority And Precedence

Use Agent Ops as shared baseline context only.

1. Current user instruction.
2. Repository-local `AGENTS.md`, `CLAUDE.md`, and product/data-safety documentation.
3. Ava Agent Ops shared guidance.
4. General shared skills and model defaults.

If Agent Ops conflicts with repository-local rules, follow the repository-local rule and surface the conflict.

## Write Policy

Default to read-only. Write Agent Ops guidance only when Ana explicitly asks or when the active task specifically includes creating or updating shared guidance.

When writing is allowed:

1. Search and read related live guidance first.
2. Create or revise the smallest focused document.
3. Remember that text document creation and body replacement are separate commits.
4. Verify the saved body with `ava document get`.
5. Report the document ID and changed guidance.

Use idempotency keys for mutations and reuse the same key and content when retrying.

## Legacy Heddle Fallback

Use Heddle only when Avalandra is unavailable or the task specifically requires legacy history, superseded revisions, or migration provenance.

```text
Legacy display name: Ana Agent Ops
Legacy space ID: 6444a494-a7c4-49c2-9ce0-2c6f25764087
Legacy access: ccore CLI at the default local node
```

Keep fallback reads narrow and read-only. Do not silently treat Heddle as the current authority.

## Safety Boundaries

Do not perform credential, invite, membership, delete, archive, restore, transfer, sync, or direct-database operations unless Ana explicitly asks for that operation.

If Avalandra is unavailable, say so briefly and continue from current user and repository-local guidance. Do not bypass safeguards to reconstruct Agent Ops from private databases or backups.

Do not put production secrets, credentials, private tokens, or product data dumps into Agent Ops guidance.

## What Belongs In Agent Ops

- Cross-repository agent operating procedures.
- Local tool runbooks.
- Reusable skill notes.
- Reviewed-plan workflow guidance.
- Recovery notes for local agent tooling.
- Shared conventions that apply across related repositories and agent hosts.

Keep repository-specific constraints in that repository's `AGENTS.md` or `CLAUDE.md`, and keep one-off task state in the task's normal tracking artifact.
