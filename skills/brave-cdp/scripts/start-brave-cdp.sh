#!/usr/bin/env bash
set -euo pipefail

PROFILE_DIR="${BRAVE_CDP_PROFILE_DIR:-$HOME/.brave-cdp-profile}"
CDP_PORT="${BRAVE_CDP_PORT:-9222}"
PROFILE_NAME="${BRAVE_CDP_PROFILE_NAME:-Default}"
TARGET_URL=""
RESET_PROFILE=0
PRINT_ENV=0

usage() {
  cat <<EOF
Usage: $(basename "$0") [options] [url]

Starts a separate Brave instance configured for CDP automation.
Use this once to get the profile logged into the accounts you want the agent to use.

Options:
  --profile-dir PATH   Override profile directory (default: $PROFILE_DIR)
  --port PORT          Override remote debugging port (default: $CDP_PORT)
  --profile-name NAME  Profile subdir for DevToolsActivePort fallback (default: $PROFILE_NAME)
  --reset-profile      Delete the automation profile before launching
  --print-env          Print the export command for CDP_PORT_FILE and exit
  --help               Show this help

Environment:
  BRAVE_CDP_PROFILE_DIR   Default profile directory
  BRAVE_CDP_PORT          Default remote debugging port
  BRAVE_CDP_PROFILE_NAME  Fallback profile subdirectory name
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile-dir)
      PROFILE_DIR="$2"
      shift 2
      ;;
    --port)
      CDP_PORT="$2"
      shift 2
      ;;
    --profile-name)
      PROFILE_NAME="$2"
      shift 2
      ;;
    --reset-profile)
      RESET_PROFILE=1
      shift
      ;;
    --print-env)
      PRINT_ENV=1
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    --*)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
    *)
      if [[ -n "$TARGET_URL" ]]; then
        echo "Only one optional URL may be provided." >&2
        usage >&2
        exit 1
      fi
      TARGET_URL="$1"
      shift
      ;;
  esac
done

port_file() {
  if [[ -f "$PROFILE_DIR/DevToolsActivePort" ]]; then
    printf '%s\n' "$PROFILE_DIR/DevToolsActivePort"
  else
    printf '%s\n' "$PROFILE_DIR/$PROFILE_NAME/DevToolsActivePort"
  fi
}

synthesize_port_file() {
  local port_file="$1"

  python3 - "$CDP_PORT" "$port_file" <<'PY'
import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

port = sys.argv[1]
port_file = sys.argv[2]
url = f"http://127.0.0.1:{port}/json/version"
deadline = time.time() + 10
payload = None

while time.time() < deadline:
    try:
        with urllib.request.urlopen(url, timeout=1) as response:
            payload = json.load(response)
        break
    except (urllib.error.URLError, TimeoutError, json.JSONDecodeError):
        time.sleep(0.1)

if payload is None:
    raise SystemExit(1)

ws_url = payload.get("webSocketDebuggerUrl")
if not ws_url:
    raise SystemExit(1)

path = urllib.parse.urlparse(ws_url).path
if not path:
    raise SystemExit(1)

os.makedirs(os.path.dirname(port_file), exist_ok=True)
with open(port_file, "w", encoding="utf-8") as handle:
    handle.write(f"{port}\n{path}\n")
PY
}

if [[ "$PRINT_ENV" -eq 1 ]]; then
  printf 'export CDP_PORT_FILE=%q\n' "$(port_file)"
  exit 0
fi

if [[ "$RESET_PROFILE" -eq 1 ]]; then
  rm -rf "$PROFILE_DIR"
fi

mkdir -p "$PROFILE_DIR"

OPEN_ARGS=(
  -na "Brave Browser"
  --args
  --remote-debugging-port="$CDP_PORT"
  --user-data-dir="$PROFILE_DIR"
)

if [[ -n "$TARGET_URL" ]]; then
  OPEN_ARGS+=("$TARGET_URL")
fi

open "${OPEN_ARGS[@]}"

PORT_FILE="$(port_file)"
for _ in {1..100}; do
  if [[ -f "$PORT_FILE" ]]; then
    break
  fi
  sleep 0.1
done

if [[ ! -f "$PORT_FILE" ]]; then
  synthesize_port_file "$PORT_FILE"
fi

cat <<EOF
Brave automation profile started.

Profile dir: $PROFILE_DIR
Remote debugging port: $CDP_PORT
CDP_PORT_FILE: $PORT_FILE

Next steps:
1. Log into the accounts you want inside this Brave window.
2. In a shell, run:
   export CDP_PORT_FILE=$(printf '%q' "$PORT_FILE")
3. Use the skill:
   ~/.agents/skills/brave-cdp/scripts/cdp.mjs list
EOF
