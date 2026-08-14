#!/usr/bin/env bash
set -euo pipefail

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
require_cmd bash
require_cmd doct-agent

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

BASE_URL_ARGS=()
AUTH_STATUS_ARGS=(--all)
if [[ -n "${DOCT_BASE_URL:-}" ]]; then
  BASE_URL_ARGS=(--base-url "$DOCT_BASE_URL")
  AUTH_STATUS_ARGS=(--base-url "$DOCT_BASE_URL")
fi

if ! doct-agent auth status "${AUTH_STATUS_ARGS[@]}" --json >/dev/null; then
  if [[ -n "${DOCT_BASE_URL:-}" ]]; then
    echo "Doct auth is not valid for ${DOCT_BASE_URL}. Run: doct-agent auth login --base-url ${DOCT_BASE_URL}" >&2
  else
    echo "Doct auth is not valid. Run: doct-agent auth status --all --json, then doct-agent auth login --base-url <endpoint>." >&2
  fi
  exit 1
fi

WORKSPACES_JSON="$(doct-agent workspaces list "${BASE_URL_ARGS[@]}" --json)"

if [[ "$WORKSPACE_SELECTOR" == "personal" ]]; then
  WORKSPACE_JSON="$(printf '%s' "$WORKSPACES_JSON" | jq -c '(.workspaces? // .) | map(select(.isPersonal == true or .is_personal == true)) | .[0] // empty')"
else
  WORKSPACE_JSON="$(printf '%s' "$WORKSPACES_JSON" | jq -c --arg selector "$WORKSPACE_SELECTOR" '(.workspaces? // .) | map(select(.id == $selector or .slug == $selector or .handle == $selector or .name == $selector or .title == $selector)) | .[0] // empty')"
fi

if [[ -z "$WORKSPACE_JSON" ]]; then
  echo "Could not resolve workspace: $WORKSPACE_SELECTOR" >&2
  exit 1
fi

WORKSPACE_ID="$(printf '%s' "$WORKSPACE_JSON" | jq -r '.id')"
WORKSPACE_HANDLE="$(printf '%s' "$WORKSPACE_JSON" | jq -r '.handle // .slug // .id')"

DOCS_JSON="$(doct-agent documents list "${BASE_URL_ARGS[@]}" --workspace-id "$WORKSPACE_ID" --json)"
PARENT_JSON="$(printf '%s' "$DOCS_JSON" | jq -c --arg title "$PARENT_TITLE" '(.documents? // .) | map(select(.title == $title and (.parentId == null or .parent_id == null))) | .[0] // empty')"

if [[ -z "$PARENT_JSON" ]]; then
  PARENT_JSON="$(doct-agent documents create "${BASE_URL_ARGS[@]}" \
    --workspace-id "$WORKSPACE_ID" \
    --title "$PARENT_TITLE" \
    --path "$PARENT_TITLE" \
    --kind text \
    --content "" \
    --json)"
fi

PARENT_ID="$(printf '%s' "$PARENT_JSON" | jq -r '.id')"
PARENT_PATH="$(printf '%s' "$PARENT_JSON" | jq -r --arg fallback "$PARENT_TITLE" '.path // $fallback')"
CHILD_PATH="${PARENT_PATH%/}/$TITLE"

CHILD_JSON="$(doct-agent documents create "${BASE_URL_ARGS[@]}" \
  --workspace-id "$WORKSPACE_ID" \
  --title "$TITLE" \
  --path "$CHILD_PATH" \
  --kind text \
  --content "" \
  --parent-id "$PARENT_ID" \
  --json)"
CHILD_ID="$(printf '%s' "$CHILD_JSON" | jq -r '.id')"
CHILD_PATH="$(printf '%s' "$CHILD_JSON" | jq -r --arg fallback "$CHILD_PATH" '.path // $fallback')"

doct-agent documents replace-body "${BASE_URL_ARGS[@]}" --id "$CHILD_ID" --file "$CONTENT_FILE" --json >/dev/null

BASE_URL_FOR_RESULT="${DOCT_BASE_URL:-$(doct-agent auth status --json | jq -r '.base_url // .default_base_url // empty')}"
CHILD_URL="$BASE_URL_FOR_RESULT/d/$WORKSPACE_HANDLE/docs/$CHILD_ID"

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
