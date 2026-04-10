# pi-vcc (vendored for OMP)

Vendored into `ai-configs` from `sting8k/pi-vcc` so this repo can ship the same pinned VCC behavior for OMP that it already ships for Pi.

- Source: `https://github.com/sting8k/pi-vcc`
- Upstream version: `0.3.0`
- Upstream commit snapshot: `8487c9d55e119aa3de270cdf552b6b88eb374b39`
- License: MIT
- Local changes:
  - `/pi-vcc` carries the `__PI_VCC_MANUAL_BYPASS__` marker directly in-source
  - the compaction hook falls back to keeping a recent non-user tail when there is no later user-message boundary
  - debug config for this OMP copy lives at `~/.omp/agent/pi-vcc-config.json`

Install from this repo:

```bash
./install.sh --omp
```

Algorithmic conversation compactor for OMP. No LLM calls — it produces a brief transcript via extraction and formatting.

Inspired by [VCC](https://github.com/lllyasviel/VCC) (View-oriented Conversation Compiler).

## What this OMP copy provides

- `session_before_compact` hook for algorithmic compaction
- `/pi-vcc` for manual compaction on demand
- `vcc_recall` for searching full session history, including compacted parts

## Usage

After `./install.sh --omp`, OMP loads the extension from `~/.omp/agent/extensions/pi-vcc`.

- When OMP triggers a compaction, pi-vcc supplies the summary.
- To trigger compaction manually, run `/pi-vcc`.
- To search older history after compaction, use `vcc_recall`.

## Recall

`vcc_recall` reads the raw session JSONL for the current session so older history remains searchable even after compaction.

Examples:

```text
vcc_recall({ query: "auth token" })
vcc_recall({ query: "hook|inject" })
vcc_recall({ query: "fail.*build" })
vcc_recall({ expand: [41, 42] })
```

## Debug

Debug logging is off by default. Enable it in `~/.omp/agent/pi-vcc-config.json`:

```json
{ "debug": true }
```

When enabled, each compaction writes detailed info to `/tmp/pi-vcc-debug.json`.

## Related work

- [VCC](https://github.com/lllyasviel/VCC)
- [Pi](https://github.com/badlogic/pi-mono)
- OMP loads the same `@mariozechner/pi-coding-agent` extension surface used by this vendored port
