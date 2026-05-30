#!/usr/bin/env python3
"""Create a Linear issue build workspace through OpenCode's workspace API.

This intentionally creates an OpenCode workspace, not only a git worktree. The
workspace row is what makes the build visible in OpenCode's workspace picker.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sqlite3
import subprocess
import sys
import time
import urllib.parse
import urllib.request
from base64 import b64encode
from pathlib import Path


class OpenCodeAPIError(Exception):
    def __init__(self, method: str, url: str, code: int, detail: str) -> None:
        self.method = method
        self.url = url
        self.code = code
        self.detail = detail
        super().__init__(f"OpenCode API request failed: {method} {url}\n{code}: {detail}")


def run(args: list[str], cwd: str | None = None, check: bool = True) -> str:
    proc = subprocess.run(args, cwd=cwd, text=True, capture_output=True)
    if check and proc.returncode != 0:
        detail = (proc.stderr or proc.stdout or "").strip()
        raise SystemExit(f"command failed: {' '.join(args)}\n{detail}")
    return proc.stdout.strip()


def slugify(value: str, limit: int = 42) -> str:
    slug = re.sub(r"[^a-z0-9]+", "-", value.lower()).strip("-")
    slug = re.sub(r"-+", "-", slug)
    return slug[:limit].strip("-")


def issue_workspace_id(issue_key: str) -> str:
    token = re.sub(r"[^a-z0-9]+", "_", issue_key.lower()).strip("_")
    if not token:
        raise SystemExit("issue key must contain at least one alphanumeric character")
    return f"wrk_{token}"


def find_server_url() -> str:
    explicit = os.environ.get("OPENCODE_SERVER_URL") or os.environ.get("OPENCODE_URL")
    if explicit:
        return explicit.rstrip("/")

    pid = os.environ.get("OPENCODE_PID")
    if not pid:
        raise SystemExit("OPENCODE_PID is not set; pass --server-url explicitly")

    output = run(["lsof", "-Pan", "-p", pid, "-iTCP", "-sTCP:LISTEN"])
    ports = re.findall(r"TCP\s+[^:]+:(\d+)\s+\(LISTEN\)", output)
    if not ports:
        raise SystemExit(f"could not discover OpenCode server port for PID {pid}")
    return f"http://127.0.0.1:{ports[0]}"


def request_json(url: str, method: str = "GET", body: dict | None = None) -> dict | list:
    data = None
    headers = {}
    password = os.environ.get("OPENCODE_SERVER_PASSWORD")
    if password:
        username = os.environ.get("OPENCODE_SERVER_USERNAME") or "opencode"
        token = b64encode(f"{username}:{password}".encode("utf-8")).decode("ascii")
        headers["authorization"] = f"Basic {token}"
    if body is not None:
        data = json.dumps(body).encode("utf-8")
        headers["content-type"] = "application/json"
    request = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(request, timeout=120) as response:
            payload = response.read().decode("utf-8")
            return json.loads(payload) if payload else {}
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="replace")
        raise OpenCodeAPIError(method, url, exc.code, detail) from exc


def opencode_db_path() -> str:
    return run(["opencode", "db", "path"])


def project_root_for_opencode(repo: str) -> str:
    repo_root = Path(run(["git", "rev-parse", "--show-toplevel"], cwd=repo)).resolve()
    common_dir_raw = run(["git", "rev-parse", "--path-format=absolute", "--git-common-dir"], cwd=str(repo_root))
    common_dir = Path(common_dir_raw).resolve()
    if common_dir.name == ".git" and common_dir.parent != repo_root:
        return str(common_dir.parent)
    return str(repo_root)


def update_workspace_branch(workspace_id: str, branch: str) -> None:
    db_path = opencode_db_path()
    with sqlite3.connect(db_path) as conn:
        conn.execute("update workspace set branch = ? where id = ?", (branch, workspace_id))
        conn.commit()


def find_workspace(workspaces: dict | list, workspace_id: str) -> dict | None:
    if not isinstance(workspaces, list):
        return None
    return next((item for item in workspaces if item.get("id") == workspace_id), None)


def workspace_from_db(workspace_id: str) -> dict | None:
    db_path = opencode_db_path()
    with sqlite3.connect(db_path) as conn:
        conn.row_factory = sqlite3.Row
        row = conn.execute(
            "select id,type,name,branch,directory,extra,project_id from workspace where id = ?",
            (workspace_id,),
        ).fetchone()
    if row is None:
        return None
    workspace = dict(row)
    if workspace.get("project_id"):
        workspace["projectID"] = workspace.pop("project_id")
    return workspace


def current_branch(directory: str) -> str:
    return run(["git", "branch", "--show-current"], cwd=directory)


def is_ignorable_command_scratch(directory: str, line: str) -> bool:
    """Allow the command's own temp files to exist before branch reconciliation."""
    if line == "?? .opencode/tmp/" or line.startswith("?? .opencode/tmp/"):
        return True
    if line != "?? .opencode/":
        return False

    opencode_dir = Path(directory) / ".opencode"
    if not opencode_dir.exists():
        return False
    files = [path for path in opencode_dir.rglob("*") if path.is_file()]
    return bool(files) and all(path.is_relative_to(opencode_dir / "tmp") for path in files)


