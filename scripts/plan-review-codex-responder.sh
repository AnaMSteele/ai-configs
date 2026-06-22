#!/usr/bin/env bash
set -euo pipefail

export PATH="/opt/homebrew/bin:/usr/local/bin:$HOME/.local/bin:$PATH"

REPO="${AI_CONFIGS_REPO:-/Users/anasteele/code/ai-configs}"
PLAN_REVIEW_SERVICE_URL="${PLAN_REVIEW_SERVICE_URL:-${PLAN_REVIEW_URL:-http://127.0.0.1:4317}}"
PLAN_REVIEW_BROWSER_URL="${PLAN_REVIEW_BROWSER_URL:-http://mbp.braid-python.ts.net:4317}"
REPO_KEY="${PLAN_REVIEW_REPO_KEY:-https://github.com/AnaMSteele/ai-configs.git}"
STATE_DIR="${PLAN_REVIEW_CODEX_STATE_DIR:-$HOME/.plan-reviewer/codex-responder}"
POLL_SECONDS="${PLAN_REVIEW_CODEX_POLL_SECONDS:-15}"
LEASE_SECONDS="${PLAN_REVIEW_CODEX_LEASE_SECONDS:-1800}"
CODEX_MODEL="${PLAN_REVIEW_CODEX_MODEL:-gpt-5.5}"
CODEX_IGNORE_USER_CONFIG="${PLAN_REVIEW_CODEX_IGNORE_USER_CONFIG:-1}"
CODEX_FULL_ACCESS="${PLAN_REVIEW_CODEX_FULL_ACCESS:-1}"
SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
PID_FILE="$STATE_DIR/responder.pid"
LOG_FILE="$STATE_DIR/responder.log"
LAUNCH_AGENT_LABEL="${PLAN_REVIEW_CODEX_LAUNCH_AGENT_LABEL:-com.anasteele.plan-review-codex-responder}"
LAUNCH_AGENT_PLIST="$HOME/Library/LaunchAgents/$LAUNCH_AGENT_LABEL.plist"

usage() {
  cat <<'USAGE'
Usage: plan-review-codex-responder.sh <start|stop|status|once|loop|install-service|uninstall-service>

Environment:
  AI_CONFIGS_REPO                 Repo to operate in. Default: /Users/anasteele/code/ai-configs
  PLAN_REVIEW_SERVICE_URL         Local plan-review API URL. Default: http://127.0.0.1:4317
  PLAN_REVIEW_BROWSER_URL         Human browser URL. Default: http://mbp.braid-python.ts.net:4317
  PLAN_REVIEW_REPO_KEY            Repo key to poll. Default: https://github.com/AnaMSteele/ai-configs.git
  PLAN_REVIEW_CODEX_STATE_DIR     Runtime logs/state directory. Default: ~/.plan-reviewer/codex-responder
  PLAN_REVIEW_CODEX_POLL_SECONDS  Poll interval for loop/start. Default: 15
  PLAN_REVIEW_CODEX_LEASE_SECONDS Claim lease duration. Default: 1800
  PLAN_REVIEW_CODEX_MODEL         Codex model. Default: gpt-5.5
  PLAN_REVIEW_CODEX_IGNORE_USER_CONFIG
                                  Set to 0 to let Codex load user config. Default: 1
  PLAN_REVIEW_CODEX_FULL_ACCESS   Set to 0 to use workspace-write. Default: 1
  PLAN_REVIEW_CODEX_LAUNCH_AGENT_LABEL
                                  LaunchAgent label. Default: com.anasteele.plan-review-codex-responder
USAGE
}

log() {
  mkdir -p "$STATE_DIR"
  printf '%s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" | tee -a "$LOG_FILE" >&2
}

on_error() {
  local status="$1"
  local line="$2"
  log "exiting after error at line $line with status $status"
  exit "$status"
}

trap 'on_error "$?" "$LINENO"' ERR

ensure_ready() {
  command -v plan-review >/dev/null
  command -v codex >/dev/null
  command -v jq >/dev/null
  cd "$REPO"
  local origin_url
  origin_url="$(git remote get-url origin 2>/dev/null || true)"
  if [ "$origin_url" != "$REPO_KEY" ]; then
    echo "origin must be $REPO_KEY; found ${origin_url:-<missing>}" >&2
    return 1
  fi
  if ! curl -fsS "$PLAN_REVIEW_SERVICE_URL/health" >/dev/null; then
    echo "plan-review service is not healthy at $PLAN_REVIEW_SERVICE_URL" >&2
    return 1
  fi
}

