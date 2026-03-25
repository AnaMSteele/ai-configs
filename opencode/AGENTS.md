# OpenCode Agent Configuration

This directory (`~/.config/opencode`) contains the local configuration, custom commands, and agent definitions for the OpenCode CLI.

## Synchronization & Source of Truth

**Source of Truth:** `~/code/ai-configs/opencode`

While this directory is where the active configuration lives and where you make edits, the persistent version control resides in `~/code/ai-configs`.

### Workflow
1. **Edit**: Make changes in `~/.config/opencode`.
2. **Sync**: Run `./scripts/sync_to_repo.sh` from `~/.config/opencode`.
3. **Commit**: Go to `~/code/ai-configs` to commit and push the synced changes.

## Important Context for Agents

**THIS IS NOT THE USER'S PROJECT.**

When you are acting as an agent and asked to debug or inspect a project:
1. **Do not** assume this directory is the project root.
2. This directory only contains **your own tools and instructions**.
3. Diagnostic checks run here (for example `git status` or `ls`) reveal the state of your configuration, not the user's application.

If you are debugging a command failure, check these files. If you are debugging the user's application code, look at the working directory specified in the prompt or ask for the correct path.