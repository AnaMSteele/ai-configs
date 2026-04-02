#!/bin/bash
set -euo pipefail

TARGET="$HOME/code/ai-configs/opencode"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "Syncing managed OpenCode files to $TARGET..."

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

for dir in agents commands prompts skills scripts; do
  sync_dir "$dir"
done

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