pending_comment_json() {
  plan-review queue list --url "$PLAN_REVIEW_SERVICE_URL" --repo-key "$REPO_KEY" --limit 1 --json |
    jq -c '.items[]? | select(.status == "pending")' |
    head -n 1
}

claim_comment() {
  local plan_id="$1"
  local comment_id="$2"
  plan-review queue claim "$plan_id" \
    --url "$PLAN_REVIEW_SERVICE_URL" \
    --ids "$comment_id" \
    --lease-seconds "$LEASE_SECONDS" \
    --json
}

run_codex_for_claim() {
  local claim_file="$1"
  local output_file="$2"
  local prompt_file="$STATE_DIR/prompt-$(date -u +%Y%m%dT%H%M%SZ).md"

  cat >"$prompt_file" <<PROMPT
You are the Codex responder for a browser comment in the local plan-review tool.

Repository: $REPO
Plan-review service URL: $PLAN_REVIEW_SERVICE_URL
Plan-review browser URL: $PLAN_REVIEW_BROWSER_URL
Repo key: $REPO_KEY
Claim JSON: $claim_file

Rules:
- Read /Users/anasteele/AGENTS.md first, then this repo's AGENTS.md or CLAUDE.md if present.
- Follow this repo's ownership rules.
- Read the full plan file before editing it.
- Process exactly the claimed comment in the claim JSON; do not claim other comments.
- Use the comment anchor, heading path, quoted text, and body as evidence.
- Make the smallest correct plan/documentation change, if a change is needed.
- If no file change is needed, still acknowledge the comment with a clear note.
- This installed plan-review CLI may not have a visible reply command, so use ack/resolve metadata.
- Use the service URL for CLI calls and the browser URL for human-facing references.
- Acknowledge with: plan-review ack <commentId> --url "$PLAN_REVIEW_SERVICE_URL" --claim <claimId> --note ... --summary ... --changed-files ...
- Resolve only when the reviewer-visible issue is actually settled.
- If you modify the repo, commit and push to Ana's origin before finishing.
- If plan-review ack/resolve fails, release the claim and finish with a failing summary.
- Do not edit the plan-review SQLite database directly.
- Do not search package caches or unrelated dependency trees.
- Leave a concise final summary of what you did.
PROMPT

  local codex_args=(exec -C "$REPO" --add-dir "$STATE_DIR" -o "$output_file")
  if [ "$CODEX_FULL_ACCESS" != "0" ]; then
    codex_args+=(--dangerously-bypass-approvals-and-sandbox)
  else
    codex_args+=(--full-auto)
  fi
  if [ "$CODEX_IGNORE_USER_CONFIG" != "0" ]; then
    codex_args+=(--ignore-user-config)
  fi
  if [ -n "$CODEX_MODEL" ]; then
    codex_args=(-m "$CODEX_MODEL" "${codex_args[@]}")
  fi
  log "starting codex for claim file $claim_file"
  codex "${codex_args[@]}" <"$prompt_file"
}

