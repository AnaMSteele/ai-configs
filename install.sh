#!/bin/bash

# Installation script for Claude Code, Codex, Gemini, Oh My Pi, and optional OpenCode

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"
TARGET_DIR="."
INSTALL_MODE="--default"
APPEND_AGENTS=false
INSTALL_TOOLS=false
INSTALL_SKILLS=false
AI_CONFIGS_MANAGED_MARKER='.ai-configs-managed.json'
AI_CONFIGS_BACKUP_RUN_ID="$(date +"%Y%m%d-%H%M%S")"
AI_CONFIGS_REPO_NAME='ai-configs'
AI_CONFIGS_REPO_COMMIT="$(git -C "$REPO_ROOT" rev-parse HEAD 2>/dev/null || echo unknown)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

print_usage() {
    echo "Usage: $0 [--claude|--codex|--gemini|--omp|--opencode|--pi|--tools|--skills|--all] [--append-agents] [target-directory]"
    echo ""
    echo "Options:"
    echo "  --claude    Install Claude Code configuration and refresh shared skills for Claude"
    echo "  --codex     Install Codex configuration only"
    echo "  --gemini    Install Gemini CLI configuration only"
    echo "  --opencode  Install OpenCode configuration and refresh shared skills for OpenCode"
    echo "  --pi        Install Pi prompt templates, subagents, and extensions, then refresh shared skills"
    echo "  --omp       Install Oh My Pi configuration and refresh shared skills"
    echo "  --tools     Install CLI tools only (e.g., ltui)"
    echo "  --skills    Sync repo-owned and package-managed shared skills into ~/.agents/skills"
    echo "  --all       Install everything: Claude, Codex, Gemini, Oh My Pi, OpenCode, Pi, tools, and shared skills"
    echo "  --append-agents"
    echo "             Ensure GEMINI.md exists and contains required Personas."
    echo "             If GEMINI.md exists but is missing the Personas section, append it from the template."
    echo ""
    echo "Default behavior (no args):"
    echo "  Installs Claude, Codex, Gemini, Oh My Pi, OpenCode, Pi, and shared skills (no tools)."
    echo ""
    echo "Notes:"
    echo "  - OpenCode does NOT auto-install opencode.json (copy config-template.json manually if needed)"
    echo "  - Shared installable skills are declared in skills/install-matrix.json and synced into ~/.agents/skills"
    echo "  - Claude/OpenCode consume compatible shared skills via per-skill links into ~/.agents/skills"
    echo "  - When using --omp or --all, commands, agents, and repo-managed extensions are installed to ~/.omp/agent"
    echo "  - When using --opencode or --all, commands, prompts, and agents are installed to ~/.config/opencode"
    echo "  - When using --pi or --all, Pi prompt templates, subagents, and repo-managed extensions are copied to ~/.pi/agent"
    echo "  - Repo-managed Pi extensions live under ~/.pi/agent/extensions and do NOT appear in 'pi list'"
    echo "  - When using --pi or --all, also installs pi extensions via git: pi-dcp, chrome-cdp-skill, pi-rlm"
    echo "  - Package-managed Pi installs DO appear in 'pi list': @tintinweb/pi-subagents, @aliou/pi-processes, pi-web-access, pi-mcp-adapter, lsp-pi, @fnnm/pi-ast-grep, pi-updater, pi-interactive-shell, pi-powerline-footer, @marckrenn/pi-sub-bar, pi-side-agents, pi-multi-pass, pi-no-soft-cursor, @tmustier/pi-files-widget, @tmustier/pi-raw-paste, @sting8k/pi-vcc"
    echo "  - In non-interactive mode, existing configs are preserved automatically"
    echo ""
    echo "Examples:"
    echo "  $0                               # Default: install Claude + Codex + Gemini + OMP + OpenCode + Pi + shared skills"
    echo "  $0 --claude                      # Install Claude to current directory"
    echo "  $0 --codex ~/my-project          # Install Codex to ~/my-project"
    echo "  $0 --gemini ~/my-project         # Install Gemini to ~/my-project"
    echo "  $0 --opencode ~/my-project       # Install OpenCode to ~/my-project"
    echo "  $0 --pi                          # Install Pi prompt templates, subagents, extensions, and refresh shared skills"
    echo "  $0 --omp ~/my-project            # Install Oh My Pi config to ~/.omp/agent"
    echo "  $0 --tools                       # Install CLI tools globally"
    echo "  $0 --skills                      # Sync repo-owned and package-managed shared skills into ~/.agents/skills"
    echo "  $0 --all --append-agents         # Install everything and ensure GEMINI.md Personas"
}

ensure_codex_cli_flags() {
    local target_dir="$1"
    local config_path="$target_dir/config.toml"

    if [ ! -f "$config_path" ]; then
        return
    fi

    local status
    status=$(CONFIG_PATH="$config_path" python3 <<'PY'
import ast
import os
import re
from pathlib import Path

config_file = Path(os.environ["CONFIG_PATH"])
text = config_file.read_text()
required_flags = [
    "--dangerously-bypass-approvals-and-sandbox",
    "--enable-web-search",
]

pattern = re.compile(r"default_cli_flags\s*=\s*\[(.*?)\]", re.DOTALL)
match = pattern.search(text)
changed = False


def format_block(flags):
    inner = ",\n".join(f'  "{flag}"' for flag in flags)
    return f"default_cli_flags = [\n{inner}\n]"


if match:
    content = match.group(1)
    try:
        existing = ast.literal_eval("[" + content + "]")
    except Exception:
        existing = []

    updated = existing[:]
    for flag in required_flags:
        if flag not in updated:
            updated.append(flag)

    if updated != existing:
        block = format_block(updated)
        text = text[:match.start()] + block + text[match.end():]
        changed = True
else:
    cli_header = re.compile(r"^\[cli\]\s*$", re.MULTILINE)
    cli_match = cli_header.search(text)
    block = format_block(required_flags)
    insertion = block + "\n"

    if cli_match:
        block_start = cli_match.end()
        next_table = re.search(r"^\[.*?\]", text[block_start:], re.MULTILINE)
        insert_pos = len(text) if not next_table else block_start + next_table.start()

        if block_start < len(text) and text[block_start] != "\n":
            text = text[:block_start] + "\n" + text[block_start:]
            insert_pos += 1

        prefix = text[:insert_pos]
        suffix = text[insert_pos:]
        if prefix and not prefix.endswith("\n"):
            prefix += "\n"
        text = prefix + insertion + suffix
    else:
        if text and not text.endswith("\n"):
            text += "\n"
        text = text.rstrip() + "\n\n[cli]\n" + block + "\n"

    changed = True

if changed:
    config_file.write_text(text if text.endswith("\n") else text + "\n")
    print("updated")
else:
    print("unchanged")
PY
)
    local cli_update_status=$?

    if [ $cli_update_status -ne 0 ]; then
        echo "  - Unable to ensure Codex CLI flags (manual config update required)"
        return
    fi

    case "$status" in
        updated)
            echo "  - Ensured Codex CLI runs with --dangerously-bypass-approvals-and-sandbox and web search"
            ;;
        unchanged)
            echo "  - Codex CLI flags already configured for dangerous bypass and web search"
            ;;
        *)
            echo "  - Unable to validate Codex CLI flags (manual config update required)"
            ;;
    esac
}

ensure_gemini_personas() {
    # Ensure GEMINI.md has the required Personas section
    local project_root="$1"
    local template_path="$REPO_ROOT/_gemini/GEMINI.template.md"
    local gemini_path="$project_root/GEMINI.md"
    local gemini_created=false

    # Do not touch the config repo's own files via this path
    if [ "$project_root" = "$REPO_ROOT" ]; then
        return
    fi

    if [ ! -f "$template_path" ]; then
        return
    fi

    if [ ! -f "$gemini_path" ]; then
        echo "  - No GEMINI.md found; installing from template..."
        cp "$template_path" "$gemini_path"
        gemini_created=true
    fi

    if grep -q "Available Personas" "$gemini_path"; then
        return
    fi

    echo "  - Existing GEMINI.md found without 'Available Personas' section."
    echo "    (These Personas are REQUIRED for Gemini commands to function)"

    local should_append=false

    if [ "$APPEND_AGENTS" = true ]; then
        should_append=true
    elif [ -t 0 ]; then
        printf "  - Append missing Personas to GEMINI.md now? [Y/n] "
        read -r reply
        case "$reply" in
            ""|"Y"|"y")
                should_append=true
                ;;
            *)
                echo "  - Skipping append. WARNING: Commands may fail without defined Personas."
                ;;
        esac
    else
        echo "  - Skipping automatic append (non-interactive; run with --append-agents or edit manually)."
    fi

    if [ "$should_append" = true ]; then
        echo "  - Appending Personas from template..."
        # Extract everything from "## Available Personas" to the end
        awk 'BEGIN{flag=0} /^## Available Personas/{flag=1} flag {print}' "$template_path" >> "$gemini_path"
    fi
}

