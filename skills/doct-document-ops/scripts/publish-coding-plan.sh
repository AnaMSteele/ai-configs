#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_PATH="${HOME}/.config/doct-cli/config.json"
DEFAULT_PARENT_TITLE="Coding Plans"

usage() {
  cat <<'EOF'
Usage: publish-coding-plan.sh [--file PATH] [--title TITLE] [--parent-title TITLE] [--workspace personal|WORKSPACE_ID|slug|handle|name] [--json]

Creates a new doct text document as a child of the user's Coding Plans document.

Input:
  --file PATH      Read markdown from PATH
  stdin            If --file is omitted, reads markdown from stdin

Defaults:
  --workspace      personal
  --parent-title   Coding Plans
  --title          First H1 in the markdown, else file basename, else timestamp
EOF
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

json_post() {
  local endpoint="$1"
  local payload="$2"
  local response_file
  response_file="$(mktemp)"

  local status
  status=$(curl -sS -o "$response_file" -w '%{http_code}' -X POST "$endpoint" \
    -H "Authorization: Bearer ${DOCT_ACCESS_TOKEN}" \
    -H "X-Doct-Pat: Bearer ${DOCT_ACCESS_TOKEN}" \
    -H 'Content-Type: application/json' \
    -d "$payload")

  if [[ ! "$status" =~ ^2 ]]; then
    echo "Request failed: POST $endpoint -> HTTP $status" >&2
    cat "$response_file" >&2
    if [[ "$status" == "403" ]] && grep -q 'Required: write' "$response_file"; then
      echo >&2
      echo "Hint: doct-cli device login mints a read-only token. Set DOCT_ACCESS_TOKEN to a write-scope PAT (for example a write agent PAT) before publishing plans." >&2
    fi
    rm -f "$response_file"
    exit 1
  fi

  cat "$response_file"
  rm -f "$response_file"
}

FILE_PATH=""
TITLE=""
PARENT_TITLE="${DOCT_PARENT_TITLE:-$DEFAULT_PARENT_TITLE}"
WORKSPACE_SELECTOR="${DOCT_WORKSPACE_SELECTOR:-personal}"
OUTPUT_JSON=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --file)
      FILE_PATH="${2:-}"
      shift 2
      ;;
    --title)
      TITLE="${2:-}"
      shift 2
      ;;
    --parent-title)
      PARENT_TITLE="${2:-}"
      shift 2
      ;;
    --workspace)
      WORKSPACE_SELECTOR="${2:-}"
      shift 2
      ;;
    --json)
      OUTPUT_JSON=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

require_cmd jq
require_cmd curl
require_cmd bash

CONTENT_FILE="$(mktemp)"
cleanup() {
  rm -f "$CONTENT_FILE"
}
trap cleanup EXIT

if [[ -n "$FILE_PATH" ]]; then
  if [[ ! -f "$FILE_PATH" ]]; then
    echo "File not found: $FILE_PATH" >&2
    exit 1
  fi
  cp "$FILE_PATH" "$CONTENT_FILE"
else
  if [[ -t 0 ]]; then
    echo "No input provided. Pass --file PATH or pipe markdown on stdin." >&2
    exit 1
  fi
  cat > "$CONTENT_FILE"
fi

if [[ ! -s "$CONTENT_FILE" ]]; then
  echo "Plan content is empty." >&2
  exit 1
fi

if [[ -z "$TITLE" ]]; then
  TITLE="$( (grep -m1 -E '^# ' "$CONTENT_FILE" || true) | sed 's/^# //' )"
fi

if [[ -z "$TITLE" && -n "$FILE_PATH" ]]; then
  TITLE="$(basename "$FILE_PATH")"
  TITLE="${TITLE%.*}"
fi

if [[ -z "$TITLE" ]]; then
  TITLE="Coding Plan $(date '+%Y-%m-%d %H:%M')"
fi

if [[ -z "${DOCT_BASE_URL:-}" && -f "$CONFIG_PATH" ]]; then
  DOCT_BASE_URL="$(jq -r '.baseUrl // empty' "$CONFIG_PATH")"
