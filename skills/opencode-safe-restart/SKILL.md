---
name: opencode-safe-restart
description: Safely restart long-lived OpenCode servers after command, agent, skill, or config updates without stranding active work. Use this whenever the user asks to restart OpenCode, reload OpenCode commands/skills/config, bounce the OpenCode web/server process, or coordinate restarts across mbp and dever. This skill launches a detached supervisor, inventories only sessions that are definitely active immediately before restart, restarts the configured services, then sends `continue` only to those captured sessions.
argument-hint: "[--dry-run] [--targets mbp,dever]"
---

# OpenCode Safe Restart

Restart OpenCode servers without performing the restart from the foreground session that is about to be interrupted.

## Core Behavior

Use the bundled supervisor script. It is intentionally conservative:

- It samples `/session/status` and recent root sessions twice immediately before restart.
- It resumes sessions whose status is `busy` or `retry` in both status samples.
- It also resumes unarchived root sessions that appear in both recent-session samples inside a tight recency window.
- It requires matching session metadata from `/experimental/session` or `/session`.
- It records the inventory before restarting anything.
- It restarts services only after the inventory is safely written.
- It sends `continue` only to sessions captured in that pre-restart inventory.

This does not preserve an in-flight tool call. It resumes by creating a new turn in the same persisted conversation, which is the expected OpenCode recovery model.

## Never Restart Inline

If you are operating through an active OpenCode server session, do not run `launchctl kickstart`, `systemctl restart`, or equivalent restart commands directly in the foreground tool call. That kills the transport carrying the current conversation.

Instead, launch the supervisor detached and let it own the restart:

```bash
~/.agents/skills/opencode-safe-restart/scripts/opencode-safe-restart.py --detach
```

The command prints the run directory and log path, then exits before the supervisor restarts anything.

## Common Usage

Preview without changing services or resuming sessions:

```bash
~/.agents/skills/opencode-safe-restart/scripts/opencode-safe-restart.py --dry-run
```

Restart both default hosts and resume only definitely-active sessions:

```bash
~/.agents/skills/opencode-safe-restart/scripts/opencode-safe-restart.py --detach --targets mbp,dever
```

The default recent-session window is 5 minutes. Tune it only when you intentionally want a wider or narrower definition of "in progress":

```bash
~/.agents/skills/opencode-safe-restart/scripts/opencode-safe-restart.py --detach --recent-minutes 10
```

Use a custom resume message:

```bash
~/.agents/skills/opencode-safe-restart/scripts/opencode-safe-restart.py --detach --resume-message continue
```

## Default Targets

The script has built-in defaults for the current fleet:

- `mbp`: OpenCode server on port `63333`, launchd service `com.anichols.opencode-web`, default directory `/Users/anichols/code`.
- `dever`: OpenCode server on port `63333`, user systemd service `opencode-web.service`, default directory `/home/anichols/code`.

If a target is local, the script uses the local service manager. If it is remote, the script uses `ssh <target> ...`.

For host-specific overrides, create `~/.config/opencode/safe-restart-targets.json`. Keep the same shape as this example:

```json
{
  "targets": {
    "mbp": {
      "url": "http://127.0.0.1:63333",
      "directory": "/Users/anichols/code",
      "restart": "launchctl kickstart -k gui/$(id -u)/com.anichols.opencode-web"
    },
    "dever": {
      "url": "http://dever:63333",
      "directory": "/home/anichols/code",
      "restart": "ssh dever 'systemctl --user restart opencode-web.service'"
    }
  }
}
```

## Output

Each run writes to `~/.cache/opencode-safe-restart/runs/<timestamp>/`:

- `supervisor.log`: full detached-run log when `--detach` is used.
- `inventory.json`: status samples, session metadata, selected resume candidates, and skipped sessions.
- `summary.json`: restart, health-check, and resume results.

Report the run directory to the user. If a server was restarted, remind them that currently running OpenCode clients may need to reconnect.

## Race Handling

OpenCode's `/session/status` endpoint reports live generation state, not every open conversation. A session can be actively in progress from the operator's perspective while status is empty between turns.

The script therefore uses two conservative signals:

- `busy` / `retry` in both `/session/status` samples for live generation.
- unarchived root session present in both recent-session samples within the recency window for open conversations that are between turns.

There is a tiny unavoidable race where a session can complete after the final sample but before the service restart. The script defends against practical races by requiring two consecutive samples and matching metadata. It deliberately prefers false negatives over broad historical resumes: if it is not sure a session was active, it does not resume it.
