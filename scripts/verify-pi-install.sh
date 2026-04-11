#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PI_AGENT_DIR="${PI_AGENT_DIR:-$HOME/.pi/agent}"
PI_EXT_DIR="$PI_AGENT_DIR/extensions"

EXPECTED_GIT_PACKAGES=(
  "git:github.com/pasky/chrome-cdp-skill"
  "git:github.com/adnichols/pi-rlm"
  "git:github.com/edxeth/pi-gpt-config"
)

EXPECTED_NPM_PACKAGES=(
  "npm:@tintinweb/pi-subagents"
  "npm:@aliou/pi-processes"
  "npm:pi-web-access"
  "npm:lsp-pi"
  "npm:@fnnm/pi-ast-grep"
  "npm:pi-updater"
  "npm:pi-powerline-footer"
  "npm:pi-side-agents"
  "npm:pi-multi-pass"
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

resolve_npm_global_prefix() {
  local prefix

  if prefix="$(npm prefix -g 2>/dev/null)" && [ -n "$prefix" ] && [ "$prefix" != "undefined" ] && [ "$prefix" != "null" ]; then
    printf '%s\n' "$prefix"
    return 0
  fi

  if prefix="$(npm config get prefix 2>/dev/null)" && [ -n "$prefix" ] && [ "$prefix" != "undefined" ] && [ "$prefix" != "null" ]; then
    printf '%s\n' "$prefix"
    return 0
  fi

  return 1
}

resolve_npm_global_root_dir() {
  local root

  if root="$(npm root -g 2>/dev/null)" && [ -n "$root" ] && [ "$root" != "undefined" ] && [ "$root" != "null" ]; then
    printf '%s\n' "$root"
    return 0
  fi

  return 1
}

resolve_npm_global_bin_dir() {
  local prefix="$1"

  if [ -z "$prefix" ]; then
    return 1
  fi

  case "$(uname -s 2>/dev/null || echo unknown)" in
    CYGWIN*|MINGW*|MSYS*)
      printf '%s\n' "$prefix"
      ;;
    *)
      printf '%s\n' "$prefix/bin"
      ;;
  esac
}

npm_global_prefix_is_writable() {
  local prefix="$1"
  [ -n "$prefix" ] && [ -d "$prefix" ] && [ -w "$prefix" ]
}

path_includes_dir() {
  local dir="$1"

  case ":$PATH:" in
    *":$dir:"*)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

lsp_pi_knows_bin_dir() {
  local bin_dir="$1"

  case "$bin_dir" in
    /usr/local/bin|/opt/homebrew/bin)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

lsp_pi_find_command() {
  local command_name="$1"
  local resolved
  local extra_dir

  if resolved="$(command -v "$command_name" 2>/dev/null)" && [ -n "$resolved" ] && [ -x "$resolved" ]; then
    printf '%s\n' "$resolved"
    return 0
  fi

  for extra_dir in \
    "/usr/local/bin" \
    "/opt/homebrew/bin" \
    "$HOME/.pub-cache/bin" \
    "$HOME/fvm/default/bin" \
    "$HOME/go/bin" \
    "$HOME/.cargo/bin"; do
    if [ -x "$extra_dir/$command_name" ]; then
      printf '%s\n' "$extra_dir/$command_name"
      return 0
    fi
  done

  return 1
}

npm_global_package_installed() {
  local npm_root="$1"
  local package_name="$2"
  [ -n "$npm_root" ] && [ -f "$npm_root/$package_name/package.json" ]
}

probe_version_command() {
  local command_path="$1"
  local label="$2"
  local output=""

  if output="$($command_path --version 2>&1)"; then
    if [ -n "$output" ]; then
      printf '  - %s probe: ok (%s)\n' "$label" "$(printf '%s' "$output" | head -n 1)"
    else
      printf '  - %s probe: ok (--version exited 0 with no output)\n' "$label"
    fi
    return 0
  fi

  printf '  - %s probe: failed\n' "$label"
  printf '%s\n' "$output" | sed 's/^/    /'
  return 1
}

probe_pyright_langserver() {
  local command_path="$1"
  local stdout_file stderr_file status

  stdout_file="$(mktemp)"
  stderr_file="$(mktemp)"

  if timeout 2s "$command_path" --stdio < /dev/null > "$stdout_file" 2> "$stderr_file"; then
    echo "  - Pyright language server probe: ok (--stdio accepted)"
    rm -f "$stdout_file" "$stderr_file"
    return 0
  else
    status=$?
  fi

  if [ "$status" -eq 1 ] && [ ! -s "$stderr_file" ]; then
    echo "  - Pyright language server probe: ok (--stdio accepted, process exited on EOF)"
    rm -f "$stdout_file" "$stderr_file"
    return 0
  fi

  echo "  - Pyright language server probe: failed"
  echo "    exit status: $status"
  if [ -s "$stderr_file" ]; then
    sed 's/^/    /' "$stderr_file"
  fi
  rm -f "$stdout_file" "$stderr_file"
  return 1
}

probe_curated_command() {
  local label="$1"
  local command_name="$2"
  local probe_kind="$3"
  local preflight_ok="$4"
  local resolved=""

  if resolved="$(lsp_pi_find_command "$command_name")"; then
    echo "  - $label: found at $resolved"
    case "$probe_kind" in
      version)
        probe_version_command "$resolved" "$label" || note_failure "$label exists but failed its executable smoke probe"
        ;;
      pyright-stdio)
        probe_pyright_langserver "$resolved" || note_failure "$label exists but failed its executable smoke probe"
        ;;
      *)
        note_failure "Unknown probe kind '$probe_kind' for $label"
        ;;
    esac
    return
  fi

  echo "  - $label: missing"
  if [ "$preflight_ok" = true ]; then
    note_failure "$label is not discoverable even though curated npm preflight passed"
  fi
}

