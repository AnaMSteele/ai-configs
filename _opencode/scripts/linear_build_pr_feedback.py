#!/usr/bin/env python3
"""Fetch GitHub PR feedback and fail closed on remaining P1/P2 items.

This helper intentionally does not implement fixes. It creates a durable review
artifact whose first line can be recorded by linear_build_orchestrator.py.
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


STATE_BEGIN = "<!-- OPENCODE_LINEAR_BUILD_STATE_BEGIN -->"
STATE_END = "<!-- OPENCODE_LINEAR_BUILD_STATE_END -->"
SEVERITY_RE = re.compile(r"\b(p0|p1|p2|critical|blocker|must\s+fix|major)\b", re.IGNORECASE)
RESOLVED_FEEDBACK_RE = re.compile(r"^Resolved-Feedback:\s*(\S+)\s*$", re.MULTILINE)
NOISE_AUTHOR_RE = re.compile(r"^(github-actions(\[bot\])?|railway-app(\[bot\])?)$", re.IGNORECASE)
NOISE_BODY_RE = re.compile(r"\b(deploy|deployed|deployment|workflow|run details|preview|status)\b", re.IGNORECASE)


def run_json(args: list[str]) -> Any:
    result = subprocess.run(args, check=True, text=True, capture_output=True)
    text = result.stdout.strip()
    return json.loads(text) if text else None


def run_lines(args: list[str]) -> list[str]:
    result = subprocess.run(args, check=True, text=True, capture_output=True)
    return [line for line in result.stdout.splitlines() if line.strip()]


def read_ledger(path: Path) -> dict[str, Any]:
    text = path.read_text()
    start = text.find(STATE_BEGIN)
    end = text.find(STATE_END)
    if start == -1 or end == -1 or end < start:
        raise SystemExit(f"ledger is missing state markers: {path}")
    return json.loads(text[start + len(STATE_BEGIN) : end].strip())


def pr_from_ledger(path: Path) -> str:
    state = read_ledger(path)
    pr = state.get("pr", {}) if isinstance(state.get("pr"), dict) else {}
    if pr.get("url"):
        return str(pr["url"])
    for artifact in reversed(state.get("artifacts", [])):
        if artifact.get("stage") == "PR_CREATED" and str(artifact.get("path", "")).startswith("https://github.com/"):
            return str(artifact["path"])
    stage = state.get("stages", {}).get("PR_CREATED", {})
    for artifact in reversed(stage.get("artifacts", [])):
        if str(artifact).startswith("https://github.com/"):
            return str(artifact)
    raise SystemExit("could not resolve PR URL from ledger; pass --pr")


def parse_pr_url(value: str) -> tuple[str | None, int | None]:
    match = re.search(r"github\.com/([^/]+/[^/]+)/pull/(\d+)", value)
    if match:
        return match.group(1), int(match.group(2))
    if value.isdigit():
        return None, int(value)
    return None, None


def resolve_pr(args: argparse.Namespace) -> dict[str, Any]:
    pr_value = args.pr or (pr_from_ledger(Path(args.ledger)) if args.ledger else "")
    repo, number = parse_pr_url(pr_value) if pr_value else (None, None)
    repo = args.repo or repo

    view_cmd = ["gh", "pr", "view"]
    if pr_value:
        view_cmd.append(pr_value)
    if repo:
        view_cmd.extend(["--repo", repo])
    view_cmd.extend(["--json", "number,url,headRefOid,commits"])
    data = run_json(view_cmd)
    if not isinstance(data, dict):
        raise SystemExit("gh pr view did not return an object")

    if not repo:
        parsed_repo, _ = parse_pr_url(str(data.get("url", "")))
        repo = parsed_repo or str(run_json(["gh", "repo", "view", "--json", "nameWithOwner"]).get("nameWithOwner", ""))
    data["repo"] = repo
    data["number"] = int(data.get("number") or number or 0)
    commits = data.get("commits") or []
    data["lastPrCommitAt"] = commits[-1].get("committedDate") if commits else ""
    if not data["repo"] or not data["number"]:
        raise SystemExit("could not resolve PR repository and number")
    return data


def fetch_rest_items(repo: str, number: int) -> list[dict[str, Any]]:
    routes = [
        ("issue_comment", f"repos/{repo}/issues/{number}/comments?per_page=100"),
        ("review", f"repos/{repo}/pulls/{number}/reviews?per_page=100"),
        ("review_comment", f"repos/{repo}/pulls/{number}/comments?per_page=100"),
    ]
    items: list[dict[str, Any]] = []
    for source, route in routes:
        lines = run_lines(["gh", "api", "--paginate", route, "--jq", ".[] | @json"])
        for line in lines:
            raw = json.loads(line)
            user = raw.get("user") or {}
            items.append(
                {
                    "source": source,
                    "id": raw.get("id"),
                    "author": user.get("login", ""),
                    "createdAt": raw.get("submitted_at") or raw.get("created_at") or "",
                    "body": raw.get("body") or "",
                    "url": raw.get("html_url") or "",
                    "state": raw.get("state"),
                    "path": raw.get("path"),
                    "line": raw.get("line") or raw.get("original_line"),
                    "isResolved": None,
                    "isOutdated": None,
                }
            )
    return items


def fetch_review_threads(repo: str, number: int) -> list[dict[str, Any]]:
    owner, name = repo.split("/", 1)
    query = """
