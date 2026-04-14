#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
VENDORED_DIR_REL="./_pi/packages/pi-vcc"
VENDORED_DIR="$REPO_ROOT/_pi/packages/pi-vcc"
README_PATH="$VENDORED_DIR/README.md"
PACKAGE_JSON="$VENDORED_DIR/package.json"
UPSTREAM_REPO_URL="https://github.com/sting8k/pi-vcc.git"
VERBOSE=0
EXPECTED_LOCAL_DIFFS=(
  "README.md"
  "package.json"
  "src/commands/pi-vcc.ts"
  "src/core/format.ts"
  "src/core/summarize.ts"
  "src/hooks/before-compact.ts"
  "tests/before-compact.test.ts"
  "tests/compile.test.ts"
  "tests/fixtures.ts"
  "tests/format.test.ts"
  "tests/support/load-session.ts"
)

for arg in "$@"; do
  case "$arg" in
    --verbose|-v)
      VERBOSE=1
      ;;
    --summary)
      ;;
    *)
      echo "Usage: $0 [--verbose]" >&2
      exit 1
      ;;
  esac
done

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

NORMALIZED_DIFFS="$(python3 - "$TMP_DIR/upstream" "$VENDORED_DIR" <<'PY'
from pathlib import Path
import os, sys

upstream = Path(sys.argv[1])
vendored = Path(sys.argv[2])
ignore_dirs = {'.git', 'node_modules'}
ignore_files = {'package-lock.json'}

def collect(root: Path):
    files = {}
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d not in ignore_dirs]
        base = Path(dirpath)
        for filename in filenames:
            if filename in ignore_files:
                continue
            path = base / filename
            rel = path.relative_to(root).as_posix()
            files[rel] = path
    return files

left = collect(upstream)
right = collect(vendored)
all_paths = sorted(set(left) | set(right))
diffs = []
for rel in all_paths:
    l = left.get(rel)
    r = right.get(rel)
    if l is None or r is None:
        diffs.append(rel)
        continue
    if l.read_bytes() != r.read_bytes():
        diffs.append(rel)
print('\n'.join(diffs))
PY
)"

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

DRIFT_COUNT="$(printf '%s\n' "$NORMALIZED_DIFFS" | sed '/^$/d' | wc -l | tr -d ' ')"
UNEXPECTED_COUNT="$(printf '%s\n' "$UNEXPECTED_DIFFS" | sed '/^$/d' | wc -l | tr -d ' ')"
MISSING_COUNT="$(printf '%s\n' "$MISSING_EXPECTED_DIFFS" | sed '/^$/d' | wc -l | tr -d ' ')"

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

if [ -z "$NORMALIZED_DIFFS" ]; then
  printf 'drift status: no local diffs vs upstream clone\n'
elif [ -n "$UNEXPECTED_DIFFS" ]; then
  printf 'drift status: unexpected local diffs present\n'
else
  printf 'drift status: only expected local diffs present (%s paths)\n' "$DRIFT_COUNT"
fi

if [ "$UNEXPECTED_COUNT" -gt 0 ]; then
  printf 'unexpected diff count: %s\n' "$UNEXPECTED_COUNT"
fi

if [ "$MISSING_COUNT" -gt 0 ]; then
  printf 'missing expected diff count: %s\n' "$MISSING_COUNT"
fi

if [ "$VERBOSE" -eq 1 ]; then
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
elif [ "$UNEXPECTED_COUNT" -gt 0 ] || [ "$MISSING_COUNT" -gt 0 ]; then
  printf 'review details with: ./scripts/check-pi-vcc-upstream.sh --verbose\n'
fi

if [ -n "$UNEXPECTED_DIFFS" ]; then
  exit 1
fi

if [ -n "$RECORDED_COMMIT" ] && [ "$RECORDED_COMMIT" != "$UPSTREAM_HEAD" ]; then
  exit 2
fi

if [ -n "$NPM_LATEST_VERSION" ] && [ "$NPM_LATEST_VERSION" != "$UPSTREAM_VERSION" ]; then
  exit 2
fi