print_unmanaged_status() {
  local label="$1"
  shift
  local command_name resolved=""

  for command_name in "$@"; do
    if resolved="$(lsp_pi_find_command "$command_name")"; then
      echo "  - $label: found via $command_name at $resolved"
      return
    fi
  done

  echo "  - $label: not found (informational only in Phase 1)"
}

EXPECTED_REPO_EXTENSIONS="$(cd "$REPO_ROOT" && list_find_entries "_pi/extensions")"
EXPECTED_LOCAL_PACKAGES="$(cd "$REPO_ROOT" && pwd)/_pi/packages/pi-vcc"
LOCAL_PI_INTERACTIVE_SHELL="$(cd "$REPO_ROOT/../3p/pi-interactive-shell" 2>/dev/null && pwd || true)"
if [ -n "$LOCAL_PI_INTERACTIVE_SHELL" ]; then
  EXPECTED_LOCAL_PACKAGES="$EXPECTED_LOCAL_PACKAGES
$LOCAL_PI_INTERACTIVE_SHELL"
else
  EXPECTED_NPM_PACKAGES+=("npm:pi-interactive-shell")
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
        case "$source" in
          npm:*|git:*)
            printf '%s\n' "$source"
            ;;
          *)
            python3 - "$source" <<'PY'
import os
import sys
print(os.path.realpath(sys.argv[1]))
PY
            ;;
        esac
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

print_section "3) Curated lsp-pi provisioning preflight + curated binary probes"
PRELIGHT_OK=true
NPM_PREFIX=""
NPM_ROOT=""
NPM_BIN=""

if command -v npm >/dev/null 2>&1; then
  if NPM_PREFIX="$(resolve_npm_global_prefix)"; then
    echo "  - npm global prefix: $NPM_PREFIX"
  else
    echo "  - npm global prefix: unresolved"
    PRELIGHT_OK=false
    note_failure "Could not resolve npm global prefix"
  fi

  if NPM_ROOT="$(resolve_npm_global_root_dir)"; then
    echo "  - npm global root: $NPM_ROOT"
  else
    echo "  - npm global root: unresolved"
    PRELIGHT_OK=false
    note_failure "Could not resolve npm global node_modules directory"
  fi

  if [ -n "$NPM_PREFIX" ] && NPM_BIN="$(resolve_npm_global_bin_dir "$NPM_PREFIX")"; then
    echo "  - npm global bin: $NPM_BIN"
  else
    echo "  - npm global bin: unresolved"
    PRELIGHT_OK=false
    note_failure "Could not resolve npm global bin directory"
  fi

  if [ -n "$NPM_PREFIX" ]; then
    if npm_global_prefix_is_writable "$NPM_PREFIX"; then
      echo "  - preflight: npm global prefix is writable without sudo"
    else
      echo "  - preflight: npm global prefix is not writable without sudo"
      PRELIGHT_OK=false
      note_failure "npm global prefix is not writable without sudo: $NPM_PREFIX"
    fi
  fi

  if [ -n "$NPM_BIN" ]; then
    if path_includes_dir "$NPM_BIN"; then
      echo "  - preflight: npm global bin is already on PATH"
    elif lsp_pi_knows_bin_dir "$NPM_BIN"; then
      echo "  - preflight: npm global bin is not on PATH, but current lsp-pi searches it explicitly"
    else
      echo "  - preflight: npm global bin is not discoverable by current lsp-pi search rules"
      echo "    remediation: ensure '$NPM_BIN' is on PATH or matches /usr/local/bin or /opt/homebrew/bin"
      PRELIGHT_OK=false
      note_failure "npm global bin is not discoverable by current lsp-pi search rules: $NPM_BIN"
    fi
  fi
else
  PRELIGHT_OK=false
  echo "  - npm: not found"
  note_failure "npm is required for curated lsp-pi provisioning checks"
fi

probe_curated_command "TypeScript language server" "typescript-language-server" "version" "$PRELIGHT_OK"
if npm_global_package_installed "$NPM_ROOT" "typescript"; then
  echo "  - TypeScript runtime fallback (typescript): present in npm global root"
else
  echo "  - TypeScript runtime fallback (typescript): missing"
  echo "    warning: TypeScript-family projects without a local workspace TypeScript install will have degraded fallback support"
fi
probe_curated_command "Vue language server" "vue-language-server" "version" "$PRELIGHT_OK"
probe_curated_command "Svelte language server" "svelteserver" "version" "$PRELIGHT_OK"
probe_curated_command "Pyright language server" "pyright-langserver" "pyright-stdio" "$PRELIGHT_OK"

print_section "4) Unmanaged informational server surface (reported only; does not affect exit status in Phase 1)"
print_unmanaged_status "Dart / Flutter" "dart"
print_unmanaged_status "Go" "gopls"
print_unmanaged_status "Kotlin" "kotlin-lsp" "kotlin-language-server"
print_unmanaged_status "Swift" "sourcekit-lsp" "xcrun"
print_unmanaged_status "Rust" "rust-analyzer"

print_section "Quick checks"
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
