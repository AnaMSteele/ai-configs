---
description: Run a QA test plan via browser
argument-hint: <plan-slug-or-path>
---

# /qa:run

Run a browser-based QA test plan. Resolves a plan file, logs into the app, and executes each test item via Playwright browser tools.

## Autopilot

- Execute **continuously**. Do not pause for confirmation between test items.
- Every response must take **concrete action**: navigate, click, type, screenshot, or record a finding.
- Do NOT narrate what you're "about to do" — just do it.
- Do NOT ask for permission to proceed to the next test item.
- If you encounter an error that doesn't block the current test item, note it and continue.
- If you encounter an error that blocks ALL remaining items (e.g., can't login, server down), stop with an explanation.

## Resolve Plan

Resolve `$ARGUMENTS` to a plan file path:

| Input | Resolution |
|-------|------------|
| bare slug (e.g. `comments-and-docs`) | `thoughts/qa/<slug>.md` |
| path ending in `.md` | Use as-is (relative to repo root) |
| `@`-prefixed (e.g. `@thoughts/qa/foo.md`) | Strip `@`, resolve relative to workspace root |

Read the plan file. It must contain these sections:

- **`## Context`** — path to context file (login instructions, test accounts, app layout)
- **`## Findings`** — path to findings file (append results here)
- **`## Screenshots`** — path to screenshots directory
- **`## Progress`** — checkbox list of test items (`- [ ]` unchecked, `- [x]` checked)
- **`## Items`** — detailed description for each numbered test item

## Startup

1. **Read context file** from the plan's `## Context` section. This contains login instructions, test accounts, severity levels, and app layout.
2. **Discover port**: Run `ss -tlnp | grep next-server`. Extract the port number from the output (e.g., `0.0.0.0:3052` means port `3052`).
   - If nothing found → dev server is not running. **Stop** with message: _"Dev server not running. Start it with `pnpm dev` and re-run."_
   - If multiple ports appear → use the one with the highest PID (most recent).
   - **NEVER start the dev server yourself** — it orphans background processes.
   - Do NOT hardcode any port. Do NOT assume port 3000.
3. **Login**: Navigate to `http://localhost:{port}`.
   - If you see a dashboard (sidebar with workspace content), you are already logged in. Proceed.
   - If you see `/sign-in` or a login form, follow the **two-step Clerk login** procedure from the context file. This is critical — the password field is hidden until the email step completes.
   - Take a snapshot after login to confirm you reached the dashboard.
4. **Read findings file** from the plan's `## Findings` section. Note which items have already been tested in previous runs.

## Test Loop

For each unchecked `- [ ]` item in `## Progress` (in order):

1. **Read** the matching entry under `## Items` for the detailed test description.
2. **Execute** the test via browser — navigate, interact, observe results.
3. **Screenshot**: Take a PNG screenshot as evidence.
   - Use `playwright_browser_take_screenshot` with `type: "png"`.
   - Save to the screenshots directory from `## Screenshots`.
   - Naming convention: `{number:02d}-{short-name}.png` (e.g., `01-create-comment.png`).
4. **Record findings**: Append to the findings file (from `## Findings`) using this format:

   ```markdown
   ## {number}. {item name}
   - **Status**: PASS | FAIL | SKIP | BLOCKED
   - **Severity**: critical | high | medium | low (for FAIL only)
   - **Steps**: What you did
   - **Expected**: What should happen
   - **Actual**: What actually happened
   - **Screenshot**: {filename}
   - **Notes**: Any additional observations
   ```

5. **Update progress**: Edit the plan file — flip `- [ ]` to `- [x]` for the completed item.
6. **Continue** to the next unchecked item. Do NOT pause or ask for confirmation.

## Rules

- **No source code reading.** You are testing the UI, not the code. Do not open, read, or grep application source files to understand features. If a feature isn't visible after reasonable UI exploration, mark it SKIP.
- **Real PNG screenshots only.** Always use `playwright_browser_take_screenshot` with `type: "png"`. Never use `playwright_browser_snapshot` as a substitute for evidence screenshots.
- **Snapshots for interaction.** Use `playwright_browser_snapshot` (accessibility tree) to understand page structure before clicking/typing. Use screenshots for evidence after.
- **Never start the dev server.** If it's not running, stop and say so.
- **Never re-test checked items.** If an item is already `- [x]` in Progress, skip it.
- **Be thorough.** Click things. Try edge cases. Verify state changes. A passing test needs evidence.
- **CAPTCHA blocks everything.** If a CAPTCHA appears during login, mark the current item BLOCKED with reason "CAPTCHA challenge" and stop the run.
- **Clean up after yourself.** If you create test documents or comments, try to delete them when you're done with that test item (unless a later item depends on them).

## Completion

When all items in `## Progress` are `- [x]`:

1. Read the findings file.
2. Output a summary table: count of PASS / FAIL / SKIP / BLOCKED.
3. List any FAIL items with their severity and one-line description.
4. Note any SKIP items and why they were skipped.