process_once() {
  log "polling for comments"
  if ! ensure_ready; then
    log "readiness check failed for $REPO_KEY at $PLAN_REVIEW_SERVICE_URL"
    return 1
  fi
  mkdir -p "$STATE_DIR"

  local pending
  if ! pending="$(pending_comment_json)"; then
    log "queue list failed for $REPO_KEY at $PLAN_REVIEW_SERVICE_URL"
    return 1
  fi
  if [ -z "$pending" ]; then
    log "no pending comments for $REPO_KEY"
    return 0
  fi

  local plan_id comment_id
  plan_id="$(jq -r '.planId' <<<"$pending")"
  comment_id="$(jq -r '.id' <<<"$pending")"
  log "claiming comment $comment_id on plan $plan_id"

  local claim_file="$STATE_DIR/claim-$comment_id.json"
  local claim_output
  if ! claim_output="$(claim_comment "$plan_id" "$comment_id")"; then
    log "claim failed for $comment_id"
    return 1
  fi
  printf '%s\n' "$claim_output" >"$claim_file"

  local claim_id
  claim_id="$(jq -r '.claimed[0].claim.id // empty' "$claim_file")"
  if [ -z "$claim_id" ]; then
    log "claim response did not include claim id for $comment_id"
    return 1
  fi

  local output_file="$STATE_DIR/codex-$comment_id-$(date -u +%Y%m%dT%H%M%SZ).md"
  local codex_status=0
  run_codex_for_claim "$claim_file" "$output_file" || codex_status=$?
  if [ "$codex_status" -eq 0 ]; then
    log "codex completed for $comment_id; output: $output_file"
    return 0
  fi

  log "codex failed for $comment_id with status $codex_status; releasing claim $claim_id"
  plan-review release "$comment_id" \
    --url "$PLAN_REVIEW_SERVICE_URL" \
    --claim "$claim_id" \
    --reason "Codex responder failed; see $output_file" \
    --json >/dev/null || true
  return 1
}

loop_forever() {
  ensure_ready
  log "starting loop for repo $REPO_KEY"
  while true; do
    process_once || true
    sleep "$POLL_SECONDS"
  done
}

start_daemon() {
  mkdir -p "$STATE_DIR"
  if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
    echo "Responder already running with pid $(cat "$PID_FILE")"
    exit 0
  fi
  nohup "$SCRIPT_PATH" loop >>"$LOG_FILE" 2>&1 &
  echo $! >"$PID_FILE"
  echo "Started plan-review Codex responder with pid $(cat "$PID_FILE")"
  echo "Log: $LOG_FILE"
}

stop_daemon() {
  if [ ! -f "$PID_FILE" ]; then
    echo "Responder is not running."
    return 0
  fi
  local pid
  pid="$(cat "$PID_FILE")"
  if kill -0 "$pid" 2>/dev/null; then
    kill "$pid"
    echo "Stopped responder pid $pid"
  else
    echo "Responder pid $pid is not active."
  fi
  rm -f "$PID_FILE"
}

status_daemon() {
  if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
    echo "running pid $(cat "$PID_FILE")"
  elif launchctl print "gui/$(id -u)/$LAUNCH_AGENT_LABEL" >/dev/null 2>&1; then
    echo "running via LaunchAgent $LAUNCH_AGENT_LABEL"
  else
    echo "not running"
  fi
  echo "log $LOG_FILE"
}

install_service() {
  ensure_ready
  mkdir -p "$STATE_DIR" "$(dirname "$LAUNCH_AGENT_PLIST")"
  cat >"$LAUNCH_AGENT_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$LAUNCH_AGENT_LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>$SCRIPT_PATH</string>
    <string>loop</string>
  </array>
  <key>WorkingDirectory</key>
  <string>$REPO</string>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
  <key>StandardOutPath</key>
  <string>$LOG_FILE</string>
  <key>StandardErrorPath</key>
  <string>$LOG_FILE</string>
</dict>
</plist>
PLIST
  launchctl bootout "gui/$(id -u)" "$LAUNCH_AGENT_PLIST" >/dev/null 2>&1 || true
  launchctl bootstrap "gui/$(id -u)" "$LAUNCH_AGENT_PLIST"
  launchctl kickstart -k "gui/$(id -u)/$LAUNCH_AGENT_LABEL"
  echo "Installed and started LaunchAgent $LAUNCH_AGENT_LABEL"
  echo "Plist: $LAUNCH_AGENT_PLIST"
  echo "Log: $LOG_FILE"
}

uninstall_service() {
  launchctl bootout "gui/$(id -u)" "$LAUNCH_AGENT_PLIST" >/dev/null 2>&1 || true
  rm -f "$LAUNCH_AGENT_PLIST"
  echo "Uninstalled LaunchAgent $LAUNCH_AGENT_LABEL"
}

case "${1:-}" in
  start) start_daemon ;;
  stop) stop_daemon ;;
  status) status_daemon ;;
  once) process_once ;;
  loop) loop_forever ;;
  install-service) install_service ;;
  uninstall-service) uninstall_service ;;
  -h|--help|help|"") usage ;;
  *)
    usage >&2
    exit 2
    ;;
esac
