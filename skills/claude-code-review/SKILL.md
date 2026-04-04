---
name: claude-code-review
description: Launch Claude Code via pi interactive_shell for background plan/code reviews. Use when the task is to have Claude Code review a plan or code diff without editing files.
---

# Claude Code Review

Use this skill when you want Claude Code to review work in the background and report back reliably on the first try.

## What worked in local testing

### Reliable default
Use `interactive_shell` with:
- `mode: "dispatch"`
- `background: true`
- `claude --permission-mode plan "...review prompt..."`
- a prompt that asks Claude Code to **return the review in chat**, not save it to a file

This worked for a real plan review and produced a usable structured review without extra permission prompts.

### Less reliable paths
Avoid these as the first attempt:
- asking Claude Code in `plan` mode to write review output to `/tmp` or repo files
- starting `hands-free`, then backgrounding it, then trying to steer it later
- using write-to-`/tmp` as the normal artifact path for read-only reviews

In testing, the write-to-file flow stalled on Claude Code permission prompts after `Write(...)` failed and it fell back to `Bash(touch /tmp/...)`.

## Default launch patterns

### 1) One-shot plan review
```typescript
interactive_shell({
  command: 'claude --permission-mode plan "Review thoughts/plans/foo.md against thoughts/plans/AGENTS.md and thoughts/specs/product_intent.md. This is a read-only plan review. Do not edit files. Return a concise review in chat with sections: Verdict, Strengths, Issues, Required Changes."',
  mode: "dispatch",
  background: true,
  name: "claude-plan-review",
  reason: "Claude Code plan review",
  handoffPreview: { enabled: true, lines: 120, maxChars: 20000 },
})
```

### 2) One-shot code review
```typescript
interactive_shell({
  command: 'claude --permission-mode plan "Review path/to/file.ts and path/to/test.ts for correctness, edge cases, and test gaps. This is a read-only code review. Do not edit files. Return the review in chat with sections: Summary, Findings, Suggested Follow-ups."',
  mode: "dispatch",
  background: true,
  name: "claude-code-review",
  reason: "Claude Code code review",
  handoffPreview: { enabled: true, lines: 120, maxChars: 20000 },
})
```

## Prompt rules

Prefer prompts that:
- explicitly say **read-only**
- explicitly say **do not edit files**
- ask for a **compact structured review in chat**
- name the exact files/docs to review
- name the rubric or comparison docs

Good plan review structure:
- `Verdict`
- `Strengths`
- `Issues`
- `Required Changes`

Good code review structure:
- `Summary`
- `Findings`
- `Suggested Follow-ups`

## When to use hands-free instead

Use `hands-free` only if you expect real follow-up interaction while Claude Code stays live.

```typescript
interactive_shell({
  command: 'claude --permission-mode plan "Read AGENTS.md and summarize reviewer guardrails in 3 bullets, then wait for more instructions."',
  mode: "hands-free",
  name: "claude-review-live",
  reason: "Interactive Claude Code review session",
  handsFree: {
    updateMode: "on-quiet",
    quietThreshold: 4000,
    updateInterval: 60000,
    autoExitOnQuiet: false,
  },
})
```

But do **not** default to this for one-pass reviews. In testing, `dispatch` was more dependable.

## If you need a saved artifact

Best path:
1. ask Claude Code to return the review in chat
2. capture the review from the dispatch output
3. save it yourself with pi’s `write` tool

Do not make Claude Code file-writing the default for review tasks.

## If the run gets stuck

Typical failure pattern in testing:
- Claude Code attempts `Write(...)`
- write fails
- Claude falls back to `Bash(touch /tmp/file)`
- session blocks on an approval prompt

Recovery:
1. inspect the session output via `attach` or the dispatch handoff
2. if the session is waiting on permissions, stop it
3. relaunch with a simpler read-only prompt that returns the review in chat
4. save the result yourself if needed

A non-zero exit does not automatically mean failure. In testing, a plan review produced a complete structured review in the transcript and still ended with exit code `143` after teardown. Judge success by whether the review content was fully produced.

## Notes from testing

Observed:
- `dispatch + background + --permission-mode plan + direct-in-chat output` succeeded for plan review
- `plan mode + write to /tmp` did not succeed reliably
- `acceptEdits` and extra `/tmp` access were not proven reliable enough to recommend as the default review workflow

## Recommendation

For “have Claude Code review this in the background,” the first try should be:
- `interactive_shell`
- `mode: "dispatch"`
- `background: true`
- `claude --permission-mode plan ...`
- return review in chat
- save artifacts with pi, not Claude Code
