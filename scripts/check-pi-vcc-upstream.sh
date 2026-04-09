#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
VENDORED_DIR_REL="./_pi/packages/pi-vcc"
VENDORED_DIR="$REPO_ROOT/_pi/packages/pi-vcc"
README_PATH="$VENDORED_DIR/README.md"
PACKAGE_JSON="$VENDORED_DIR/package.json"
UPSTREAM_REPO_URL="https://github.com/sting8k/pi-vcc.git"
EXPECTED_LOCAL_DIFFS=(
  ".gitignore"
  "README.md"
  "package.json"
  "src/commands/pi-vcc.ts"
  "src/hooks/before-compact.ts"
  "tests/before-compact.test.ts"
)

if [ ! -d "$VENDORED_DIR" ]; then
  echo "Vendored pi-vcc directory not found: $VENDORED_DIR_REL" >&2
  exit 1
fi

if ! command -v git >/dev/null 2>&1; then
  echo "git is required" >&2
  exit 1
fi

if ! command -v npm >/dev/null 2>&1; then
  echo "npm is required" >&2
  exit 1
fi

UPSTREAM_VERSION="$(python3 - "$PACKAGE_JSON" <<'PY'
import json, sys
with open(sys.argv[1], 'r', encoding='utf-8') as f:
    version = json.load(f)['version']
print(version.split('-ai-configs', 1)[0])
PY
)"

RECORDED_COMMIT="$(python3 - "$README_PATH" <<'PY'
import re, sys
text = open(sys.argv[1], 'r', encoding='utf-8').read()
m = re.search(r'^- Upstream commit snapshot: `([0-9a-f]{7,40})`$', text, re.M)
print(m.group(1) if m else '')
PY
)"

NPM_LATEST_VERSION="$(npm view @sting8k/pi-vcc version 2>/dev/null || true)"
UPSTREAM_HEAD="$(git ls-remote "$UPSTREAM_REPO_URL" refs/heads/master | awk '{print $1}')"

TMP_DIR="$(mktemp -d)"
cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

git clone --depth 1 "$UPSTREAM_REPO_URL" "$TMP_DIR/upstream" >/dev/null 2>&1

RAW_DIFF_LINES="$({
  diff -qr \
    --exclude node_modules \
    --exclude package-lock.json \
    --exclude .git \
    "$TMP_DIR/upstream" "$VENDORED_DIR" || true
} | sed '/^$/d')"

NORMALIZED_DIFFS="$({
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    case "$line" in
      "Only in $TMP_DIR/upstream:"*)
        path="${line#Only in $TMP_DIR/upstream: }"
        printf '%s\n' "$path"
        ;;
      "Only in $VENDORED_DIR:"*)
        path="${line#Only in $VENDORED_DIR: }"
        printf '%s\n' "$path"
        ;;
      "Only in $VENDORED_DIR/"*)
        path="${line#Only in $VENDORED_DIR/}"
        dir="${path%%:*}"
        file="${line##*: }"
        printf '%s/%s\n' "$dir" "$file"
        ;;
      Files\ "$TMP_DIR/upstream/"*\ and\ "$VENDORED_DIR/"*\ differ)
        path="${line#Files $TMP_DIR/upstream/}"
        path="${path%% and $VENDORED_DIR/*}"
        printf '%s\n' "$path"
        ;;
      *)
        printf 'UNPARSED: %s\n' "$line"
        ;;
    esac
  done <<EOF
$RAW_DIFF_LINES
EOF
} | sort -u)"

EXPECTED_DIFFS_TEXT="$(printf '%s\n' "${EXPECTED_LOCAL_DIFFS[@]}" | sort -u)"
UNEXPECTED_DIFFS="$({
  comm -23 \
    <(printf '%s\n' "$NORMALIZED_DIFFS" | sed '/^$/d' | sort -u) \
    <(printf '%s\n' "$EXPECTED_DIFFS_TEXT" | sed '/^$/d' | sort -u)
} || true)"
MISSING_EXPECTED_DIFFS="$({
  comm -23 \
    <(printf '%s\n' "$EXPECTED_DIFFS_TEXT" | sed '/^$/d' | sort -u) \
    <(printf '%s\n' "$NORMALIZED_DIFFS" | sed '/^$/d' | sort -u)
} || true)"

printf 'pi-vcc upstream check\n'
printf 'vendored path: %s\n' "$VENDORED_DIR_REL"
printf 'vendored upstream version: %s\n' "$UPSTREAM_VERSION"
printf 'recorded upstream commit: %s\n' "${RECORDED_COMMIT:-<missing from README>}"
printf 'npm latest version: %s\n' "${NPM_LATEST_VERSION:-<unavailable>}"
printf 'upstream master head: %s\n' "$UPSTREAM_HEAD"

if [ -n "$NPM_LATEST_VERSION" ] && [ "$NPM_LATEST_VERSION" != "$UPSTREAM_VERSION" ]; then
  printf 'version status: UPDATE AVAILABLE (vendored %s, npm latest %s)\n' "$UPSTREAM_VERSION" "$NPM_LATEST_VERSION"
else
  printf 'version status: up to date with npm latest\n'
fi

if [ -n "$RECORDED_COMMIT" ] && [ "$RECORDED_COMMIT" != "$UPSTREAM_HEAD" ]; then
  printf 'commit status: UPDATE AVAILABLE (recorded %s, upstream %s)\n' "$RECORDED_COMMIT" "$UPSTREAM_HEAD"
else
  printf 'commit status: recorded commit matches upstream head\n'
fi

printf '\nlocal drift vs upstream clone:\n'
if [ -z "$NORMALIZED_DIFFS" ]; then
  printf '  none\n'
else
  while IFS= read -r item; do
    [ -n "$item" ] || continue
    printf '  %s\n' "$item"
  done <<EOF
$NORMALIZED_DIFFS
EOF
fi

printf '\nexpected local diffs:\n'
while IFS= read -r item; do
  [ -n "$item" ] || continue
  printf '  %s\n' "$item"
done <<EOF
$EXPECTED_DIFFS_TEXT
EOF

if [ -n "$UNEXPECTED_DIFFS" ]; then
  printf '\nunexpected diffs:\n'
  while IFS= read -r item; do
    [ -n "$item" ] || continue
    printf '  %s\n' "$item"
  done <<EOF
$UNEXPECTED_DIFFS
EOF
  exit 1
fi

if [ -n "$MISSING_EXPECTED_DIFFS" ]; then
  printf '\nmissing expected local diffs:\n'
  while IFS= read -r item; do
    [ -n "$item" ] || continue
    printf '  %s\n' "$item"
  done <<EOF
$MISSING_EXPECTED_DIFFS
EOF
fi

if [ -n "$RECORDED_COMMIT" ] && [ "$RECORDED_COMMIT" != "$UPSTREAM_HEAD" ]; then
  exit 2
fi

if [ -n "$NPM_LATEST_VERSION" ] && [ "$NPM_LATEST_VERSION" != "$UPSTREAM_VERSION" ]; then
  exit 2
fi
