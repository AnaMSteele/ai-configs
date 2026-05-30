#!/usr/bin/env python3
"""Launch /cmd:linear-build-workspace in a workspace-owned OpenCode session.

This is the automation bridge for root-repo invocations. OpenCode session
workspace ownership is fixed at creation time, so a command that starts in the
root repo cannot become workspace-owned by changing cwd. This helper creates or
reuses the workspace first, creates a session with both workspaceID and the
workspace directory, and sends the slash command there.
"""

from __future__ import annotations

import argparse
import json
import os
import socket
import subprocess
import sys
import tempfile
import urllib.parse
import urllib.error
import urllib.request
from base64 import b64encode
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPT_DIR))

from create_linear_workspace import find_server_url, issue_workspace_id, request_json, run  # noqa: E402


def auth_headers() -> dict[str, str]:
    password = os.environ.get("OPENCODE_SERVER_PASSWORD")
    if not password:
        return {}
    username = os.environ.get("OPENCODE_SERVER_USERNAME") or "opencode"
    token = b64encode(f"{username}:{password}".encode("utf-8")).decode("ascii")
    return {"authorization": f"Basic {token}"}


def post_json(url: str, body: dict, timeout: int = 120) -> dict:
    data = json.dumps(body).encode("utf-8")
    headers = {"content-type": "application/json", **auth_headers()}
    request = urllib.request.Request(url, data=data, headers=headers, method="POST")
    with urllib.request.urlopen(request, timeout=timeout) as response:
        payload = response.read().decode("utf-8")
        return json.loads(payload) if payload else {}


def fetch_issue(issue_key: str, output_dir: Path) -> dict:
    output_dir.mkdir(parents=True, exist_ok=True)
    issue_path = output_dir / f"{issue_key}.json"
    with issue_path.open("w") as handle:
        subprocess.run(
            [
                "ltui",
                "--format",
                "json",
                "--fields",
                "identifier,title,url,state,project",
                "issues",
                "view",
                issue_key,
                "--no-attachment-probe",
            ],
            text=True,
            stdout=handle,
            check=True,
        )
    return json.loads(issue_path.read_text())


def create_workspace(issue_key: str, title: str, base_ref: str, repo: str, server_url: str, output_dir: Path) -> dict:
    workspace_path = output_dir / f"{issue_key}-workspace.json"
    result = subprocess.run(
        [
            sys.executable,
            str(SCRIPT_DIR / "create_linear_workspace.py"),
            issue_key,
            "--base-ref",
            base_ref,
            "--title",
            title,
            "--repo",
            repo,
            "--server-url",
            server_url,
        ],
        text=True,
        capture_output=True,
        check=True,
    )
    workspace_path.write_text(result.stdout)
    return json.loads(result.stdout)


def create_session(server_url: str, workspace_id: str, workspace_dir: str, issue_key: str) -> dict:
    query = urllib.parse.urlencode({"directory": workspace_dir})
    url = f"{server_url}/session?{query}&workspace={urllib.parse.quote(workspace_id)}"
    body = {
        "title": f"Linear build {issue_key}",
        "workspaceID": workspace_id,
        "permission": {"edit": "allow", "bash": "allow", "webfetch": "allow"},
    }
    session = post_json(url, body)
    if session.get("workspaceID") != workspace_id or os.path.realpath(session.get("directory", "")) != os.path.realpath(workspace_dir):
        raise SystemExit(f"created misplaced session: {json.dumps(session, indent=2)}")
    return session


def send_command(server_url: str, session_id: str, workspace_id: str, workspace_dir: str, issue_key: str, base_ref: str) -> str:
    query = urllib.parse.urlencode({"directory": workspace_dir})
    command_url = f"{server_url}/session/{session_id}/command?{query}&workspace={urllib.parse.quote(workspace_id)}"
    body = {"command": "cmd:linear-build-workspace", "arguments": f"{issue_key} {base_ref}"}
    try:
        post_json(command_url, body, timeout=10)
        return "command"
    except urllib.error.HTTPError as exc:
        if exc.code not in {404, 405}:
            raise
        prompt_url = f"{server_url}/session/{session_id}/prompt_async?{query}&workspace={urllib.parse.quote(workspace_id)}"
        post_json(prompt_url, {"parts": [{"type": "text", "text": f"/cmd:linear-build-workspace {issue_key} {base_ref}"}]}, timeout=10)
        return "prompt_async"
    except TimeoutError:
        return "command_timeout_assumed_dispatched"
    except urllib.error.URLError as exc:
        if isinstance(exc.reason, (TimeoutError, socket.timeout)):
            return "command_timeout_assumed_dispatched"
        raise
    except socket.timeout:
        return "command_timeout_assumed_dispatched"


def main() -> int:
    parser = argparse.ArgumentParser(description="Launch a Linear build in a workspace-owned OpenCode session")
    parser.add_argument("issue_key")
    parser.add_argument("--base-ref", default="origin/develop")
    parser.add_argument("--repo", default=".")
    parser.add_argument("--server-url", default="")
    args = parser.parse_args()

    repo = run(["git", "rev-parse", "--show-toplevel"], cwd=args.repo)
    issue_key = args.issue_key.strip().upper()
    server_url = (args.server_url or find_server_url()).rstrip("/")
    output_dir = Path(tempfile.gettempdir()) / "opencode-linear-build" / issue_key

    issue = fetch_issue(issue_key, output_dir)
    workspace_payload = create_workspace(issue_key, issue.get("title", ""), args.base_ref, repo, server_url, output_dir)
    expected_workspace_id = issue_workspace_id(issue_key)
    workspace = workspace_payload.get("workspace", {}) if isinstance(workspace_payload.get("workspace"), dict) else {}
    actual_workspace_id = workspace.get("id") or workspace_payload.get("workspaceID")
    if actual_workspace_id != expected_workspace_id:
        raise SystemExit(f"workspace id mismatch: expected {expected_workspace_id}, got {actual_workspace_id}; payload={workspace_payload!r}")
    workspace_id = expected_workspace_id
    workspace_dir = workspace_payload.get("directory") or workspace.get("directory")
    if not workspace_dir:
        raise SystemExit(f"workspace payload missing directory: {workspace_payload!r}")

    session = create_session(server_url, workspace_id, workspace_dir, issue_key)
    dispatch = send_command(server_url, session["id"], workspace_id, workspace_dir, issue_key, args.base_ref)
    print(
        json.dumps(
            {
                "status": "launched",
                "issueKey": issue_key,
                "workspaceID": workspace_id,
                "directory": workspace_dir,
                "sessionID": session["id"],
                "dispatch": dispatch,
                "resume": f"Monitor session {session['id']} and ledger thoughts/runs for {issue_key}.",
            },
            indent=2,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
