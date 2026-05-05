---
name: codex-computer-use
description: Drive local macOS desktop apps from OpenCode by delegating to Codex's bundled computer-use MCP plugin. Use this whenever the user asks OpenCode to operate the host computer UI, inspect or change desktop app settings, click through a native app, use Finder/System Settings/menu bar UI, take a UI inventory, or otherwise perform general computer use that OpenCode tools cannot directly do. This skill is a Codex proxy pattern: verify Codex computer-use is enabled, run `codex exec` with a tightly scoped desktop task, and report the result without exposing secrets.
license: Complete terms in LICENSE.txt
---

# Codex Computer Use

Use Codex as a proxy when OpenCode needs general macOS computer use. OpenCode does not expose Codex's computer-use MCP tools directly, but a subprocess launched with `codex exec` can access the configured `computer-use` MCP server and drive the local desktop.

This skill is for desktop UI work: launching apps, opening menus, inspecting settings/preferences, clicking buttons, reading visible UI state, and performing explicitly requested UI operations. It is not for browser-only testing when OpenCode already has browser/Playwright tools, and it is not for code edits.

## What Is Available

On the host where this skill was created, Codex exposes:

- Feature flag: `computer_use` enabled via `codex features list`.
- Plugin config: `[plugins."computer-use@openai-bundled"] enabled = true` in `~/.codex/config.toml`.
- MCP server: `computer-use` in `codex mcp list`, backed by the bundled `Codex Computer Use.app` client.
- Observed callable tools through `codex exec`: app listing/state inspection and click-based desktop interaction. Let Codex discover the exact current tool set inside its own run; do not assume OpenCode can call those tools directly.

## When To Use

Use this skill when the user asks to:

- Drive a local desktop app or native macOS app.
- Inspect Preferences, Settings, menus, dialogs, sidebars, windows, or visible app state.
- Operate Finder, System Settings, menu bar extras, or another non-browser GUI.
- Validate that a local app launches and presents expected UI.
- Gather a UI inventory without changing files.

Do not use this skill when:

- A direct OpenCode tool is better, such as file reads, shell commands, code search, or browser automation.
- The task requires entering or revealing secrets unless the user explicitly asks and the operation is safe.
- The user asks for unattended destructive UI actions such as deleting data, resetting state, purchasing, sending messages, or changing security/privacy settings. Ask for confirmation first.

## Preflight

Run these checks before delegating substantial desktop work:

```bash
codex mcp list
codex features list
```

Confirm:

- `computer-use` is present and `enabled` in `codex mcp list`.
- `computer_use` is `true` in `codex features list`.

If either check fails, report that Codex computer use is not currently available and include the exact missing condition. Do not pretend OpenCode can drive the desktop directly.

## Proxy Command

Use `codex exec` from the relevant project directory. Prefer `danger-full-access` for desktop control because GUI automation usually needs to escape a workspace-only sandbox. Keep the prompt scoped and instruct Codex not to edit files unless the user explicitly asked for edits.

Template:

```bash
codex exec --sandbox danger-full-access --cd "/path/to/project" "Use the configured computer-use MCP if available. Drive the local macOS desktop UI to: <task>. Do not edit files or change settings unless explicitly required. Do not reveal secrets, API keys, tokens, passwords, or full private local paths. If a secret or private path is visible, summarize its presence without copying the value. Report: apps/windows opened, actions taken, visible UI findings, any settings changed, and blockers. If you cannot access computer-use tools, say exactly what tool access is missing and stop after reporting the blocker."
```

Notes:

- This installed `codex exec` may not accept top-level-only flags such as `--ask-for-approval`; use `codex exec --help` if a flag fails.
- The user's Codex config may already set `approval_policy = "never"` and `sandbox_mode = "danger-full-access"`, but pass `--sandbox danger-full-access` anyway for clarity on desktop tasks.
- Use `--cd` instead of shell `cd` so Codex gets the intended working root.
- If the task is purely observational, say "Do not change settings" explicitly.
- If changes are required, ask Codex to list each intended change before performing it when the change is sensitive, destructive, or hard to undo.

## Prompting Codex Well

Give Codex a UI objective, not low-level click coordinates. Ask it to use accessibility/state inspection where available before clicking. Good prompts include:

- The app name or bundle path, if known.
- The exact surface to inspect, such as Preferences, Settings, account panel, or menu bar extra.
- Whether it may launch the app.
- Whether it may modify controls.
- What to redact from the report.
- The output structure you need back.

Example observational prompt:

```text
Use the configured computer-use MCP if available. Open /Applications/Heddle.app, open Settings or Preferences, inspect each visible sidebar section, and report the preference sections and visible setting groups. Do not change settings. Do not reveal API keys, tokens, passwords, account identifiers, or full local source paths; only report that such fields are present. If you cannot access computer-use tools, say exactly what tool access is missing and stop.
```

Example action prompt:

```text
Use the configured computer-use MCP if available. Open System Settings and check whether <setting> is enabled. If it is disabled, stop and report that state; do not change it unless I explicitly confirm. Do not reveal unrelated account information.
```

## Safety Rules

Desktop automation sees the user's real machine. Treat visible UI as sensitive.

- Do not disclose secrets, API keys, passwords, token values, private account identifiers, or full private filesystem paths.
- Do not change settings, delete data, send messages, make purchases, grant permissions, reset state, or submit forms unless the user explicitly requested that exact action.
- Prefer observation over mutation. For ambiguous tasks, ask one short clarification before invoking Codex.
- If Codex reports a permission prompt, login screen, or sensitive dialog, stop and ask the user how to proceed.
- If Codex output includes sensitive values, summarize the capability without repeating the value.

## Failure Handling

If Codex fails before using computer-use:

- Run `codex exec --help` and retry with supported flags only.
- Re-check `codex mcp list` and `codex features list`.
- If the MCP server is disabled, tell the user it must be enabled in Codex before OpenCode can proxy desktop control.
- If Codex can run but cannot control the UI, report the exact blocker, such as missing Accessibility/Screen Recording permissions, missing app bundle, or a plugin transport/auth error.

Do not fall back to brittle coordinate-only AppleScript unless the user explicitly accepts that approach. The point of this skill is to use Codex's computer-use MCP as the higher-level desktop operator.

## Report Back

After the `codex exec` run, summarize in OpenCode using this shape:

- Capability: whether Codex computer-use was available.
- Target: app/window/surface inspected or operated.
- Actions: concise list of UI actions taken.
- Findings: visible sections/settings/state, redacted where needed.
- Changes: either "none" or the exact settings changed.
- Blockers/residual risk: permission gaps, UI uncertainty, or manual checks needed.

Keep the report factual. Do not include Codex's full raw transcript unless the user asks for it.
