#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PI_AGENT_DIR="${PI_AGENT_DIR:-$HOME/.pi/agent}"
PI_EXT_DIR="$PI_AGENT_DIR/extensions"

EXPECTED_GIT_PACKAGES=(
  "git:github.com/adnichols/pi-dcp"
  "git:github.com/pasky/chrome-cdp-skill"
  "git:github.com/adnichols/pi-rlm"
)

EXPECTED_NPM_PACKAGES=(
  "npm:pi-subagents"
  "npm:@aliou/pi-processes"
  "npm:pi-web-access"
  "npm:pi-mcp-adapter"
  "npm:lsp-pi"
  "npm:@fnnm/pi-ast-grep"
  "npm:pi-updater"
  "npm:pi-interactive-shell"
  "npm:pi-powerline-footer"
  "npm:pi-side-agents"
  "npm:pi-multi-pass"
  "npm:pi-no-soft-cursor"
  "npm:@tmustier/pi-files-widget"
  "npm:@tmustier/pi-raw-paste"
)

mapfile -t EXPECTED_REPO_EXTENSIONS < <(
  cd "$REPO_ROOT" && find _pi/extensions -mindepth 1 -maxdepth 1 -printf '%f\n' | sort
)

mapfile -t INSTALLED_REPO_EXTENSIONS < <(
  if [ -d "$PI_EXT_DIR" ]; then
    find "$PI_EXT_DIR" -mindepth 1 -maxdepth 1 -printf '%f\n' | sort
  fi
)

mapfile -t INSTALLED_PI_PACKAGES < <(
  if command -v pi >/dev/null 2>&1; then
    pi list 2>/dev/null |
      sed -n 's/^  \([^[:space:]].*\)$/\1/p' |
      sed -E 's#^(git:[^@[:space:]]+)@.*#\1#' |
      sort -u
  fi
)

print_section() {
  echo
  echo "$1"
}

print_list() {
  local prefix="$1"
  shift || true
  if [ "$#" -eq 0 ]; then
    echo "  (none)"
    return
  fi
  for item in "$@"; do
    echo "  ${prefix}${item}"
  done
}

compare_lists() {
  local label="$1"
  shift
  local -n expected_ref=$1
  shift
  local -n actual_ref=$1
  shift

  local expected_file actual_file
  expected_file="$(mktemp)"
  actual_file="$(mktemp)"

  printf '%s\n' "${expected_ref[@]}" | sed '/^$/d' | sort -u > "$expected_file"
  printf '%s\n' "${actual_ref[@]}" | sed '/^$/d' | sort -u > "$actual_file"

  mapfile -t missing < <(comm -23 "$expected_file" "$actual_file")
  mapfile -t extra < <(comm -13 "$expected_file" "$actual_file")

  echo "$label"
  if [ "${#missing[@]}" -eq 0 ]; then
    echo "  Missing: none"
  else
    echo "  Missing:"
    for item in "${missing[@]}"; do
      echo "    - $item"
    done
  fi

  if [ "${#extra[@]}" -eq 0 ]; then
    echo "  Extra: none"
  else
    echo "  Extra:"
    for item in "${extra[@]}"; do
      echo "    - $item"
    done
  fi

  rm -f "$expected_file" "$actual_file"
}

echo "Pi install verification"
echo "Repo root: $REPO_ROOT"
echo "Pi agent dir: $PI_AGENT_DIR"

print_section "1) Repo-managed Pi extensions (copied into ~/.pi/agent/extensions; these do NOT appear in 'pi list')"
print_list "expected: " "${EXPECTED_REPO_EXTENSIONS[@]}"
print_list "installed: " "${INSTALLED_REPO_EXTENSIONS[@]}"
compare_lists "  Comparison:" EXPECTED_REPO_EXTENSIONS INSTALLED_REPO_EXTENSIONS

print_section "2) Package-managed Pi installs (registered via 'pi install'; these DO appear in 'pi list')"
print_list "expected git: " "${EXPECTED_GIT_PACKAGES[@]}"
print_list "expected npm: " "${EXPECTED_NPM_PACKAGES[@]}"
print_list "registered: " "${INSTALLED_PI_PACKAGES[@]}"
ALL_EXPECTED_PACKAGES=("${EXPECTED_GIT_PACKAGES[@]}" "${EXPECTED_NPM_PACKAGES[@]}")
compare_lists "  Comparison:" ALL_EXPECTED_PACKAGES INSTALLED_PI_PACKAGES

print_section "Quick checks"
echo "  Repo-managed extensions: find ~/.pi/agent/extensions -mindepth 1 -maxdepth 1 -printf '%f\\n' | sort"
echo "  Package-managed installs: pi list"