fi
if [[ -z "${DOCT_ACCESS_TOKEN:-}" && -f "$CONFIG_PATH" ]]; then
  DOCT_ACCESS_TOKEN="$(jq -r '.token // empty' "$CONFIG_PATH")"
fi

: "${DOCT_BASE_URL:?Set DOCT_BASE_URL or login with doct-cli first}"
: "${DOCT_ACCESS_TOKEN:?Set DOCT_ACCESS_TOKEN or login with doct-cli first}"

doct-cli auth status >/dev/null

WORKSPACES_JSON="$(doct-cli workspaces list --json)"

if [[ "$WORKSPACE_SELECTOR" == "personal" ]]; then
  WORKSPACE_JSON="$(printf '%s' "$WORKSPACES_JSON" | jq -c 'map(select(.isPersonal == true)) | .[0] // empty')"
else
  WORKSPACE_JSON="$(printf '%s' "$WORKSPACES_JSON" | jq -c --arg selector "$WORKSPACE_SELECTOR" 'map(select(.id == $selector or .slug == $selector or .handle == $selector or .name == $selector)) | .[0] // empty')"
fi

if [[ -z "$WORKSPACE_JSON" ]]; then
  echo "Could not resolve workspace: $WORKSPACE_SELECTOR" >&2
  exit 1
fi

WORKSPACE_ID="$(printf '%s' "$WORKSPACE_JSON" | jq -r '.id')"
WORKSPACE_HANDLE="$(printf '%s' "$WORKSPACE_JSON" | jq -r '.handle')"

DOCS_JSON="$(doct-cli docs list --workspace "$WORKSPACE_ID" --json)"
PARENT_JSON="$(printf '%s' "$DOCS_JSON" | jq -c --arg title "$PARENT_TITLE" 'map(select(.title == $title and (.parentId == null))) | .[0] // empty')"

if [[ -z "$PARENT_JSON" ]]; then
  PARENT_PAYLOAD="$(jq -nc \
    --arg title "$PARENT_TITLE" \
    --arg kind "text" \
    --arg content "" \
    --arg workspaceId "$WORKSPACE_ID" \
    '{title: $title, kind: $kind, content: $content, workspaceId: $workspaceId}')"
  PARENT_JSON="$(json_post "$DOCT_BASE_URL/api/documents" "$PARENT_PAYLOAD")"
fi

PARENT_ID="$(printf '%s' "$PARENT_JSON" | jq -r '.id')"

CHILD_PAYLOAD="$(jq -nc \
  --arg title "$TITLE" \
  --arg kind "text" \
  --arg workspaceId "$WORKSPACE_ID" \
  --arg parentId "$PARENT_ID" \
  --rawfile content "$CONTENT_FILE" \
  '{title: $title, kind: $kind, content: $content, workspaceId: $workspaceId, parentId: $parentId}')"

CHILD_JSON="$(json_post "$DOCT_BASE_URL/api/documents" "$CHILD_PAYLOAD")"
CHILD_ID="$(printf '%s' "$CHILD_JSON" | jq -r '.id')"
CHILD_PATH="$(printf '%s' "$CHILD_JSON" | jq -r '.path')"
CHILD_URL="$DOCT_BASE_URL/d/$WORKSPACE_HANDLE/docs/$CHILD_ID"

RESULT_JSON="$(jq -nc \
  --arg workspaceId "$WORKSPACE_ID" \
  --arg workspaceHandle "$WORKSPACE_HANDLE" \
  --arg parentId "$PARENT_ID" \
  --arg parentTitle "$PARENT_TITLE" \
  --arg id "$CHILD_ID" \
  --arg title "$TITLE" \
  --arg path "$CHILD_PATH" \
  --arg url "$CHILD_URL" \
  '{workspaceId: $workspaceId, workspaceHandle: $workspaceHandle, parentId: $parentId, parentTitle: $parentTitle, id: $id, title: $title, path: $path, url: $url}')"

if [[ "$OUTPUT_JSON" == true ]]; then
  printf '%s\n' "$RESULT_JSON"
else
  echo "Created doct coding-plan document"
  echo "title: $TITLE"
  echo "id: $CHILD_ID"
  echo "path: $CHILD_PATH"
  echo "url: $CHILD_URL"
fi