# Setup thoughts directory structure
setup_thoughts_structure() {
    local target_dir="$1"
    local thoughts_dir="$target_dir/thoughts"

    # Create main thoughts directory
    mkdir -p "$thoughts_dir"

    # Create all subdirectories
    local subdirs=(plans specs research handoffs prs validation debug linear archive)
    for subdir in "${subdirs[@]}"; do
        mkdir -p "$thoughts_dir/$subdir"
    done

    echo "  - Created thoughts/ directory structure"
}

# Create permanent documentation templates if they don't exist
create_permanent_docs() {
    local target_dir="$1"

    # CHANGELOG.md
    if [ ! -f "$target_dir/CHANGELOG.md" ]; then
        cat > "$target_dir/CHANGELOG.md" << 'EOF'
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

<!--
Entries are added by /cmd:graduate after completing features.
Format:
## [Feature Name] - YYYY-MM-DD
### Added/Changed/Fixed
- Description of change
-->
EOF
        echo "  - Created CHANGELOG.md template"
    fi

    # spec/ directory structure
    if [ ! -d "$target_dir/spec" ]; then
        mkdir -p "$target_dir/spec/architecture"
        echo "  - Created spec/ directory structure"
    fi

    # spec/architecture/README.md
    if [ ! -f "$target_dir/spec/architecture/README.md" ]; then
        cat > "$target_dir/spec/architecture/README.md" << 'EOF'
# Architecture Documentation

This directory contains architecture documents for implemented features.

## Architecture Docs

| Feature | Document | Status | Description |
|---------|----------|--------|-------------|
<!-- Rows added by /cmd:graduate after completing features -->
EOF
        echo "  - Created spec/architecture/README.md template"
    fi

    # spec/adr-log.md
    if [ ! -f "$target_dir/spec/adr-log.md" ]; then
        cat > "$target_dir/spec/adr-log.md" << 'EOF'
# Architectural Decision Records

This document captures key architectural decisions and their rationale.

<!--
Entries are prepended by /cmd:graduate after completing features.
Format:
## ADR NNNN: [Decision Title]
**Status:** Accepted
**Date:** YYYY-MM

**Context:** ...
**Decision:** ...
**Alternatives considered:** ...
**Current state:** ...
-->
EOF
        echo "  - Created spec/adr-log.md template"
    fi
}

