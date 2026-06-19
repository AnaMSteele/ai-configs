#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PI_AGENT_DIR="${PI_AGENT_DIR:-${PI_CODING_AGENT_DIR:-$HOME/.pi/agent}}"
PI_EXT_DIR="$PI_AGENT_DIR/extensions"
PI_VCC_STABLE_PACKAGE="$PI_AGENT_DIR/local-packages/ai-configs/pi-vcc"

EXPECTED_GIT_PACKAGES=(
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

list_pi_model_entries() {
  local models_path="$1"
  if [ ! -f "$models_path" ]; then
    return
  fi

  python3 - "$models_path" <<'PY'
import json
import sys
from pathlib import Path

try:
    data = json.loads(Path(sys.argv[1]).read_text())
except Exception:
    raise SystemExit(0)

providers = data.get("providers")
if not isinstance(providers, dict):
    raise SystemExit(0)

for provider_id, provider in providers.items():
    if not isinstance(provider, dict):
        continue
    models = provider.get("models")
    if not isinstance(models, list):
        continue
    for model in models:
        if isinstance(model, dict) and isinstance(model.get("id"), str):
            print(f"{provider_id}/{model['id']}")
PY
}

EXPECTED_REPO_EXTENSIONS="$(cd "$REPO_ROOT" && list_find_entries "_pi/extensions")"
EXPECTED_LOCAL_PACKAGES="$PI_VCC_STABLE_PACKAGE"
LOCAL_PI_INTERACTIVE_SHELL="$(cd "$REPO_ROOT/../3p/pi-interactive-shell" 2>/dev/null && pwd || true)"
if [ -n "$LOCAL_PI_INTERACTIVE_SHELL" ]; then
  EXPECTED_LOCAL_PACKAGES="$EXPECTED_LOCAL_PACKAGES
$LOCAL_PI_INTERACTIVE_SHELL"
else
  EXPECTED_NPM_PACKAGES+=("git:github.com/adnichols/pi-interactive-shell")
fi
INSTALLED_REPO_EXTENSIONS="$(list_find_entries "$PI_EXT_DIR")"
EXPECTED_PI_MODELS="$(list_pi_model_entries "$REPO_ROOT/_pi/models.json")"
INSTALLED_PI_MODELS="$(list_pi_model_entries "$PI_AGENT_DIR/models.json")"
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

print_section "3) Repo-managed Pi model entries (merged into ~/.pi/agent/models.json; these do NOT appear in 'pi list')"
print_list "expected: " "$EXPECTED_PI_MODELS"
print_list "installed: " "$INSTALLED_PI_MODELS"
report_expected_vs_actual "  Comparison:" "$EXPECTED_PI_MODELS" "$INSTALLED_PI_MODELS" true

print_section "4) Quick checks"
echo "  Repo-managed extensions: find ~/.pi/agent/extensions -mindepth 1 -maxdepth 1 -exec basename {} \\; | sort"
echo "  Package-managed installs: pi list"
echo "  Repo-managed model entries: python3 -m json.tool ~/.pi/agent/models.json"

PI_VCC_REGISTERED="$(printf '%s\n' "$INSTALLED_PI_PACKAGES" | grep 'pi-vcc' || true)"
PI_VCC_COUNT="$(printf '%s\n' "$PI_VCC_REGISTERED" | sed '/^$/d' | wc -l | tr -d '[:space:]')"
if [ "$PI_VCC_COUNT" != "1" ]; then
  note_failure "expected exactly one registered pi-vcc package, found $PI_VCC_COUNT"
elif [ "$PI_VCC_REGISTERED" != "$PI_VCC_STABLE_PACKAGE" ]; then
  note_failure "registered pi-vcc path is not the stable mirror: $PI_VCC_REGISTERED"
fi

if [ -d "$PI_VCC_STABLE_PACKAGE" ]; then
  echo "  stable pi-vcc mirror: present"
else
  note_failure "stable pi-vcc mirror is missing: $PI_VCC_STABLE_PACKAGE"
fi

if [ -f "$PI_VCC_STABLE_PACKAGE/package.json" ]; then
  PI_VCC_PACKAGE_NAME="$(python3 - "$PI_VCC_STABLE_PACKAGE/package.json" <<'PY'
import json
import sys
from pathlib import Path
try:
    print(json.loads(Path(sys.argv[1]).read_text()).get("name", ""))
except Exception:
    print("")
PY
)"
  if [ "$PI_VCC_PACKAGE_NAME" = "@adnichols/pi-vcc" ]; then
    echo "  stable pi-vcc package name: @adnichols/pi-vcc"
  else
    note_failure "stable pi-vcc package.json has unexpected name: ${PI_VCC_PACKAGE_NAME:-missing}"
  fi
else
  note_failure "stable pi-vcc package.json is missing"
fi

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