query($owner: String!, $name: String!, $number: Int!, $cursor: String) {
  repository(owner: $owner, name: $name) {
    pullRequest(number: $number) {
      reviewThreads(first: 100, after: $cursor) {
        pageInfo { hasNextPage endCursor }
        nodes {
          id
          isResolved
          isOutdated
          path
          line
          comments(first: 100) {
            nodes {
              id
              body
              url
              createdAt
              author { login }
            }
          }
        }
      }
    }
  }
}
"""
    cursor = None
    items: list[dict[str, Any]] = []
    while True:
        cmd = ["gh", "api", "graphql", "-f", f"query={query}", "-f", f"owner={owner}", "-f", f"name={name}", "-F", f"number={number}"]
        if cursor:
            cmd.extend(["-f", f"cursor={cursor}"])
        data = run_json(cmd)
        threads = data.get("data", {}).get("repository", {}).get("pullRequest", {}).get("reviewThreads", {})
        for thread in threads.get("nodes", []) or []:
            comments = thread.get("comments", {}).get("nodes", []) or []
            body = "\n\n".join(comment.get("body") or "" for comment in comments)
            latest = comments[-1] if comments else {}
            author = (latest.get("author") or {}).get("login", "") if isinstance(latest.get("author"), dict) else ""
            items.append(
                {
                    "source": "review_thread",
                    "id": thread.get("id"),
                    "author": author,
                    "createdAt": latest.get("createdAt") or "",
                    "body": body,
                    "url": latest.get("url") or "",
                    "state": None,
                    "path": thread.get("path"),
                    "line": thread.get("line"),
                    "isResolved": thread.get("isResolved"),
                    "isOutdated": thread.get("isOutdated"),
                }
            )
        page = threads.get("pageInfo") or {}
        if not page.get("hasNextPage"):
            break
        cursor = page.get("endCursor")
    return items


def severity(body: str) -> str:
    lowered = (body or "").lower()
    negated_severity = re.search(r"\b(no|not|without|didn['’]?t find any)\s+((p0|p1|p2)(\s*/\s*(p0|p1|p2))*|major|critical|blockers?|feedback|issues)", lowered)
    explicit_after_but = re.search(r"\bbut\b.*\b(p0|p1|p2|critical|blocker|must\s+fix|major)\b", lowered)
    if negated_severity and not explicit_after_but:
        return ""
    explicit = re.search(r"\b(p0|p1|p2|critical|blocker|must\s+fix)\b", body or "", re.IGNORECASE)
    if explicit:
        value = explicit.group(1).lower().replace(" ", "_")
        if value in {"p0", "p1", "critical", "blocker"}:
            return "P1"
        return "P2"
    if re.search(r"\b(no|not|without|didn['’]?t find any)\s+major\s+issues\b", lowered):
        return ""
    match = re.search(r"\bmajor\b", body or "", re.IGNORECASE)
    if not match:
        return ""
    return "P2"


def is_noise(item: dict[str, Any]) -> bool:
    author = str(item.get("author") or "")
    body = str(item.get("body") or "")
    author_lc = author.lower()
    if author_lc == "linear[bot]" and "linear-linkback" in body:
        return True
    if author_lc == "chatgpt-codex-connector[bot]" and not severity(body):
        return True
    return bool(NOISE_AUTHOR_RE.search(author) and NOISE_BODY_RE.search(body))


def fix_commit_is_in_head(commit: str, head_sha: str) -> bool:
    if not re.fullmatch(r"[0-9a-fA-F]{7,40}", commit.strip()) or not head_sha:
        return False
    result = subprocess.run(["git", "merge-base", "--is-ancestor", commit.strip(), head_sha], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return result.returncode == 0


def resolved_feedback_keys(head_sha: str = "") -> set[str]:
    keys: set[str] = set()
    for path in Path("thoughts/reviews").glob("pr-feedback-resolution-*.md"):
        text = path.read_text(errors="replace")
        first = text.splitlines()[0].strip() if text.splitlines() else ""
        fix_match = re.search(r"^Fix-Commit:\s*(\S+)\s*$", text, re.MULTILINE)
        if first != "PR_FEEDBACK_RESOLUTION" or "Resolution-Evidence:" not in text or "Validation-Evidence:" not in text or not fix_match:
            continue
        if not fix_commit_is_in_head(fix_match.group(1), head_sha):
            continue
        keys.update(match.group(1).strip() for match in RESOLVED_FEEDBACK_RE.finditer(text))
    return keys


def actionable_items(items: list[dict[str, Any]], cutoff: str, resolved_keys: set[str] | None = None) -> list[dict[str, Any]]:
    resolved_keys = resolved_keys or set()
    seen: set[str] = set()
    actionable: list[dict[str, Any]] = []
    for item in sorted(items, key=lambda value: str(value.get("createdAt") or ""), reverse=True):
        source = item.get("source")
        sev = severity(str(item.get("body") or ""))
        if source == "review" and item.get("state") == "CHANGES_REQUESTED" and not sev:
            sev = "P1"
        if not sev or is_noise(item):
            continue
        key = f"{source}:{item.get('id')}"
        if source == "review_thread":
            if item.get("isResolved") is True or item.get("isOutdated") is True:
                continue
            reason = "unresolved review thread"
        elif source == "review_comment":
            # GraphQL review threads carry resolution/outdated state for inline comments.
            # Do not let the raw REST copy keep a resolved thread blocking forever.
            continue
        else:
            if key in resolved_keys:
                continue
            reason = "GitHub review requested changes" if source == "review" and item.get("state") == "CHANGES_REQUESTED" else "newer than latest PR commit" if cutoff and str(item.get("createdAt") or "") > cutoff else "top-level feedback lacks resolution evidence"
        if key in seen:
            continue
        seen.add(key)
        copy = dict(item)
        copy["severity"] = sev
        copy["reason"] = reason
        actionable.append(copy)
    return actionable


def render_artifact(pr: dict[str, Any], items: list[dict[str, Any]], all_items: list[dict[str, Any]]) -> str:
    verdict = "PR_FEEDBACK_REQUIRED" if items else "PR_FEEDBACK_CLEAR"
    lines = [
        verdict,
        f"Checked-At: {datetime.now(timezone.utc).replace(microsecond=0).isoformat()}",
        f"PR: {pr.get('url', '')}",
        f"Head-SHA: {pr.get('headRefOid', '')}",
        f"Last-PR-Commit-At: {pr.get('lastPrCommitAt', '')}",
        "",
        "## Summary",
        f"- Remaining P1/P2 items: {len(items)}",
        f"- Total fetched feedback items: {len(all_items)}",
        "- Blocking criteria: severity marker P0/P1/P2/critical/blocker/major/must fix on unresolved, non-outdated review threads or top-level feedback that lacks a durable pr-feedback-resolution artifact.",
        "",
        "## Evidence",
        "Evidence: GitHub issue comments, PR reviews, inline review comments, and unresolved review threads fetched through gh REST and GraphQL APIs.",
        "",
    ]
    if items:
        lines.extend(["## Remaining P1/P2 Feedback", ""])
        for index, item in enumerate(items, start=1):
            body = " ".join(str(item.get("body") or "").split())[:700]
            location = f"{item.get('path')}:{item.get('line')}" if item.get("path") else "conversation"
            lines.extend(
                [
                    f"### {index}. {item.get('severity')} {item.get('source')} {item.get('id')}",
                    f"- Author: {item.get('author', '')}",
                    f"- Created: {item.get('createdAt', '')}",
                    f"- Location: {location}",
                    f"- Reason: {item.get('reason', '')}",
                    f"- URL: {item.get('url', '')}",
                    f"- Body: {body}",
                    "",
                ]
            )
    else:
        lines.extend(["## Remaining P1/P2 Feedback", "", "None.", ""])
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(description="Check PR feedback for unresolved/new P1/P2 items")
    parser.add_argument("--pr", default="", help="PR URL or number; defaults to the ledger PR_CREATED artifact or current branch")
    parser.add_argument("--repo", default="", help="GitHub owner/repo when --pr is a number or omitted")
    parser.add_argument("--ledger", default="", help="linear build ledger used to resolve PR URL")
    parser.add_argument("--output", required=True, help="artifact path to write; must not already exist")
    args = parser.parse_args()

    output = Path(args.output)
    if output.exists():
        raise SystemExit(f"refusing to overwrite existing artifact: {output}")
    output.parent.mkdir(parents=True, exist_ok=True)

    pr = resolve_pr(args)
    repo = str(pr["repo"])
    number = int(pr["number"])
    items = fetch_rest_items(repo, number) + fetch_review_threads(repo, number)
    remaining = actionable_items(items, str(pr.get("lastPrCommitAt") or ""), resolved_feedback_keys(str(pr.get("headRefOid") or "")))
    artifact = render_artifact(pr, remaining, items)
    output.write_text(artifact)
    print(str(output))
    return 2 if remaining else 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except subprocess.CalledProcessError as exc:
        sys.stderr.write(exc.stderr or exc.stdout or str(exc))
        raise SystemExit(exc.returncode) from exc