# Detect and migrate legacy directories
migrate_legacy_directories() {
    local target_dir="$1"
    local thoughts_dir="$target_dir/thoughts"

    # Check for legacy directories
    local has_tasks=false
    local has_tasks_complete=false
    local has_notes_linear=false
    local files_to_migrate=()

    if [ -d "$target_dir/tasks" ]; then
        has_tasks=true
    fi
    if [ -d "$target_dir/tasks-complete" ]; then
        has_tasks_complete=true
    fi
    if [ -d "$target_dir/notes/linear" ]; then
        has_notes_linear=true
    fi

    # If no legacy directories, return
    if [ "$has_tasks" = false ] && [ "$has_tasks_complete" = false ] && [ "$has_notes_linear" = false ]; then
        return 0
    fi

    # Display OBVIOUS migration banner
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}${BOLD}  🔄 MIGRATION DETECTED: Moving existing files to new thoughts/ structure${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "  ${BOLD}Found legacy directories:${NC}"

    if [ "$has_tasks" = true ]; then
        echo -e "    ${GREEN}✓${NC} tasks/           → will migrate to thoughts/plans/ and thoughts/specs/"
    fi
    if [ "$has_tasks_complete" = true ]; then
        echo -e "    ${GREEN}✓${NC} tasks-complete/  → will migrate to thoughts/archive/"
    fi
    if [ "$has_notes_linear" = true ]; then
        echo -e "    ${GREEN}✓${NC} notes/linear/    → will migrate to thoughts/linear/"
    fi
    echo ""

    # List files to be moved
    echo -e "  ${BOLD}The following files will be moved:${NC}"

    if [ "$has_tasks" = true ]; then
        shopt -s nullglob
        for file in "$target_dir/tasks"/*.md; do
            local filename=$(basename "$file")
            local dest=""
            case "$filename" in
                prd-*.md|tasks-*.md|simplify-plan-*.md)
                    dest="thoughts/plans/$filename"
                    ;;
                spec-*.md|research-spec-*.md)
                    dest="thoughts/specs/$filename"
                    ;;
                *)
                    dest="thoughts/plans/$filename"
                    ;;
            esac
            echo -e "    ${YELLOW}$filename${NC} → ${GREEN}$dest${NC}"
            files_to_migrate+=("$file:$target_dir/$dest")
        done
        shopt -u nullglob
    fi

    if [ "$has_tasks_complete" = true ]; then
        shopt -s nullglob
        for file in "$target_dir/tasks-complete"/*.md; do
            local filename=$(basename "$file")
            echo -e "    ${YELLOW}tasks-complete/$filename${NC} → ${GREEN}thoughts/archive/$filename${NC}"
            files_to_migrate+=("$file:$thoughts_dir/archive/$filename")
        done
        shopt -u nullglob
    fi

    if [ "$has_notes_linear" = true ]; then
        shopt -s nullglob
        for file in "$target_dir/notes/linear"/*.md; do
            local filename=$(basename "$file")
            echo -e "    ${YELLOW}notes/linear/$filename${NC} → ${GREEN}thoughts/linear/$filename${NC}"
            files_to_migrate+=("$file:$thoughts_dir/linear/$filename")
        done
        shopt -u nullglob
    fi

    echo ""
    echo -e "  ${YELLOW}⚠️  This is a ONE-TIME migration. Original directories will be removed.${NC}"
    echo -e "  ${YELLOW}⚠️  Git history preserves all files at their original locations.${NC}"
    echo ""

    # Prompt for confirmation
    if [ -t 0 ]; then
        printf "  Press ENTER to continue, or Ctrl+C to cancel... "
        read -r
    else
        echo "  (Non-interactive mode: proceeding with migration)"
    fi

    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════════════════════${NC}"
    echo ""

    # Perform migration
    echo "  - Migrating files..."

    # Ensure thoughts directory structure exists
    setup_thoughts_structure "$target_dir"

    # Move files
    for entry in "${files_to_migrate[@]}"; do
        local src="${entry%%:*}"
        local dest="${entry##*:}"
        if [ -f "$src" ]; then
            mv "$src" "$dest"
            echo "    Moved: $(basename "$src")"
        fi
    done

    # Remove empty legacy directories
    if [ "$has_tasks" = true ] && [ -d "$target_dir/tasks" ]; then
        if [ -z "$(ls -A "$target_dir/tasks" 2>/dev/null)" ]; then
            rmdir "$target_dir/tasks"
            echo "  - Removed empty tasks/ directory"
        else
            echo -e "  ${YELLOW}- tasks/ still contains files, not removing${NC}"
        fi
    fi

    if [ "$has_tasks_complete" = true ] && [ -d "$target_dir/tasks-complete" ]; then
        if [ -z "$(ls -A "$target_dir/tasks-complete" 2>/dev/null)" ]; then
            rmdir "$target_dir/tasks-complete"
            echo "  - Removed empty tasks-complete/ directory"
        else
            echo -e "  ${YELLOW}- tasks-complete/ still contains files, not removing${NC}"
        fi
    fi

    if [ "$has_notes_linear" = true ] && [ -d "$target_dir/notes/linear" ]; then
        if [ -z "$(ls -A "$target_dir/notes/linear" 2>/dev/null)" ]; then
            rmdir "$target_dir/notes/linear"
            # Also remove notes/ if empty
            if [ -d "$target_dir/notes" ] && [ -z "$(ls -A "$target_dir/notes" 2>/dev/null)" ]; then
                rmdir "$target_dir/notes"
            fi
            echo "  - Removed empty notes/linear/ directory"
        else
            echo -e "  ${YELLOW}- notes/linear/ still contains files, not removing${NC}"
        fi
    fi

    echo ""
    echo -e "${GREEN}  ✓ Migration complete!${NC}"
    echo ""
    echo -e "  ${BOLD}Suggested next step:${NC}"
    echo -e "    ${CYAN}git add -A && git commit -m \"chore: migrate to thoughts/ directory structure\"${NC}"
    echo ""
}

ask_overwrite_permission() {
    local target="$1"
    local description="$2"

    if [ -e "$target" ]; then
        echo ""
        echo -e "${YELLOW}  ═══════════════════════════════════════════════════════════════${NC}"
        echo -e "${YELLOW}  ⚠️  Existing configuration found${NC}"
        echo -e "${YELLOW}  ═══════════════════════════════════════════════════════════════${NC}"
        echo "  Location: $target"
        echo "  Type: $description"
        echo ""
        
        if [ -t 0 ]; then
            printf "  Overwrite existing configuration? [Y/n/skip] "
            read -r reply
            case "$reply" in
                ""|"Y"|"y")
                    echo -e "  ${GREEN}✓ Overwrite confirmed${NC}"
                    echo -e "${YELLOW}  ═══════════════════════════════════════════════════════════════${NC}"
                    echo ""
                    return 0
                    ;;
                *"skip"*|"n")
                    echo -e "  ${YELLOW}→ Skipping overwrite (preserving existing configuration)${NC}"
                    echo -e "${YELLOW}  ═══════════════════════════════════════════════════════════════${NC}"
                    echo ""
                    return 1
                    ;;
                *)
                    echo -e "  ${YELLOW}→ Skipping overwrite (preserving existing configuration)${NC}"
                    echo -e "${YELLOW}  ═══════════════════════════════════════════════════════════════${NC}"
                    echo ""
                    return 1
                    ;;
            esac
        else
            echo -e "  ${YELLOW}→ Non-interactive mode: preserving existing configuration${NC}"
            echo "  (Re-run with interactive shell to allow overwrite)"
            echo -e "${YELLOW}  ═══════════════════════════════════════════════════════════════${NC}"
            echo ""
            return 1
        fi
    fi
    return 0
}

sync_codex_prompts() {
    local destination="$1"
    local label="$2"
    local mode="${3:-merge}"

    if [ "$mode" = "replace" ] && [ -d "$destination" ]; then
        echo "  - Resetting $label at $destination"
        rm -rf "$destination"
    fi

    mkdir -p "$destination"

    echo "  - Syncing Codex prompts into $label ($destination)"

    local legacy_dirs=(cmd doc prd spec simplify)
    for legacy_dir in "${legacy_dirs[@]}"; do
        if [ -d "$destination/$legacy_dir" ]; then
            echo "    - Removing legacy subdirectory $legacy_dir/"
            rm -rf "$destination/$legacy_dir"
        fi
    done

    if [ -d "$destination/_lib" ]; then
        rm -rf "$destination/_lib"
    fi

    for prompt in "$REPO_ROOT"/_codex/prompts/*.md; do
        [ -e "$prompt" ] || continue
        cp "$prompt" "$destination/"
    done
}

install_claude() {
    local target="$1/.claude"
    local is_update=false

    # Detect if this is an update
    if [ -d "$target" ]; then
        is_update=true
        echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
        echo -e "${GREEN}  Updating Claude Code Configuration${NC}"
        echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
        echo ""
        echo -e "${GREEN}Updating Claude Code configuration at $target${NC}"
    else
        echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
        echo -e "${GREEN}  Installing Claude Code Configuration${NC}"
        echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
        echo ""
        echo -e "${GREEN}Installing Claude Code configuration to $target${NC}"
        mkdir -p "$target"
    fi

    # Update agents (remove first to ensure clean state)
    echo "  - Installing agents..."
    if [ -d "$target/agents" ]; then
        rm -rf "$target/agents"
    fi
    cp -r "$REPO_ROOT/_claude/agents" "$target/"

    # Update commands (remove first to ensure clean state)
    if [ -d "$target/commands" ]; then
        # Check for legacy subdirectories
        local has_legacy=false
        local legacy_dirs=(cmd doc prd spec)
        for legacy_dir in "${legacy_dirs[@]}"; do
            if [ -d "$target/commands/$legacy_dir" ]; then
                has_legacy=true
                break
            fi
        done

        if [ "$has_legacy" = true ]; then
            echo "  - Cleaning up legacy command structure (subdirectories will be flattened)..."
        fi
    fi

    echo "  - Installing commands..."
    if [ -d "$target/commands" ]; then
        rm -rf "$target/commands"
    fi
    cp -r "$REPO_ROOT/_claude/commands" "$target/"

    # Update scripts (remove first to ensure clean state)
    echo "  - Installing scripts..."
    if [ -d "$target/scripts" ]; then
        rm -rf "$target/scripts"
    fi
    cp -r "$REPO_ROOT/scripts" "$target/"

    # Handle settings.local.json (preserve if exists)
    if [ -f "$target/settings.local.json" ]; then
        echo -e "  ${YELLOW}✓ Preserved existing settings.local.json${NC}"
    else
        echo "  - Installing settings.local.json..."
        cp "$REPO_ROOT/_claude/settings.local.json" "$target/"
    fi

    # Setup thoughts directory structure and migrate legacy directories
    migrate_legacy_directories "$1"
    if [ ! -d "$1/thoughts" ]; then
        setup_thoughts_structure "$1"
    fi
    create_permanent_docs "$1"

    if [ "$is_update" = true ]; then
        echo -e "${GREEN}✓ Claude Code update complete${NC}"
    else
        echo -e "${GREEN}✓ Claude Code installation complete${NC}"
    fi
    echo ""
    echo "Note: CLAUDE.md is NOT installed - codex will generate this file."
}

install_tools() {
    echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  Installing CLI Tools${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
    echo ""

    # Install ltui
    if [ -d "$REPO_ROOT/tools/ltui" ]; then
        echo "Installing ltui..."

        # Check for Bun
        if ! command -v bun &> /dev/null; then
            echo -e "${RED}Error: Bun is required to build ltui${NC}"
            echo "Install from: https://bun.sh"
            return 1
        fi

        local current_dir=$(pwd)
        cd "$REPO_ROOT/tools/ltui"

        echo "  - Installing dependencies..."
        bun install

        echo "  - Building ltui..."
        bun run build

        echo "  - Linking ltui globally..."
        bun link

        cd "$current_dir"
        echo -e "${GREEN}✓ ltui installed successfully${NC}"
        echo ""

        # Check if ~/.bun/bin is in PATH
        if [[ ":$PATH:" != *":$HOME/.bun/bin:"* ]]; then
            echo -e "${YELLOW}⚠  NOTE: ~/.bun/bin is not in your PATH${NC}"
            echo "  Add this to your shell profile (~/.bashrc, ~/.zshrc, etc.):"
            echo "    export PATH=\"\$HOME/.bun/bin:\$PATH\""
            echo ""
            echo "  After updating, run: source ~/.zshrc  (or restart your shell)"
            echo "  Then verify with: ltui --help"
        else
            echo "  ltui is now available globally. Try: ltui --help"
        fi
    else
        echo -e "${YELLOW}No tools directory found, skipping...${NC}"
    fi
}

skill_matrix_path() {
    echo "$REPO_ROOT/skills/install-matrix.json"
}

iterate_installable_skills() {
    local matrix_path
    matrix_path="$(skill_matrix_path)"

    if [ ! -f "$matrix_path" ]; then
        echo -e "${RED}Error: Missing install matrix at $matrix_path${NC}" >&2
        return 1
    fi

    python3 - "$matrix_path" <<'PY'
import json
import sys

matrix_path = sys.argv[1]
with open(matrix_path, 'r', encoding='utf-8') as handle:
    data = json.load(handle)

for name, meta in sorted(data["installableSkills"].items()):
    source_type = meta.get("sourceType", "repo")
    if source_type == "external-package":
        source_id = f"external-package:{meta['packageSource']}#{name}"
    else:
        source_id = meta["canonicalSource"]

    print("\t".join([
        name,
        source_id,
        meta.get("class", ""),
        ",".join(meta.get("allowedConsumers", [])),
    ]))
PY
}

iterate_repo_installable_skills() {
    local matrix_path
    matrix_path="$(skill_matrix_path)"

    python3 - "$matrix_path" <<'PY'
import json
import sys

matrix_path = sys.argv[1]
with open(matrix_path, 'r', encoding='utf-8') as handle:
    data = json.load(handle)

for name, meta in sorted(data["installableSkills"].items()):
    if meta.get("sourceType", "repo") != "repo":
        continue
    print("\t".join([name, meta["canonicalSource"]]))
PY
}

iterate_external_skill_packages() {
    local matrix_path
    matrix_path="$(skill_matrix_path)"

    python3 - "$matrix_path" <<'PY'
import json
import sys
from collections import defaultdict

matrix_path = sys.argv[1]
with open(matrix_path, 'r', encoding='utf-8') as handle:
    data = json.load(handle)

groups = defaultdict(list)
for name, meta in sorted(data["installableSkills"].items()):
    if meta.get("sourceType") != "external-package":
        continue
    package_skill_name = meta.get("packageSkillName", name)
    groups[meta["packageSource"]].append(f"{name}={package_skill_name}")

for package_source, skills in sorted(groups.items()):
    print("\t".join([package_source, ",".join(sorted(skills))]))
PY
}

consumer_is_forced() {
    local consumer="$1"
    shift || true
    local forced_consumer
    for forced_consumer in "$@"; do
        if [ "$forced_consumer" = "$consumer" ]; then
            return 0
        fi
    done
    return 1
}

consumer_allows_skill() {
    local consumer="$1"
    local consumers_csv="$2"

    case ",${consumers_csv}," in
        *",${consumer},"*)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

is_repo_managed_skill_dir() {
    local skill_dir="$1"
    local expected_source="$2"
    local marker_path="$skill_dir/$AI_CONFIGS_MANAGED_MARKER"

    if [ ! -f "$marker_path" ]; then
        return 1
    fi

    python3 - "$marker_path" "$expected_source" <<'PY'
import json
import sys

marker_path = sys.argv[1]
expected_source = sys.argv[2]

with open(marker_path, 'r', encoding='utf-8') as handle:
    data = json.load(handle)

if data.get("repo") != "ai-configs":
    raise SystemExit(1)
if data.get("managed") is not True:
    raise SystemExit(1)
if data.get("source") != expected_source:
    raise SystemExit(1)
PY
}

write_skill_marker() {
    local skill_dir="$1"
    local source_rel="$2"

    python3 - "$skill_dir/$AI_CONFIGS_MANAGED_MARKER" "$source_rel" "$AI_CONFIGS_REPO_COMMIT" <<'PY'
import json
import sys

marker_path = sys.argv[1]
source_rel = sys.argv[2]
repo_commit = sys.argv[3]

payload = {
    "repo": "ai-configs",
    "source": source_rel,
    "managed": True,
    "commit": repo_commit,
}

with open(marker_path, 'w', encoding='utf-8') as handle:
    json.dump(payload, handle, indent=2)
    handle.write("\n")
PY
}

build_external_skill_source_id() {
    local package_source="$1"
    local skill_name="$2"
    echo "external-package:${package_source}#${skill_name}"
}

stage_skill_payload_from_dir() {
    local skill_name="$1"
    local source_id="$2"
    local source_path="$3"
    local shared_skills_dir="$4"
    local stage_dir

    if [ ! -d "$source_path" ]; then
        echo -e "${RED}Error: Missing skill source directory $source_path${NC}" >&2
        return 1
    fi

    stage_dir="$(mktemp -d "$shared_skills_dir/.${skill_name}.stage.XXXXXX")"
    cp -a "$source_path/." "$stage_dir/"
    write_skill_marker "$stage_dir" "$source_id"
    echo "$stage_dir"
}

stage_repo_skill_payload() {
    local skill_name="$1"
    local source_rel="$2"
    local shared_skills_dir="$3"
    local source_path="$REPO_ROOT/$source_rel"

    stage_skill_payload_from_dir "$skill_name" "$source_rel" "$source_path" "$shared_skills_dir"
}

stage_external_skill_payload() {
    local skill_name="$1"
    local package_source="$2"
    local package_skill_name="$3"
    local package_skills_dir="$4"
    local shared_skills_dir="$5"
    local source_id
    local source_path="$package_skills_dir/$package_skill_name"

    source_id="$(build_external_skill_source_id "$package_source" "$skill_name")"
    stage_skill_payload_from_dir "$skill_name" "$source_id" "$source_path" "$shared_skills_dir"
}

skills_are_identical() {
    local left_dir="$1"
    local right_dir="$2"
    diff -qr "$left_dir" "$right_dir" >/dev/null 2>&1
}

backup_existing_path() {
    local destination_path="$1"
    local backup_rel="$2"
    local backup_root="$HOME/.agents/skill-backups/$AI_CONFIGS_REPO_NAME/$AI_CONFIGS_BACKUP_RUN_ID"
    local backup_path="$backup_root/$backup_rel"

    mkdir -p "$(dirname "$backup_path")"
    cp -a "$destination_path" "$backup_path"
    echo "$backup_path"
}

backup_existing_skill() {
    local destination_path="$1"
    local skill_name="$2"
    backup_existing_path "$destination_path" "$skill_name"
}

backup_existing_consumer_entry() {
    local entry_path="$1"
    local consumer="$2"
    local skill_name="$3"
    backup_existing_path "$entry_path" "consumers/$consumer/$skill_name"
}

failpoint_matches() {
    local phase_name="$1"
    local skill_name="$2"
    [ "${AI_CONFIGS_FAILPOINT:-}" = "${phase_name}:${skill_name}" ]
}

print_recovery_error() {
    local skill_name="$1"
    local backup_path="$2"
    local reason="$3"

    echo -e "${RED}Error: ${reason}${NC}" >&2
    echo "  Restore the affected skill from $backup_path and rerun ./install.sh --skills after resolving the underlying issue." >&2
}

install_staged_shared_skill() {
    local skill_name="$1"
    local source_id="$2"
    local stage_dir="$3"
    local shared_skills_dir="$4"
    local destination_path="$shared_skills_dir/$skill_name"
    local previous_path
    local backup_path

    if [ -e "$destination_path" ] || [ -L "$destination_path" ]; then
        if is_repo_managed_skill_dir "$destination_path" "$source_id"; then
            if skills_are_identical "$stage_dir" "$destination_path"; then
                rm -rf "$stage_dir"
                echo "    - Shared skill unchanged: $skill_name"
                return 0
            fi

            previous_path="$shared_skills_dir/.${skill_name}.previous.$$"
            rm -rf "$previous_path"
            mv "$destination_path" "$previous_path"
            if mv "$stage_dir" "$destination_path"; then
                rm -rf "$previous_path"
                echo "    - Updated shared skill: $skill_name"
                return 0
            fi

            mv "$previous_path" "$destination_path"
            rm -rf "$stage_dir"
            echo -e "${RED}Error: Failed to update managed shared skill $skill_name${NC}" >&2
            return 1
        fi

        backup_path="$(backup_existing_skill "$destination_path" "$skill_name")"
        if failpoint_matches "after-backup" "$skill_name"; then
            rm -rf "$stage_dir"
            print_recovery_error "$skill_name" "$backup_path" "Triggered test failpoint after-backup:$skill_name"
            return 1
        fi

        previous_path="$shared_skills_dir/.${skill_name}.previous.$$"
        rm -rf "$previous_path"
        mv "$destination_path" "$previous_path"
        if mv "$stage_dir" "$destination_path"; then
            rm -rf "$previous_path"
            echo "    - Replaced colliding shared skill: $skill_name"
            return 0
        fi

        mv "$previous_path" "$destination_path"
        rm -rf "$stage_dir"
        print_recovery_error "$skill_name" "$backup_path" "Failed to replace colliding shared skill $skill_name"
        return 1
    fi

    mv "$stage_dir" "$destination_path"
    echo "    - Installed shared skill: $skill_name"
}

install_shared_skill() {
    local skill_name="$1"
    local source_rel="$2"
    local shared_skills_dir="$3"
    local stage_dir

    stage_dir="$(stage_repo_skill_payload "$skill_name" "$source_rel" "$shared_skills_dir")"
    install_staged_shared_skill "$skill_name" "$source_rel" "$stage_dir" "$shared_skills_dir"
}

install_external_skill_package() {
    local package_source="$1"
    local csv_skill_mappings="$2"
    local shared_skills_dir="$3"
    local temp_home
    local package_skills_dir
    local skill_mapping
    local local_skill_name
    local package_skill_name
    local source_id
    local stage_dir
    local package_skill_names=()
    local skill_mappings=()

    if ! command -v npx >/dev/null 2>&1; then
        echo -e "${RED}Error: npx is required to fetch external package-managed skills${NC}" >&2
        return 1
    fi

    IFS=',' read -r -a skill_mappings <<< "$csv_skill_mappings"
    for skill_mapping in "${skill_mappings[@]}"; do
        local_skill_name="${skill_mapping%%=*}"
        package_skill_name="${skill_mapping#*=}"
        package_skill_names+=("$package_skill_name")
    done

    temp_home="$(mktemp -d)"
    package_skills_dir="$temp_home/.agents/skills"

    if ! HOME="$temp_home" npx skills add "$package_source" -g --skill "${package_skill_names[@]}" -y </dev/null >/dev/null; then
        rm -rf "$temp_home"
        echo -e "${RED}Error: Failed to fetch external skills from $package_source via npx skills${NC}" >&2
        return 1
    fi

    for skill_mapping in "${skill_mappings[@]}"; do
        local_skill_name="${skill_mapping%%=*}"
        package_skill_name="${skill_mapping#*=}"
        source_id="$(build_external_skill_source_id "$package_source" "$local_skill_name")"
        stage_dir="$(stage_external_skill_payload "$local_skill_name" "$package_source" "$package_skill_name" "$package_skills_dir" "$shared_skills_dir")" || {
            rm -rf "$temp_home"
            return 1
        }
        install_staged_shared_skill "$local_skill_name" "$source_id" "$stage_dir" "$shared_skills_dir" || {
            rm -rf "$temp_home"
            return 1
        }
    done

    rm -rf "$temp_home"
}

consumer_entry_is_repo_managed() {
    local entry_path="$1"
    local shared_target="$2"
    local expected_source="$3"

    if [ -L "$entry_path" ] && [ "$(readlink "$entry_path")" = "$shared_target" ]; then
        return 0
    fi

    if [ -d "$entry_path" ] && is_repo_managed_skill_dir "$entry_path" "$expected_source"; then
        return 0
    fi

    return 1
}

ensure_consumer_skill_link() {
    local consumer="$1"
    local consumer_dir="$2"
    local skill_name="$3"
    local source_rel="$4"
    local shared_skills_dir="$5"
    local shared_target="$shared_skills_dir/$skill_name"
    local link_path="$consumer_dir/$skill_name"
    local previous_path
    local backup_path

    if [ ! -d "$shared_target" ]; then
        echo -e "${RED}Error: Shared skill target missing for $skill_name at $shared_target${NC}" >&2
        return 1
    fi

    if [ -L "$link_path" ] && [ "$(readlink "$link_path")" = "$shared_target" ]; then
        return 0
    fi

    if [ -e "$link_path" ] || [ -L "$link_path" ]; then
        previous_path="$consumer_dir/.${skill_name}.previous.$$"
        rm -rf "$previous_path"

        if consumer_entry_is_repo_managed "$link_path" "$shared_target" "$source_rel"; then
            mv "$link_path" "$previous_path"
            if ln -s "$shared_target" "$link_path"; then
                rm -rf "$previous_path"
                return 0
            fi

            mv "$previous_path" "$link_path"
            echo -e "${RED}Error: Failed to update managed $consumer skill entry $skill_name${NC}" >&2
            return 1
        fi

        backup_path="$(backup_existing_consumer_entry "$link_path" "$consumer" "$skill_name")"
        mv "$link_path" "$previous_path"
        if ln -s "$shared_target" "$link_path"; then
            rm -rf "$previous_path"
            echo "    - Backed up colliding $consumer skill before linking: $skill_name"
            return 0
        fi

        mv "$previous_path" "$link_path"
        echo -e "${RED}Error: Failed to replace colliding $consumer skill entry $skill_name${NC}" >&2
        echo "  Restore the affected consumer skill from $backup_path and rerun ./install.sh --skills after resolving the underlying issue." >&2
        return 1
    fi

    ln -s "$shared_target" "$link_path"
}

remove_consumer_skill_entry() {
    local consumer="$1"
    local consumer_dir="$2"
    local skill_name="$3"
    local source_rel="$4"
    local shared_skills_dir="$5"
    local entry_path="$consumer_dir/$skill_name"
    local shared_target="$shared_skills_dir/$skill_name"
    local previous_path
    local backup_path

    if [ ! -e "$entry_path" ] && [ ! -L "$entry_path" ]; then
        return 0
    fi

    if consumer_entry_is_repo_managed "$entry_path" "$shared_target" "$source_rel"; then
        rm -rf "$entry_path"
        return 0
    fi

    backup_path="$(backup_existing_consumer_entry "$entry_path" "$consumer" "$skill_name")"
    previous_path="$consumer_dir/.${skill_name}.previous.$$"
    rm -rf "$previous_path"
    mv "$entry_path" "$previous_path"
    if rm -rf "$previous_path"; then
        echo "    - Backed up incompatible $consumer skill before removal: $skill_name"
        return 0
    fi

    mv "$previous_path" "$entry_path"
    echo -e "${RED}Error: Failed to remove colliding $consumer skill entry $skill_name${NC}" >&2
    echo "  Restore the affected consumer skill from $backup_path and rerun ./install.sh --skills after resolving the underlying issue." >&2
    return 1
}

sync_consumer_skill_links() {
    local consumer="$1"
    local consumer_dir="$2"
    shift 2

    if consumer_is_forced "$consumer" "$@"; then
        mkdir -p "$consumer_dir"
    fi

    if [ ! -d "$consumer_dir" ]; then
        echo "  - Skipping $consumer compatibility links (directory missing: $consumer_dir)"
        return 0
    fi

    echo "  - Synchronizing $consumer compatibility links in $consumer_dir..."
    while IFS=$'\t' read -r skill_name source_rel _skill_class allowed_consumers; do
        if consumer_allows_skill "$consumer" "$allowed_consumers"; then
            ensure_consumer_skill_link "$consumer" "$consumer_dir" "$skill_name" "$source_rel" "$HOME/.agents/skills"
        else
            remove_consumer_skill_entry "$consumer" "$consumer_dir" "$skill_name" "$source_rel" "$HOME/.agents/skills"
        fi
    done < <(iterate_installable_skills)
}

cleanup_pi_shared_skill_mirrors() {
    local pi_skills_dir="$1"

    if [ ! -d "$pi_skills_dir" ]; then
        return 0
    fi

    echo "  - Removing repo-managed shared skill mirrors from $pi_skills_dir..."
    while IFS=$'\t' read -r skill_name source_rel _skill_class _allowed_consumers; do
        remove_consumer_skill_entry "pi" "$pi_skills_dir" "$skill_name" "$source_rel" "$HOME/.agents/skills"
    done < <(iterate_installable_skills)
}

sync_shared_skills() {
    local shared_skills_dir="$HOME/.agents/skills"

    echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  Syncing Shared Skills${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
    echo ""

    mkdir -p "$shared_skills_dir"

    echo "  - Syncing repo-managed shared skills from skills/ into ~/.agents/skills/..."
    while IFS=$'\t' read -r skill_name source_rel; do
        install_shared_skill "$skill_name" "$source_rel" "$shared_skills_dir"
    done < <(iterate_repo_installable_skills)

    echo "  - Fetching external package-managed shared skills via npx skills..."
    while IFS=$'\t' read -r package_source csv_skill_names; do
        install_external_skill_package "$package_source" "$csv_skill_names" "$shared_skills_dir"
    done < <(iterate_external_skill_packages)

    sync_consumer_skill_links "claude" "$HOME/.claude/skills" "$@"
    sync_consumer_skill_links "opencode" "$HOME/.config/opencode/skills" "$@"
    cleanup_pi_shared_skill_mirrors "$HOME/.pi/agent/skills"

    echo -e "${GREEN}✓ Shared skills synced successfully${NC}"
    echo ""
    echo "  Shared skills now live in ~/.agents/skills"
    echo "  Repo-owned payloads come from skills/; package-backed payloads are fetched per skills/install-matrix.json"
}

install_skills() {
    sync_shared_skills "$@"
}

install_codex() {
    local target="$1/.codex"
    local is_update=false

    # Detect if this is an update
    if [ -d "$target" ]; then
        is_update=true
        echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
        echo -e "${GREEN}  Updating Codex Configuration${NC}"
        echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
        echo ""
        echo -e "${GREEN}Updating Codex configuration at $target${NC}"
    else
        echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
        echo -e "${GREEN}  Installing Codex Configuration${NC}"
        echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
        echo ""
        echo -e "${GREEN}Installing Codex configuration to $target${NC}"
        mkdir -p "$target"
    fi

    local project_prompts_dir="${target}/prompts"
    if [ -d "$project_prompts_dir" ]; then
        echo "  - Removing project prompts (Codex prefers ~/.codex/prompts)..."
        rm -rf "$project_prompts_dir"
    fi

    local project_scripts_dir="${target}/scripts"
    if [ -d "$project_scripts_dir" ]; then
        echo "  - Removing project scripts (Codex prefers ~/.codex/scripts)..."
        rm -rf "$project_scripts_dir"
    fi

    local global_codex_dir="$HOME/.codex"
    mkdir -p "$global_codex_dir"
    local global_prompts_dir="${global_codex_dir}/prompts"
    sync_codex_prompts "$global_prompts_dir" "global (~/.codex/prompts)" "replace"

    echo "  - Syncing Codex scripts globally..."
    rm -rf "$global_codex_dir/scripts"
    cp -r "$REPO_ROOT/scripts" "$global_codex_dir/"

    # Merge config.toml if it exists
    if [ -f "$target/config.toml" ]; then
        echo -e "  ${YELLOW}- config.toml already exists${NC}"
        echo "  - Review $REPO_ROOT/_codex/config.toml for settings to merge"
    else
        echo "  - Installing config.toml..."
        cp "$REPO_ROOT/_codex/config.toml" "$target/"
    fi

    ensure_codex_cli_flags "$target"

    # Copy MCP servers configuration
    echo "  - Installing mcp-servers.toml..."
    cp "$REPO_ROOT/_codex/mcp-servers.toml" "$target/"

    if [ "$is_update" = true ]; then
        echo -e "${GREEN}✓ Codex update complete${NC}"
    else
        echo -e "${GREEN}✓ Codex installation complete${NC}"
    fi
    echo ""
    if [ "$is_update" = false ]; then
        echo "To add MCP servers to Codex, merge mcp-servers.toml into ~/.codex/config.toml"
    fi
}


# Install shared appended system guidance
install_append_system_file() {
    local agent_target="$1"
    local append_system_source="$REPO_ROOT/APPEND_SYSTEM.md"
    local append_system_target="$agent_target/APPEND_SYSTEM.md"

    if [ -f "$append_system_source" ]; then
        cp "$append_system_source" "$append_system_target"
        echo "  - Installed APPEND_SYSTEM.md"
    fi
}

install_omp() {
    local is_update=false
    local omp_root_dir="$HOME/.omp"
    local omp_agent_dir="$omp_root_dir/agent"
    local omp_commands_dir="$omp_agent_dir/commands"
    local omp_agents_dir="$omp_agent_dir/agents"
    local omp_extensions_dir="$omp_agent_dir/extensions"
    local omp_source_dir="$REPO_ROOT/_omp"

    # This is a home-directory install only. Do not write into the repo.
    # Do not write OMP artifacts into the repository itself.

    if [ ! -d "$omp_source_dir" ]; then
        echo -e "${YELLOW}No _omp directory found in repository, skipping OMP install...${NC}"
        return
    fi

    if [ -d "$omp_agent_dir" ]; then
        is_update=true
        echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
        echo -e "${GREEN}  Updating Oh My Pi Configuration${NC}"
        echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
        echo ""
        echo -e "${GREEN}Updating Oh My Pi configuration at $omp_agent_dir${NC}"
    else
        echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
        echo -e "${GREEN}  Installing Oh My Pi Configuration${NC}"
        echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
        echo ""
        echo -e "${GREEN}Installing Oh My Pi configuration to $omp_agent_dir${NC}"
        mkdir -p "$omp_agent_dir"
    fi

    echo "  - Installing OMP commands..."
    rm -rf "$omp_commands_dir"
    mkdir -p "$omp_commands_dir"
    if [ -d "$omp_source_dir/commands" ]; then
        cp -r "$omp_source_dir/commands/." "$omp_commands_dir/"
    fi

    echo "  - Installing OMP agents..."
    rm -rf "$omp_agents_dir"
    mkdir -p "$omp_agents_dir"
    if [ -d "$omp_source_dir/agents" ]; then
        cp -r "$omp_source_dir/agents/." "$omp_agents_dir/"
    fi

    echo "  - Installing OMP extensions..."
    rm -rf "$omp_extensions_dir"
    mkdir -p "$omp_extensions_dir"
    if [ -d "$omp_source_dir/extensions" ]; then
        cp -r "$omp_source_dir/extensions/." "$omp_extensions_dir/"
    fi

    install_append_system_file "$omp_agent_dir"

    if [ "$is_update" = true ]; then
        echo -e "${GREEN}✓ Oh My Pi update complete${NC}"
    else
        echo -e "${GREEN}✓ Oh My Pi installation complete${NC}"
    fi
    echo ""
    echo "Note: OMP commands, agents, and repo-managed extensions are installed to $HOME/.omp/agent"
}
install_opencode() {
    local target_root="$1"
    local is_update=false
    local opencode_config_dir="$HOME/.config/opencode"
    local opencode_prompts_dir="$opencode_config_dir/prompts"
    local opencode_plugin_dir="$opencode_config_dir/plugin"
    local opencode_commands_dir="$opencode_config_dir/commands"
    local opencode_agents_dir="$opencode_config_dir/agents"
    local opencode_skills_dir="$opencode_config_dir/skills"
    local legacy_command_dir="$opencode_config_dir/command"
    local legacy_agent_dir="$opencode_config_dir/agent"
    local legacy_skill_dir="$opencode_config_dir/skill"

    # This is a home-directory install only. Do not write into the repo.
    # (target_root is accepted for CLI parity with other installers.)

    remove_legacy_dir() {
        local legacy_dir="$1"
        local label="$2"

        # Legacy singular dirs are always removed to avoid interactive prompts and
        # ensure a single canonical layout under ~/.config/opencode/{commands,agents,skills}.
        if [ -L "$legacy_dir" ]; then
            rm -f "$legacy_dir"
            return
        fi
        if [ -e "$legacy_dir" ]; then
            echo "  - Removing legacy OpenCode $label directory..."
            rm -rf "$legacy_dir"
        fi
    }


    # Detect if this is an update
    if [ -d "$opencode_config_dir" ]; then
        is_update=true
        echo -e "${GREEN}═══════════════════════════════════════════════════════════════════════════════${NC}"
        echo -e "${GREEN}  Updating OpenCode Configuration${NC}"
        echo -e "${GREEN}═══════════════════════════════════════════════════════════════════════════════${NC}"
        echo ""
        echo -e "${GREEN}Updating OpenCode configuration at $opencode_config_dir${NC}"
    else
        echo -e "${GREEN}═══════════════════════════════════════════════════════════════════════════════${NC}"
        echo -e "${GREEN}  Installing OpenCode Configuration${NC}"
        echo -e "${GREEN}═══════════════════════════════════════════════════════════════════════════════${NC}"
        echo ""
        echo -e "${GREEN}Installing OpenCode configuration to $opencode_config_dir${NC}"
        mkdir -p "$opencode_config_dir"
    fi

    # Create OpenCode config directory structure
    echo "  - Creating OpenCode config directory structure..."
    mkdir -p "$opencode_prompts_dir"
    mkdir -p "$opencode_plugin_dir"

    # Cleanup / migrate legacy singular directories
    remove_legacy_dir "$legacy_command_dir" "commands"
    remove_legacy_dir "$legacy_agent_dir" "agents"
    remove_legacy_dir "$legacy_skill_dir" "skills"

    # Install prompts
    echo "  - Installing OpenCode prompts..."
    mkdir -p "$opencode_prompts_dir"
    cp "$REPO_ROOT/_opencode/prompts/glm-reasoning.md" "$opencode_prompts_dir/" 2>/dev/null || true

    # Install commands (authoritative global location)
    echo "  - Installing OpenCode commands to ~/.config/opencode/commands..."
    rm -rf "$opencode_commands_dir"
    mkdir -p "$opencode_commands_dir"
    if [ -d "$REPO_ROOT/_opencode/commands" ]; then
        cp -r "$REPO_ROOT/_opencode/commands/"* "$opencode_commands_dir/"
    fi

    # Install agents
    echo "  - Installing OpenCode agents to ~/.config/opencode/agents..."
    rm -rf "$opencode_agents_dir"
    mkdir -p "$opencode_agents_dir"
    if [ -d "$REPO_ROOT/_opencode/agents" ]; then
        cp -r "$REPO_ROOT/_opencode/agents/"* "$opencode_agents_dir/"
    fi

    # Shared skills are managed centrally via ~/.agents/skills.
    echo "  - Preparing OpenCode shared-skill compatibility directory at ~/.config/opencode/skills..."
    mkdir -p "$opencode_skills_dir"

    # Install documentation to home config (not the repo)
    echo "  - Installing OpenCode documentation..."
    cp "$REPO_ROOT/_opencode/OPENCODE_ONBOARDING.md" "$opencode_config_dir/OPENCODE_ONBOARDING.md" 2>/dev/null || true

    if [ "$is_update" = true ]; then
        echo -e "${GREEN}✓ OpenCode update complete${NC}"
    else
        echo -e "${GREEN}✓ OpenCode installation complete${NC}"
    fi
    echo ""
    echo "Note: OpenCode configuration file opencode.json is not auto-installed"
    echo "      Copy _opencode/config-template.json to your repo root and customize as needed"
    echo "      Commands, agents, and prompts are installed to $HOME/.config/opencode"
    echo "      Compatible shared skills are linked from ~/.config/opencode/skills to ~/.agents/skills"
    echo "      Documentation installed to $HOME/.config/opencode/OPENCODE_ONBOARDING.md"
}

install_gemini() {
    local target_root="$1"
    local target="$target_root/.gemini"
    local is_update=false

    # Ensure GEMINI.md has the required Personas
    ensure_gemini_personas "$target_root"

    # Detect if this is an update
    if [ -d "$target" ]; then
        is_update=true
        echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
        echo -e "${GREEN}  Updating Gemini CLI Configuration${NC}"
        echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
        echo ""
        echo -e "${GREEN}Updating Gemini configuration at $target${NC}"
    else
        echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
        echo -e "${GREEN}  Installing Gemini CLI Configuration${NC}"
        echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
        echo ""
        echo -e "${GREEN}Installing Gemini configuration to $target${NC}"
        mkdir -p "$target"
    fi

    # Install commands
    echo "  - Installing commands..."
    if [ -d "$target/commands" ]; then
        rm -rf "$target/commands"
    fi
    mkdir -p "$target/commands"
    cp -r "$REPO_ROOT/_gemini/commands/"* "$target/commands/"

    # Install shared scripts used by Gemini command prompts
    echo "  - Installing scripts..."
    if [ -d "$target/scripts" ]; then
        rm -rf "$target/scripts"
    fi
    cp -r "$REPO_ROOT/scripts" "$target/"

    # Setup thoughts directory structure
    if [ "$target_root" != "$HOME" ]; then
        setup_thoughts_structure "$target_root"
        create_permanent_docs "$target_root"
    fi

    if [ "$is_update" = true ]; then
        echo -e "${GREEN}✓ Gemini update complete${NC}"
    else
        echo -e "${GREEN}✓ Gemini installation complete${NC}"
    fi
    echo ""
    if [ "$APPEND_AGENTS" = true ]; then
        echo "Note: GEMINI.md was created or updated with required Personas."
    else
        echo "Note: To ensure GEMINI.md has all required Personas, re-run with --append-agents."
    fi
}

ensure_pi_prompt_paths() {
    local pi_agent_dir="$1"
    local pi_prompts_dir="$2"
    local settings_path="$pi_agent_dir/settings.json"

    if [ ! -d "$pi_prompts_dir" ]; then
        return
    fi

    local status
    status=$(PI_AGENT_DIR="$pi_agent_dir" PI_PROMPTS_DIR="$pi_prompts_dir" SETTINGS_PATH="$settings_path" python3 <<'PY'
import json
import os
from pathlib import Path

agent_dir = Path(os.environ["PI_AGENT_DIR"])
prompts_dir = Path(os.environ["PI_PROMPTS_DIR"])
settings_path = Path(os.environ["SETTINGS_PATH"])

if settings_path.exists():
    data = json.loads(settings_path.read_text())
else:
    data = {}

prompts = data.get("prompts")
if prompts is None:
    prompts = []
elif not isinstance(prompts, list):
    raise SystemExit("invalid-prompts-setting")

required_entries = []
for child in sorted(prompts_dir.iterdir(), key=lambda path: path.name):
    if child.is_dir():
        relative = child.relative_to(agent_dir).as_posix()
        required_entries.append(f"./{relative}")

managed_prefix = f"./{prompts_dir.relative_to(agent_dir).as_posix()}/"
updated = [entry for entry in prompts if not (isinstance(entry, str) and entry.startswith(managed_prefix))]
for entry in required_entries:
    if entry not in updated:
        updated.append(entry)

if updated != prompts:
    if updated:
        data["prompts"] = updated
    else:
        data.pop("prompts", None)
    settings_path.write_text(json.dumps(data, indent=2) + "\n")
    print("updated")
else:
    print("unchanged")
PY
)
    local settings_status=$?

    if [ $settings_status -ne 0 ]; then
        echo "  - Unable to update Pi prompt discovery paths (check $settings_path manually)"
        return
    fi

    if [ "$status" = "updated" ]; then
        echo "  - Synchronized Pi settings prompt directory entries"
    fi
}

install_pi_agents_from_repo() {
    local pi_source_dir="$1"
    local pi_agents_dir="$2"

    rm -rf "$pi_agents_dir"
    mkdir -p "$pi_agents_dir"
    if [ -d "$pi_source_dir/agents" ]; then
        cp -r "$pi_source_dir/agents/." "$pi_agents_dir/"
    fi
}

install_pi() {
    local is_update=false
    local pi_root_dir="$HOME/.pi"
    local pi_agent_dir="$pi_root_dir/agent"
    local pi_skills_dir="$pi_agent_dir/skills"
    local pi_prompts_dir="$pi_agent_dir/prompts"
    local pi_agents_dir="$pi_agent_dir/agents"
    local pi_extensions_dir="$pi_agent_dir/extensions"
    local pi_source_dir="$REPO_ROOT/_pi"

    # This is a home-directory install only. Similar to skills and opencode.
    if [ ! -d "$pi_source_dir" ]; then
        echo -e "${YELLOW}No _pi directory found in repository, skipping Pi install...${NC}"
        return
    fi

    if [ -d "$pi_agent_dir" ]; then
        is_update=true
        echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
        echo -e "${GREEN}  Updating Pi Configuration${NC}"
        echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
        echo ""
        echo -e "${GREEN}Updating Pi configuration at $pi_agent_dir${NC}"
    else
        echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
        echo -e "${GREEN}  Installing Pi Configuration${NC}"
        echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
        echo ""
        echo -e "${GREEN}Installing Pi configuration to $pi_agent_dir${NC}"
        mkdir -p "$pi_agent_dir"
    fi

    # Install prompt templates copied from OMP commands.
    echo "  - Installing Pi prompt templates..."
    rm -rf "$pi_prompts_dir"
    mkdir -p "$pi_prompts_dir"
    if [ -d "$pi_source_dir/prompts" ]; then
        cp -r "$pi_source_dir/prompts/." "$pi_prompts_dir/"
        ensure_pi_prompt_paths "$pi_agent_dir" "$pi_prompts_dir"
    fi

    # Shared installable skills are discovered via ~/.agents/skills.
    echo "  - Shared installable skills are discovered via ~/.agents/skills; ~/.pi/agent/skills is reserved for Pi-local-only entries."

    # Install subagent definitions for @tintinweb/pi-subagents.
    echo "  - Installing Pi subagents..."
    install_pi_agents_from_repo "$pi_source_dir" "$pi_agents_dir"

    # Install extensions.
    echo "  - Installing Pi extensions..."
    rm -rf "$pi_extensions_dir"
    mkdir -p "$pi_extensions_dir"
    if [ -d "$pi_source_dir/extensions" ]; then
        cp -r "$pi_source_dir/extensions/." "$pi_extensions_dir/"
    fi

    # Install documentation.
    if [ -f "$pi_source_dir/README.md" ]; then
        echo "  - Installing Pi documentation..."
        cp "$pi_source_dir/README.md" "$pi_agent_dir/README.md"
    fi

    install_append_system_file "$pi_agent_dir"

    if [ "$is_update" = true ]; then
        echo -e "${GREEN}✓ Pi update complete${NC}"
    else
        echo -e "${GREEN}✓ Pi installation complete${NC}"
    fi
    echo ""
    echo "Note: Pi prompt templates, subagents, and extensions are installed to $HOME/.pi/agent"
    echo "      Prompt templates load from ~/.pi/agent/prompts, shared installable skills load from ~/.agents/skills, subagents load from ~/.pi/agent/agents, and extensions load from ~/.pi/agent/extensions"

    # Install pi-dcp extension via pi package manager
    install_pi_dcp_package

    # Install chrome-cdp-skill extension via pi package manager
    install_chrome_cdp_skill

    # Install pi-rlm extension via pi package manager
    install_pi_rlm_package

    # Install npm-based pi extensions
    install_pi_npm_packages

    # Reinstall repo-managed subagent overrides after package installs so they win
    # over plugin defaults and stay under version control.
    echo "  - Re-installing Pi subagent overrides after Pi package installs..."
    install_pi_agents_from_repo "$pi_source_dir" "$pi_agents_dir"
}

# Install pi-dcp extension via pi package manager
install_pi_dcp_package() {
    echo ""
    echo -e "${GREEN}  Installing pi-dcp extension via pi package manager...${NC}"

    # Check if pi-dcp is already installed
    if pi list 2>/dev/null | grep -q "pi-dcp"; then
        echo "  - pi-dcp already installed, updating..."
        pi update pi-dcp 2>/dev/null || echo -e "    ${YELLOW}⚠ Update check skipped (pi update may require manual run)${NC}"
    else
        echo "  - Installing pi-dcp from git repository..."
        if pi install git:github.com/adnichols/pi-dcp 2>/dev/null; then
            echo -e "    ${GREEN}✓ pi-dcp installed${NC}"
        else
            echo -e "    ${YELLOW}⚠ pi install command not available or failed${NC}"
            echo "      To install manually, run:"
            echo "        pi install git:github.com/adnichols/pi-dcp"
            return 1
        fi
    fi
}

# Install chrome-cdp-skill extension via pi package manager
install_chrome_cdp_skill() {
    echo ""
    echo -e "${GREEN}  Installing chrome-cdp-skill extension via pi package manager...${NC}"

    # Check if chrome-cdp-skill is already installed
    if pi list 2>/dev/null | grep -q "chrome-cdp-skill"; then
        echo "  - chrome-cdp-skill already installed, updating..."
        pi update chrome-cdp-skill 2>/dev/null || echo -e "    ${YELLOW}⚠ Update check skipped (pi update may require manual run)${NC}"
    else
        echo "  - Installing chrome-cdp-skill from git repository..."
        if pi install git:github.com/pasky/chrome-cdp-skill 2>/dev/null; then
            echo -e "    ${GREEN}✓ chrome-cdp-skill installed${NC}"
        else
            echo -e "    ${YELLOW}⚠ pi install command not available or failed${NC}"
            echo "      To install manually, run:"
            echo "        pi install git:github.com/pasky/chrome-cdp-skill"
            return 1
        fi
    fi
}

# Install pi-rlm extension via pi package manager
install_pi_rlm_package() {
    echo ""
    echo -e "${GREEN}  Installing pi-rlm extension via pi package manager...${NC}"

    if pi list 2>/dev/null | grep -q "pi-rlm"; then
        echo "  - pi-rlm already installed, updating..."
        pi update pi-rlm 2>/dev/null || echo -e "    ${YELLOW}⚠ Update check skipped (pi update may require manual run)${NC}"
    else
        echo "  - Installing pi-rlm from git repository..."
        if pi install git:github.com/adnichols/pi-rlm 2>/dev/null; then
            echo -e "    ${GREEN}✓ pi-rlm installed${NC}"
        else
            echo -e "    ${YELLOW}⚠ pi install command not available or failed${NC}"
            echo "      To install manually, run:"
            echo "        pi install git:github.com/adnichols/pi-rlm"
            return 1
        fi
    fi
}

# Install npm-based pi extensions
install_pi_npm_packages() {
    echo ""
    echo -e "${GREEN}  Installing npm-based pi extensions...${NC}"

    # Core extensions for the user's workflow
    local npm_packages=(
        "@tintinweb/pi-subagents"
        "@aliou/pi-processes"
        "pi-web-access"
        "pi-mcp-adapter"
        "lsp-pi"
        "@fnnm/pi-ast-grep"
        "pi-updater"
        "pi-interactive-shell"
        "pi-powerline-footer"
        "@marckrenn/pi-sub-bar"
        "pi-side-agents"
        "pi-multi-pass"
        "pi-no-soft-cursor"
        "@tmustier/pi-files-widget"
        "@tmustier/pi-raw-paste"
        "@sting8k/pi-vcc"
    )
    local deprecated_npm_packages=(
        "pi-subagents"
    )

    # Check if npm is available
    if ! command -v npm &> /dev/null; then
        echo -e "    ${YELLOW}⚠ npm not found in PATH${NC}"
        echo "      Please install Node.js/npm to install pi extensions"
        return 1
    fi

    # Remove deprecated packages from Pi settings before installing replacements.
    for pkg in "${deprecated_npm_packages[@]}"; do
        local source="npm:$pkg"
        if pi list 2>/dev/null | grep -Fq "$source"; then
            echo "  - Removing deprecated Pi package $pkg..."
            if pi remove "$source" 2>/dev/null; then
                echo -e "    ${GREEN}✓ $pkg removed${NC}"
            else
                echo -e "    ${YELLOW}⚠ Failed to remove deprecated package $pkg${NC}"
                echo "      To remove manually, run:"
                echo "        pi remove $source"
            fi
        fi
    done

    # Install/update each package through Pi so it is registered in settings
    for pkg in "${npm_packages[@]}"; do
        local source="npm:$pkg"
        echo "  - Checking $pkg..."
        if pi list 2>/dev/null | grep -Fq "$source"; then
            echo "    - $pkg already registered with Pi, updating..."
            pi update "$source" 2>/dev/null || echo -e "    ${YELLOW}⚠ Update check skipped (pi update may require manual run)${NC}"
        else
            echo "    Installing $pkg via pi package manager..."
            if pi install "$source" 2>/dev/null; then
                echo -e "    ${GREEN}✓ $pkg installed${NC}"
            else
                echo -e "    ${YELLOW}⚠ Failed to install $pkg via pi package manager${NC}"
                echo "      To install manually, run:"
                echo "        pi install $source"
            fi
        fi
    done

    echo -e "${GREEN}  ✓ npm-based extensions processed${NC}"
}

# Argument parsing
while [ "$#" -gt 0 ]; do
    case "$1" in
        --claude|--codex|--gemini|--omp|--opencode|--pi|--tools|--skills|--all|--default)
            INSTALL_MODE="$1"
            shift
            ;;
        --append-agents)
            APPEND_AGENTS=true
            shift
            ;;
        --help|-h)
            print_usage
            exit 0
            ;;
        *)
            if [[ "$1" == -* ]]; then
                echo -e "${RED}Error: Unknown option $1${NC}"
                echo ""
                print_usage
                exit 1
            fi
            TARGET_DIR="$1"
            shift
            ;;
    esac
done

# Main installation logic
case "$INSTALL_MODE" in
    --default)
        install_claude "$TARGET_DIR"
        echo ""
        install_codex "$TARGET_DIR"
        echo ""
        install_gemini "$TARGET_DIR"
        echo ""
        install_omp "$TARGET_DIR"
        echo ""
        install_opencode "$TARGET_DIR"
        echo ""
        install_pi
        echo ""
        sync_shared_skills claude opencode
        ;;
    --claude)
        install_claude "$TARGET_DIR"
        echo ""
        sync_shared_skills claude
        ;;
    --codex)
        install_codex "$TARGET_DIR"
        ;;
    --gemini)
        install_gemini "$TARGET_DIR"
        ;;
    --omp)
        install_omp "$TARGET_DIR"
        echo ""
        sync_shared_skills
        ;;
    --opencode)
        install_opencode "$TARGET_DIR"
        echo ""
        sync_shared_skills opencode
        ;;
    --pi)
        install_pi
        echo ""
        sync_shared_skills
        ;;
    --tools)
        install_tools
        ;;
    --skills)
        install_skills
        ;;
    --all)
        install_claude "$TARGET_DIR"
        echo ""
        install_codex "$TARGET_DIR"
        echo ""
        install_gemini "$TARGET_DIR"
        echo ""
        install_omp "$TARGET_DIR"
        echo ""
        install_opencode "$TARGET_DIR"
        echo ""
        install_pi
        echo ""
        install_tools
        echo ""
        sync_shared_skills claude opencode
        ;;
    *)
        echo -e "${RED}Error: Unknown option $INSTALL_MODE${NC}"
        echo ""
        print_usage
        exit 1
        ;;
esac

echo ""
echo -e "${GREEN}Installation complete!${NC}"
echo ""
echo "Next steps:"
echo "  1. Review and customize settings as needed"
echo "  2. Run this script again to sync future updates (it auto-detects existing installations)"
