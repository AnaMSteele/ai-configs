#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PI_AGENT_DIR="${PI_AGENT_DIR:-${PI_CODING_AGENT_DIR:-$HOME/.pi/agent}}"
PI_EXT_DIR="$PI_AGENT_DIR/extensions"

EXPECTED_GIT_PACKAGES=(
  "git:github.com/pasky/chrome-cdp-skill"
  "git:github.com/edxeth/pi-gpt-config"
  "git:github.com/adnichols/pi-multi-pass"
)

EXPECTED_NPM_PACKAGES=(
  "npm:@tintinweb/pi-subagents"
  "npm:@aliou/pi-processes"
  "npm:pi-web-access"
  "npm:@fnnm/pi-ast-grep"
  "npm:pi-updater"
  "npm:pi-powerline-footer"
  "npm:pi-side-agents"
  "npm:pi-no-soft-cursor"
  "npm:@tmustier/pi-files-widget"
  "npm:@tmustier/pi-raw-paste"
)

FAILURES=0

print_section() {
  echo
  echo "$1"
}

note_failure() {
  local message="$1"
  FAILURES=$((FAILURES + 1))
  echo "  FAIL: $message"
}

list_find_entries() {
  local dir="$1"
  if [ -d "$dir" ]; then
    find "$dir" -mindepth 1 -maxdepth 1 -exec basename {} \; | sort
  fi
}

print_list() {
  local prefix="$1"
  local lines="${2:-}"

  if [ -z "$(printf '%s' "$lines" | tr -d '[:space:]')" ]; then
    echo "  (none)"
    return
  fi

  while IFS= read -r item; do
    [ -n "$item" ] || continue
    echo "  ${prefix}${item}"
  done <<EOF
$lines
EOF
}

report_expected_vs_actual() {
  local label="$1"
  local expected_lines="$2"
  local actual_lines="$3"
  local fail_on_missing="$4"

  local expected_file actual_file
  expected_file="$(mktemp)"
  actual_file="$(mktemp)"

  printf '%s\n' "$expected_lines" | sed '/^$/d' | sort -u > "$expected_file"
  printf '%s\n' "$actual_lines" | sed '/^$/d' | sort -u > "$actual_file"

  local missing extra
  missing="$(comm -23 "$expected_file" "$actual_file")"
  extra="$(comm -13 "$expected_file" "$actual_file")"

  echo "$label"
  if [ -z "$missing" ]; then
    echo "  Missing: none"
  else
    echo "  Missing:"
    while IFS= read -r item; do
      [ -n "$item" ] || continue
      echo "    - $item"
    done <<EOF
$missing
EOF
    if [ "$fail_on_missing" = true ]; then
      note_failure "$label is missing expected entries"
    fi
  fi

  if [ -z "$extra" ]; then
    echo "  Extra: none"
  else
    echo "  Extra:"
    while IFS= read -r item; do
      [ -n "$item" ] || continue
      echo "    - $item"
    done <<EOF
$extra
EOF
  fi

  rm -f "$expected_file" "$actual_file"
}

EXPECTED_REPO_EXTENSIONS="$(cd "$REPO_ROOT" && list_find_entries "_pi/extensions")"
EXPECTED_LOCAL_PACKAGES="$(cd "$REPO_ROOT" && pwd)/_pi/packages/pi-vcc"
LOCAL_PI_INTERACTIVE_SHELL="$(cd "$REPO_ROOT/../3p/pi-interactive-shell" 2>/dev/null && pwd || true)"
if [ -n "$LOCAL_PI_INTERACTIVE_SHELL" ]; then
  EXPECTED_LOCAL_PACKAGES="$EXPECTED_LOCAL_PACKAGES
$LOCAL_PI_INTERACTIVE_SHELL"
else
  EXPECTED_NPM_PACKAGES+=("git:github.com/adnichols/pi-interactive-shell")
fi
INSTALLED_REPO_EXTENSIONS="$(list_find_entries "$PI_EXT_DIR")"
INSTALLED_PI_PACKAGES=""

if command -v pi >/dev/null 2>&1; then
  INSTALLED_PI_PACKAGES="$({
    pi list 2>/dev/null |
      sed -n 's/^  \([^[:space:]].*\)$/\1/p' |
      sed -E 's#^(git:[^@[:space:]]+)@.*#\1#' |
      while IFS= read -r source; do
        [ -n "$source" ] || continue
        if [[ "$source" == npm:* || "$source" == git:* ]]; then
          printf '%s\n' "$source"
        else
          python3 -c 'import os, sys; source = sys.argv[1]; base = sys.argv[2]; print(os.path.realpath(source if os.path.isabs(source) else os.path.join(base, source)))' "$source" "$PI_AGENT_DIR"
        fi
      done |
      sort -u
  } || true)"
else
  note_failure "pi command is not available in PATH"
fi

echo "Pi install verification"
echo "Repo root: $REPO_ROOT"
echo "Pi agent dir: $PI_AGENT_DIR"

print_section "1) Repo-managed Pi extensions (copied into ~/.pi/agent/extensions; these do NOT appear in 'pi list')"
print_list "expected: " "$EXPECTED_REPO_EXTENSIONS"
print_list "installed: " "$INSTALLED_REPO_EXTENSIONS"
report_expected_vs_actual "  Comparison:" "$EXPECTED_REPO_EXTENSIONS" "$INSTALLED_REPO_EXTENSIONS" true

print_section "2) Package-managed Pi installs (registered via 'pi install'; these DO appear in 'pi list')"
print_list "expected git: " "$(printf '%s\n' "${EXPECTED_GIT_PACKAGES[@]}")"
print_list "expected npm: " "$(printf '%s\n' "${EXPECTED_NPM_PACKAGES[@]}")"
print_list "expected local: " "$EXPECTED_LOCAL_PACKAGES"
print_list "registered: " "$INSTALLED_PI_PACKAGES"
ALL_EXPECTED_PACKAGES="$(printf '%s\n' "${EXPECTED_GIT_PACKAGES[@]}" "${EXPECTED_NPM_PACKAGES[@]}")"
ALL_EXPECTED_PACKAGES="$(printf '%s\n%s\n' "$ALL_EXPECTED_PACKAGES" "$EXPECTED_LOCAL_PACKAGES")"
report_expected_vs_actual "  Comparison:" "$ALL_EXPECTED_PACKAGES" "$INSTALLED_PI_PACKAGES" true

print_section "3) Quick checks"
echo "  Repo-managed extensions: find ~/.pi/agent/extensions -mindepth 1 -maxdepth 1 -exec basename {} \\; | sort"
echo "  Package-managed installs: pi list"

if [ -f "$REPO_ROOT/_pi/packages/pi-vcc/src/commands/pi-vcc.ts" ]; then
  echo "  vendored pi-vcc command source: present"
else
  echo "  vendored pi-vcc command source: missing"
fi

if [ "$FAILURES" -gt 0 ]; then
  echo
  echo "Verification failed with $FAILURES issue(s)."
  exit 1
fi

echo

echo "Verification passed."