def is_dirty(directory: str) -> bool:
    output = run(["git", "status", "--porcelain=v1"], cwd=directory, check=True)
    lines = [line for line in output.splitlines() if line]
    return any(not is_ignorable_command_scratch(directory, line) for line in lines)


def commits_ahead(directory: str, base_ref: str) -> int:
    output = run(["git", "rev-list", "--count", f"{base_ref}..HEAD"], cwd=directory, check=True)
    return int(output or "0")


def has_run_ledger(directory: str, issue_key: str) -> bool:
    for path in (Path(directory) / "thoughts/runs").glob("*.md"):
        text = path.read_text(errors="replace")
        if f'"key": "{issue_key.upper()}"' in text and str(Path(directory).resolve()) in text:
            return True
    return False


def assert_existing_workspace_safe(directory: str, base_ref: str, issue_key: str) -> None:
    if (is_dirty(directory) or commits_ahead(directory, base_ref) > 0) and not has_run_ledger(directory, issue_key):
        raise SystemExit(
            f"existing workspace {directory} has local work but no thoughts/runs ledger; "
            "refusing to reuse it for an autonomous Linear build"
        )


def reconcile_workspace_branch(repo_root: str, workspace: dict, workspace_id: str, desired_branch: str, no_branch_rename: bool) -> dict:
    directory = workspace.get("directory")
    if not directory:
        raise SystemExit(f"workspace {workspace_id} is missing directory")

    actual_branch = current_branch(directory)
    recorded_branch = workspace.get("branch") or actual_branch
    if no_branch_rename:
        if actual_branch != recorded_branch:
            raise SystemExit(
                f"workspace {workspace_id} branch mismatch: OpenCode records {recorded_branch!r}, "
                f"but git worktree is on {actual_branch!r}"
            )
        workspace["branch"] = recorded_branch
        return workspace
    if recorded_branch == desired_branch:
        if actual_branch != desired_branch:
            raise SystemExit(
                f"workspace {workspace_id} branch mismatch: OpenCode records {recorded_branch!r}, "
                f"but git worktree is on {actual_branch!r}"
            )
        workspace["branch"] = desired_branch
        return workspace

    if actual_branch == desired_branch:
        update_workspace_branch(workspace_id, desired_branch)
        workspace["branch"] = desired_branch
        return workspace

    # Only auto-reconcile OpenCode's generated branch names before product work starts.
    if not str(actual_branch).startswith("opencode/"):
        raise SystemExit(
            f"workspace {workspace_id} is on non-generated branch {actual_branch!r}; "
            f"refusing to rename to {desired_branch!r}"
        )
    if is_dirty(directory):
        raise SystemExit(
            f"workspace {workspace_id} has uncommitted changes on {actual_branch!r}; "
            f"refusing to rename to {desired_branch!r}"
        )
    branch_check = subprocess.run(
        ["git", "show-ref", "--verify", "--quiet", f"refs/heads/{desired_branch}"],
        cwd=repo_root,
    )
    if branch_check.returncode == 0:
        raise SystemExit(f"branch already exists: {desired_branch}")
    run(["git", "branch", "-m", desired_branch], cwd=directory)
    update_workspace_branch(workspace_id, desired_branch)
    workspace["branch"] = desired_branch
    return workspace


def reset_workspace_to_base(repo_root: str, directory: str, base_ref: str, allow_commits: bool = False) -> None:
    run(["git", "fetch", "--prune", "--tags"], cwd=repo_root)
    run(["git", "rev-parse", "--verify", f"{base_ref}^{{commit}}"], cwd=repo_root)
    if is_dirty(directory):
        raise SystemExit(f"workspace {directory} has uncommitted changes; refusing to reset to {base_ref!r}")
    ahead = commits_ahead(directory, base_ref)
    if ahead > 0 and not allow_commits:
        raise SystemExit(f"workspace {directory} has {ahead} commit(s) ahead of {base_ref!r}; refusing destructive reset")
    run(["git", "reset", "--hard", base_ref], cwd=directory)


def emit(status: str, workspace_id: str, workspace: dict, base_ref: str) -> None:
    print(
        json.dumps(
            {
                "status": status,
                "workspaceID": workspace_id,
                "directory": workspace.get("directory"),
                "branch": workspace.get("branch"),
                "baseRef": base_ref,
                "workspace": workspace,
            },
            indent=2,
        )
    )


