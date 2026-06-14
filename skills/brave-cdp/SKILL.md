---
name: brave-cdp
description: Interact with Aaron's existing Brave browser session through a shared CDP CLI installed under `~/.agents/skills`. Use when asked to inspect, debug, or interact with a page that is already open in Brave. Falls back to Chrome, Chromium, Edge, or Vivaldi if Brave is unavailable. This is a local shared skill with `scripts/cdp.mjs`, not an MCP server.
---

# Brave CDP

Use this shared skill to drive Aaron's existing Brave session over the Chrome DevTools Protocol.

Primary entrypoint:

```bash
~/.agents/skills/brave-cdp/scripts/cdp.mjs list
```

To launch a dedicated automation profile without the recurring approval prompt on the default profile:

```bash
~/.agents/skills/brave-cdp/scripts/start-brave-cdp.sh
```

Optional URL:

```bash
~/.agents/skills/brave-cdp/scripts/start-brave-cdp.sh https://chatgpt.com
```

## Prerequisites

- Brave with remote debugging enabled. This skill prefers Brave first.
- Node.js 22+.
- If Brave stores `DevToolsActivePort` in a non-standard location, set `CDP_PORT_FILE` to the full path.

Fallback browsers remain supported when Brave is unavailable: Chrome, Chromium, Edge, and Vivaldi where their standard `DevToolsActivePort` paths exist.

## Detection order

The script checks candidates in this order:

1. `CDP_PORT_FILE` override if provided
2. Standard Brave `DevToolsActivePort` paths on macOS, Linux, Linux Flatpak, and Windows
3. Other Chromium-family browsers in the upstream fallback set

If both Brave and Chrome expose `DevToolsActivePort`, the Brave path wins.

## Commands

All commands use `~/.agents/skills/brave-cdp/scripts/cdp.mjs`. `<target>` is a unique `targetId` prefix copied from `list`.

```bash
~/.agents/skills/brave-cdp/scripts/cdp.mjs list
~/.agents/skills/brave-cdp/scripts/cdp.mjs shot <target> [file]
~/.agents/skills/brave-cdp/scripts/cdp.mjs snap <target>
~/.agents/skills/brave-cdp/scripts/cdp.mjs eval <target> <expr>
~/.agents/skills/brave-cdp/scripts/cdp.mjs html <target> [selector]
~/.agents/skills/brave-cdp/scripts/cdp.mjs nav <target> <url>
~/.agents/skills/brave-cdp/scripts/cdp.mjs net <target>
~/.agents/skills/brave-cdp/scripts/cdp.mjs click <target> <selector>
~/.agents/skills/brave-cdp/scripts/cdp.mjs clickxy <target> <x> <y>
~/.agents/skills/brave-cdp/scripts/cdp.mjs type <target> <text>
~/.agents/skills/brave-cdp/scripts/cdp.mjs loadall <target> <selector> [ms]
~/.agents/skills/brave-cdp/scripts/cdp.mjs evalraw <target> <method> [json]
~/.agents/skills/brave-cdp/scripts/cdp.mjs open [url]
~/.agents/skills/brave-cdp/scripts/cdp.mjs stop [target]
```

The command surface intentionally matches the upstream `chrome-cdp` skill so existing examples remain useful.

## Operating notes

- `list` refreshes the local target cache used by follow-up commands.
- The first attach for a tab may require clicking Brave's debugging approval prompt.
- A background daemon keeps the session alive per tab for 20 minutes of inactivity.
- Prefer `snap` for structure and `shot` when you need pixels.
- Use `type` after focusing an element when working inside cross-origin iframes.

## Files

- `scripts/cdp.mjs` — Brave-first CDP CLI adapted from upstream `pasky/chrome-cdp-skill`
