#!/usr/bin/env python3
"""Generate a compact digest of recent OpenCode sessions for a directory.

This script is intentionally small and dependency-free. It uses the `opencode db`
command as the data source.

Typical usage:
  python3 scripts/opencode_conversation_digest.py --limit 10
  python3 scripts/opencode_conversation_digest.py --dir /path/to/repo --scope subtree
  python3 scripts/opencode_conversation_digest.py --format json
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from dataclasses import dataclass
from datetime import datetime
from typing import Any, Dict, List, Optional, Tuple


def _run(cmd: List[str]) -> str:
    p = subprocess.run(cmd, text=True, capture_output=True)
    if p.returncode != 0:
        raise RuntimeError(
            "Command failed: "
            + " ".join(cmd)
            + "\n\nstdout:\n"
            + (p.stdout or "")
            + "\n\nstderr:\n"
            + (p.stderr or "")
        )
    return p.stdout


def _git_toplevel() -> Optional[str]:
    try:
        out = _run(["git", "rev-parse", "--show-toplevel"]).strip()
        return out or None
    except Exception:
        return None


def _sql_quote(s: str) -> str:
    # SQLite string literal quoting.
    return "'" + s.replace("'", "''") + "'"


def _opencode_db(sql: str) -> List[Dict[str, Any]]:
    out = _run(["opencode", "db", sql, "--format", "json"])
    data = json.loads(out)
    if not isinstance(data, list):
        raise RuntimeError("Unexpected opencode db JSON output")
    return data


def _ms_to_iso(ms: Optional[int]) -> Optional[str]:
    if ms is None:
        return None
    try:
        return datetime.fromtimestamp(ms / 1000).isoformat(timespec="seconds")
    except Exception:
        return None


def _parse_json_maybe(s: Optional[str]) -> Optional[Dict[str, Any]]:
    if not s:
        return None
    try:
        v = json.loads(s)
    except Exception:
        return None
    if isinstance(v, dict):
        return v
    return None


def _single_row(sql: str) -> Optional[Dict[str, Any]]:
    rows = _opencode_db(sql)
    if not rows:
        return None
    return rows[0]


def _count(sql: str) -> int:
    row = _single_row(sql)
    if not row:
        return 0
    # Accept common aliases.
    for k in ("n", "count", "c"):
        if k in row:
            try:
                return int(row[k])
            except Exception:
                return 0
    # Fallback: first value.
    try:
        return int(next(iter(row.values())))
    except Exception:
        return 0


def _extract_part_text(part_data: Optional[str]) -> Optional[str]:
    obj = _parse_json_maybe(part_data)
    if not obj:
        return None
    if obj.get("type") != "text":
        return None
    text = obj.get("text")
    return text if isinstance(text, str) else None


def _first_line(s: str, max_len: int) -> str:
    one = (s or "").strip().splitlines()[0] if (s or "").strip() else ""
    if len(one) <= max_len:
        return one
    return one[: max_len - 1] + "…"


@dataclass
class SessionDigest:
    id: str
    directory: str
    title: str
    time_created: Optional[int]
    time_updated: Optional[int]
    time_archived: Optional[int]
    summary_files: Optional[int]
    summary_additions: Optional[int]
    summary_deletions: Optional[int]
    open_todos: int
    last_error: bool
    last_incomplete: bool
    first_user_text: Optional[str]
    last_assistant_text: Optional[str]

    def flags(self) -> List[str]:
        flags: List[str] = []
        if self.open_todos > 0:
            flags.append("open_todos")
        if self.last_error:
            flags.append("error")
        if self.last_incomplete:
            flags.append("incomplete")
        return flags


def _fetch_session_digests(
    target_dir: str, scope: str, limit: int
) -> List[SessionDigest]:
    target_dir = os.path.abspath(target_dir)
    dir_q = _sql_quote(target_dir)
    if scope == "exact":
        where = f"directory = {dir_q}"
    elif scope == "subtree":
        prefix_q = _sql_quote(target_dir.rstrip("/") + "/%")
        where = f"(directory = {dir_q} OR directory LIKE {prefix_q})"
    else:
        raise ValueError(f"Unknown scope: {scope}")

    sessions = _opencode_db(
        "\n".join(
            [
                "select",
                "  id, directory, title,",
                "  time_created, time_updated, time_archived,",
                "  summary_files, summary_additions, summary_deletions",
                "from session",
                f"where {where}",
                "order by time_created desc",
                f"limit {int(limit)}",
            ]
        )
    )

    digests: List[SessionDigest] = []

    for ses in sessions:
        sid = str(ses.get("id") or "")
        sdir = str(ses.get("directory") or "")
        title = str(ses.get("title") or "")
        sid_q = _sql_quote(sid)

        # Open todos (heuristic: anything not completed/cancelled).
        open_todos = _count(
            "\n".join(
                [
                    "select count(*) as n",
                    "from todo",
                    f"where session_id = {sid_q}",
                    "  and status not in ('completed', 'cancelled')",
                ]
            )
        )

        # Last message: detect error / incomplete.
        last_msg = _single_row(
            "\n".join(
                [
                    "select data",
                    "from message",
                    f"where session_id = {sid_q}",
                    "order by time_created desc",
                    "limit 1",
                ]
            )
        )
        last_msg_data = _parse_json_maybe(last_msg.get("data") if last_msg else None)
        last_error = bool(last_msg_data and last_msg_data.get("error"))

        time_obj = (
            last_msg_data.get("time") if isinstance(last_msg_data, dict) else None
        )
        last_incomplete = bool(
            isinstance(time_obj, dict)
            and time_obj.get("created")
            and ("completed" not in time_obj)
        )

        # First user text snippet.
        first_user_part = _single_row(
            "\n".join(
                [
                    "select part.data as part_data",
                    "from part",
                    "join message on message.id = part.message_id",
                    f"where part.session_id = {sid_q}",
                    '  and message.data like \'%"role":"user"%\'',
                    '  and part.data like \'%"type":"text"%\'',
                    "order by part.time_created asc",
                    "limit 1",
                ]
            )
        )
        first_user_text = _extract_part_text(
            first_user_part.get("part_data") if first_user_part else None
        )

        # Last assistant text snippet.
        last_asst_part = _single_row(
            "\n".join(
                [
                    "select part.data as part_data",
                    "from part",
                    "join message on message.id = part.message_id",
                    f"where part.session_id = {sid_q}",
                    '  and message.data like \'%"role":"assistant"%\'',
                    '  and part.data like \'%"type":"text"%\'',
                    "order by part.time_created desc",
                    "limit 1",
                ]
            )
        )
        last_assistant_text = _extract_part_text(
            last_asst_part.get("part_data") if last_asst_part else None
        )

        digests.append(
            SessionDigest(
                id=sid,
                directory=sdir,
                title=title,
                time_created=ses.get("time_created"),
                time_updated=ses.get("time_updated"),
                time_archived=ses.get("time_archived"),
                summary_files=ses.get("summary_files"),
                summary_additions=ses.get("summary_additions"),
                summary_deletions=ses.get("summary_deletions"),
                open_todos=open_todos,
                last_error=last_error,
                last_incomplete=last_incomplete,
                first_user_text=first_user_text,
                last_assistant_text=last_assistant_text,
            )
        )

    return digests


def _render_markdown(target_dir: str, scope: str, digests: List[SessionDigest]) -> str:
    lines: List[str] = []
    lines.append("# OpenCode Session Digest")
    lines.append("")
    lines.append(f"Target: `{os.path.abspath(target_dir)}`")
    lines.append(f"Scope: `{scope}`")
    lines.append(f"Generated: `{datetime.now().isoformat(timespec='seconds')}`")
    lines.append("")
    lines.append(f"Sessions: `{len(digests)}`")
    lines.append("")
    lines.append("## Recent Sessions")
    lines.append("")

    for s in digests:
        created = _ms_to_iso(s.time_created) or "?"
        changes = "files={files} +{add} -{deletions}".format(
            files=s.summary_files if s.summary_files is not None else "?",
            add=s.summary_additions if s.summary_additions is not None else "?",
            deletions=s.summary_deletions if s.summary_deletions is not None else "?",
        )
        flags = ",".join(s.flags()) if s.flags() else "-"
        lines.append(f"- `{created}` `{s.id}` {s.title}")
        lines.append(f"  - dir: `{s.directory}`")
        lines.append(f"  - changes: {changes}")
        lines.append(f"  - open_todos: `{s.open_todos}`")
        lines.append(f"  - flags: `{flags}`")

        if s.first_user_text:
            lines.append(
                f"  - first_user: {json.dumps(_first_line(s.first_user_text, 140))}"
            )
        if s.last_assistant_text:
            lines.append(
                f"  - last_assistant: {json.dumps(_first_line(s.last_assistant_text, 200))}"
            )

    lines.append("")
    lines.append("## Dangling Candidates")
    lines.append("")
    dangling = [s for s in digests if s.flags()]
    if not dangling:
        lines.append("- (none detected by heuristic)")
    else:
        for s in dangling:
            lines.append(
                f"- `{s.id}` flags={','.join(s.flags())} title={json.dumps(s.title)}"
            )

    return "\n".join(lines) + "\n"


def main(argv: List[str]) -> int:
    parser = argparse.ArgumentParser(
        description="Digest recent OpenCode sessions via opencode db"
    )
    parser.add_argument(
        "--dir", default=None, help="Target directory (default: git root or cwd)"
    )
    parser.add_argument(
        "--scope",
        choices=["exact", "subtree"],
        default="subtree",
        help="Match session.directory exactly or include subdirectories",
    )
    parser.add_argument(
        "--limit", type=int, default=10, help="Number of sessions to include"
    )
    parser.add_argument(
        "--format", choices=["md", "json"], default="md", help="Output format"
    )
    args = parser.parse_args(argv)

    target_dir = args.dir or _git_toplevel() or os.getcwd()
    try:
        digests = _fetch_session_digests(target_dir, args.scope, args.limit)
    except Exception as e:
        sys.stderr.write(str(e) + "\n")
        return 2

    if args.format == "json":
        payload: Dict[str, Any] = {
            "target": {"directory": os.path.abspath(target_dir), "scope": args.scope},
            "generated": datetime.now().isoformat(timespec="seconds"),
            "sessions": [
                {
                    "id": s.id,
                    "directory": s.directory,
                    "title": s.title,
                    "time_created": s.time_created,
                    "time_updated": s.time_updated,
                    "time_archived": s.time_archived,
                    "summary_files": s.summary_files,
                    "summary_additions": s.summary_additions,
                    "summary_deletions": s.summary_deletions,
                    "open_todos": s.open_todos,
                    "last_error": s.last_error,
                    "last_incomplete": s.last_incomplete,
                    "flags": s.flags(),
                    "first_user_text": s.first_user_text,
                    "last_assistant_text": s.last_assistant_text,
                }
                for s in digests
            ],
        }
        sys.stdout.write(json.dumps(payload, indent=2, sort_keys=False) + "\n")
        return 0

    sys.stdout.write(_render_markdown(target_dir, args.scope, digests))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