def main() -> int:
    parser = argparse.ArgumentParser(description="Create an OpenCode workspace for a Linear issue build")
    parser.add_argument("issue_key", help="Linear issue key, e.g. NOD-123")
    parser.add_argument("--base-ref", default="origin/develop", help="base ref to reset the workspace branch to")
    parser.add_argument("--title", default="", help="Linear issue title for branch slugging")
    parser.add_argument("--repo", default=".", help="repository root or child path")
    parser.add_argument("--server-url", default="", help="OpenCode server URL; defaults to OPENCODE_PID discovery")
    parser.add_argument("--no-branch-rename", action="store_true", help="keep OpenCode-generated branch name")
    args = parser.parse_args()

    repo_root = project_root_for_opencode(args.repo)
    issue_key = args.issue_key.strip().upper()
    issue_lower = issue_key.lower()
    title_slug = slugify(args.title)
    branch_name = f"{issue_lower}-{title_slug}" if title_slug else issue_lower
    workspace_id = issue_workspace_id(issue_key)
    server_url = (args.server_url or find_server_url()).rstrip("/")
    query = urllib.parse.urlencode({"directory": repo_root})

    try:
        existing = request_json(f"{server_url}/experimental/workspace?{query}")
    except OpenCodeAPIError as exc:
        raise SystemExit(str(exc)) from exc
    workspace = find_workspace(existing, workspace_id)
    if workspace:
        workspace = reconcile_workspace_branch(repo_root, workspace, workspace_id, branch_name, args.no_branch_rename)
        run(["git", "fetch", "--prune", "--tags"], cwd=repo_root)
        run(["git", "rev-parse", "--verify", f"{args.base_ref}^{{commit}}"], cwd=repo_root)
        assert_existing_workspace_safe(workspace["directory"], args.base_ref, issue_key)
        emit("exists", workspace_id, workspace, args.base_ref)
        return 0

    post_query = urllib.parse.urlencode({"directory": repo_root, "workspace": workspace_id})
    post_url = f"{server_url}/experimental/workspace?{post_query}"
    try:
        workspace = request_json(
            post_url,
            method="POST",
            body={
                "id": workspace_id,
                "type": "worktree",
                "branch": None,
                "extra": {
                    "createdBy": "create_linear_workspace.py",
                    "issueKey": issue_key,
                    "issueTitle": args.title,
                    "baseRef": args.base_ref,
                },
            },
        )
    except OpenCodeAPIError as exc:
        # OpenCode may create the workspace row/worktree and still return a 500
        # while waiting for a UI event. Reconcile that exact partial success;
        # otherwise fail hard and preserve the original server error.
        time.sleep(0.5)
        try:
            refreshed_after_error = request_json(f"{server_url}/experimental/workspace?{query}")
            workspace = find_workspace(refreshed_after_error, workspace_id)
        except OpenCodeAPIError:
            workspace = None
        if not workspace:
            raise SystemExit(str(exc)) from exc
        workspace = reconcile_workspace_branch(repo_root, workspace, workspace_id, branch_name, args.no_branch_rename)
        reset_workspace_to_base(repo_root, workspace["directory"], args.base_ref, allow_commits=True)
        emit("recovered_after_api_error", workspace_id, workspace, args.base_ref)
        return 0
    if not isinstance(workspace, dict) or not workspace.get("directory"):
        raise SystemExit(f"unexpected OpenCode workspace response: {workspace!r}")

    directory = workspace["directory"]
    reset_workspace_to_base(repo_root, directory, args.base_ref, allow_commits=True)

    final_branch = workspace.get("branch") or branch_name
    if not args.no_branch_rename and branch_name != workspace.get("branch"):
        branch_check = subprocess.run(
            ["git", "show-ref", "--verify", "--quiet", f"refs/heads/{branch_name}"],
            cwd=repo_root,
        )
        if branch_check.returncode == 0:
            raise SystemExit(f"branch already exists: {branch_name}")
        run(["git", "branch", "-m", branch_name], cwd=directory)
        update_workspace_branch(workspace_id, branch_name)
        final_branch = branch_name

    # Give the server a moment to observe the DB/branch reconciliation before a
    # caller immediately asks the workspace list to refresh.
    time.sleep(0.2)
    refreshed = request_json(f"{server_url}/experimental/workspace?{query}")
    selected = None
    if isinstance(refreshed, list):
        selected = next((item for item in refreshed if item.get("id") == workspace_id), None)
    if selected is None:
        workspace["branch"] = final_branch

    emit("created", workspace_id, selected or workspace, args.base_ref)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
