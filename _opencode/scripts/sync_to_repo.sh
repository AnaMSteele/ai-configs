#!/bin/bash
set -euo pipefail

TARGET="${OPENCODE_SYNC_TARGET:-$HOME/code/ai-configs/_opencode}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "Syncing managed OpenCode files to $TARGET..."

if [[ "$(cd "$TARGET" 2>/dev/null && pwd || true)" == "$ROOT" ]]; then
  echo "Source and target are the same directory; nothing to sync."
  exit 0
fi

mkdir -p "$TARGET"

sync_dir() {
  local dir="$1"
  if [[ -d "$ROOT/$dir" ]]; then
    mkdir -p "$TARGET/$dir"
    rsync -av "$ROOT/$dir/" "$TARGET/$dir/"
  fi
}

sync_file() {
  local file="$1"
  if [[ -f "$ROOT/$file" ]]; then
    mkdir -p "$(dirname "$TARGET/$file")"
    rsync -av "$ROOT/$file" "$TARGET/$file"
  fi
}

sync_skills() {
  local source_dir="$ROOT/skills"
  local target_dir="$TARGET/skills"

  [[ -d "$source_dir" ]] || return 0
  mkdir -p "$target_dir"

  for skill_path in "$source_dir"/*; do
    [[ -e "$skill_path" || -L "$skill_path" ]] || continue

    local skill_name
    skill_name="$(basename "$skill_path")"

    if [[ -L "$skill_path" ]]; then
      echo "Skipping linked shared skill: skills/$skill_name"
      continue
    fi

    if [[ -d "$skill_path" ]]; then
      mkdir -p "$target_dir/$skill_name"
      rsync -av "$skill_path/" "$target_dir/$skill_name/"
    elif [[ -f "$skill_path" ]]; then
      rsync -av "$skill_path" "$target_dir/$skill_name"
    fi
  done
}

for dir in agents commands prompts scripts; do
  sync_dir "$dir"
done

sync_skills

for file in \
  .gitignore \
  AGENTS.md \
  OPENCODE_ONBOARDING.md \
  QUICKSTART.md \
  config-template.json \
  dcp.jsonc \
  read-truncation-warning-plugin.js \
  simple-plugin-test.js \
  smart-title.jsonc
do
  sync_file "$file"
done

echo "Sync complete."
