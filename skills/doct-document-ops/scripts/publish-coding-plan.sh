#!/usr/bin/env bash
set -euo pipefail

DEFAULT_PARENT_TITLE="Coding Plans"

usage() {
  cat <<'EOF'
Usage: publish-coding-plan.sh [--file PATH] [--title TITLE] [--parent-title TITLE] [--workspace shared|SHARED_WORKSPACE_ID|slug|handle|name] [--json]

Registers a new HTML plan as a child of Coding Plans in the Shared doct workspace.

Input:
  --file PATH      Read a complete, standalone HTML document from PATH
  stdin            If --file is omitted, reads the HTML document from stdin

Defaults:
  --workspace      shared; any override must resolve to the Shared workspace
  --parent-title   Coding Plans
  --title          HTML <title>, else file basename, else timestamp
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
WORKSPACE_SELECTOR="${DOCT_WORKSPACE_SELECTOR:-shared}"
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
require_cmd perl

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
    echo "No input provided. Pass --file PATH or pipe a complete HTML plan on stdin." >&2
    exit 1
  fi
  cat > "$CONTENT_FILE"
fi

if [[ ! -s "$CONTENT_FILE" ]]; then
  echo "Plan content is empty." >&2
  exit 1
fi

if ! grep -Eiq '<!doctype[[:space:]]+html' "$CONTENT_FILE" || \
   ! grep -Eiq '<html([[:space:]>])' "$CONTENT_FILE" || \
   ! grep -Eiq '<head([[:space:]>])' "$CONTENT_FILE" || \
   ! grep -Eiq '<body([[:space:]>])' "$CONTENT_FILE"; then
  echo "Plan input must be a complete HTML document with <!doctype html>, <html>, <head>, and <body>. Markdown-only plans are not publishable; render the plan as HTML first." >&2
  exit 1
fi

if grep -Eiq '<script([[:space:]>])' "$CONTENT_FILE"; then
  echo "Plan HTML must not contain scripts." >&2
  exit 1
fi

if [[ -z "$TITLE" ]]; then
  TITLE="$(perl -0777 -ne 'if (/<title[^>]*>\s*(.*?)\s*<\/title>/is) { $t=$1; $t=~s/<[^>]+>//g; $t=~s/&amp;/\&/g; $t=~s/&lt;/</g; $t=~s/&gt;/>/g; $t=~s/\s+/ /g; print $t }' "$CONTENT_FILE")"
fi

if [[ -z "$TITLE" && -n "$FILE_PATH" ]]; then
  TITLE="$(basename "$FILE_PATH")"
  TITLE="${TITLE%.*}"
fi

if [[ -z "$TITLE" ]]; then
  TITLE="Plan $(date '+%Y-%m-%d %H:%M')"
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

WORKSPACES_JSON="$(doct-agent workspaces list ${BASE_URL_ARGS[@]+"${BASE_URL_ARGS[@]}"} --json)"

WORKSPACE_JSON="$(printf '%s' "$WORKSPACES_JSON" | jq -c --arg selector "$WORKSPACE_SELECTOR" '(.workspaces? // .) | map(select(.id == $selector or .slug == $selector or .handle == $selector or .name == $selector or .title == $selector)) | .[0] // empty')"

if [[ -z "$WORKSPACE_JSON" ]]; then
  echo "Could not resolve the Shared workspace from selector: $WORKSPACE_SELECTOR. Plan documents must not fall back to Personal." >&2
  exit 1
fi

IS_SHARED_WORKSPACE="$(printf '%s' "$WORKSPACE_JSON" | jq -r '((.isPersonal // .is_personal // false) == false) and (((.name // .title // "") | ascii_downcase) == "shared" or ((.slug // "") | ascii_downcase) == "shared" or ((.handle // "") | ascii_downcase | startswith("shared_")))')"
if [[ "$IS_SHARED_WORKSPACE" != "true" ]]; then
  RESOLVED_WORKSPACE_NAME="$(printf '%s' "$WORKSPACE_JSON" | jq -r '.name // .title // .slug // .handle // .id')"
  echo "Refusing to publish plan to non-Shared workspace: $RESOLVED_WORKSPACE_NAME. Use the Shared workspace." >&2
  exit 1
fi

WORKSPACE_ID="$(printf '%s' "$WORKSPACE_JSON" | jq -r '.id')"
WORKSPACE_HANDLE="$(printf '%s' "$WORKSPACE_JSON" | jq -r '.handle // .slug // .id')"

DOCS_JSON="$(doct-agent documents list ${BASE_URL_ARGS[@]+"${BASE_URL_ARGS[@]}"} --workspace-id "$WORKSPACE_ID" --json)"
PARENT_JSON="$(printf '%s' "$DOCS_JSON" | jq -c --arg title "$PARENT_TITLE" '(.documents? // .) | map(select(.title == $title and (.parentId == null or .parent_id == null))) | .[0] // empty')"

if [[ -z "$PARENT_JSON" ]]; then
  PARENT_JSON="$(doct-agent documents create ${BASE_URL_ARGS[@]+"${BASE_URL_ARGS[@]}"} \
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

REGISTER_JSON="$(doct-agent plans register ${BASE_URL_ARGS[@]+"${BASE_URL_ARGS[@]}"} \
  --workspace-id "$WORKSPACE_ID" \
  --title "$TITLE" \
  --file "$CONTENT_FILE" \
  --source-format html \
  --path "$CHILD_PATH" \
  --parent-id "$PARENT_ID" \
  --allow-untemplated \
  --json)"

if [[ "$OUTPUT_JSON" == true ]]; then
  printf '%s\n' "$REGISTER_JSON"
else
  CHILD_ID="$(printf '%s' "$REGISTER_JSON" | jq -r '.documentId // .document.id // .id // empty')"
  CHILD_URL="$(printf '%s' "$REGISTER_JSON" | jq -r '.canonicalUrl // .reviewUrl // .url // .document.url // empty')"
  echo "Registered doct HTML plan in Shared"
  echo "title: $TITLE"
  [[ -n "$CHILD_ID" ]] && echo "id: $CHILD_ID"
  echo "path: $CHILD_PATH"
  [[ -n "$CHILD_URL" ]] && echo "url: $CHILD_URL"
  echo "Registration includes plan listener instructions; rerun with --json to preserve them verbatim."
fi
