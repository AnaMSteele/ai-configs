#!/usr/bin/env python3
"""Conservative OpenCode server restart supervisor.

Inventories only sessions that are definitely active immediately before restart,
restarts configured OpenCode services, then posts a `continue` prompt only to the
captured sessions.
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import platform
import socket
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Any


ACTIVE_TYPES = {"busy", "retry"}


def now_id() -> str:
    return dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%SZ")


def expand(path: str) -> Path:
    return Path(path).expanduser().resolve()


def local_host_kind() -> str:
    hostname = socket.gethostname().lower()
    system = platform.system().lower()
    if "dever" in hostname or system == "linux":
        return "dever"
    if system == "darwin":
        return "mbp"
    return hostname.split(".")[0] or "unknown"


def default_targets() -> dict[str, dict[str, str]]:
    local = local_host_kind()
    mbp_local = local == "mbp"
    dever_local = local == "dever"
    return {
        "mbp": {
            "url": "http://127.0.0.1:63333" if mbp_local else "http://mbp:63333",
            "directory": "/Users/anichols/code",
            "restart": "launchctl kickstart -k gui/$(id -u)/com.anichols.opencode-web"
            if mbp_local
            else "ssh mbp 'launchctl kickstart -k gui/$(id -u)/com.anichols.opencode-web'",
        },
        "dever": {
            "url": "http://127.0.0.1:63333" if dever_local else "http://dever:63333",
            "directory": "/home/anichols/code",
            "restart": "systemctl --user restart opencode-web.service"
            if dever_local
            else "ssh dever 'systemctl --user restart opencode-web.service'",
        },
    }


def load_targets(config_path: Path) -> dict[str, dict[str, str]]:
    targets = default_targets()
    if config_path.exists():
        with config_path.open("r", encoding="utf-8") as f:
            data = json.load(f)
        for name, target in data.get("targets", {}).items():
            merged = dict(targets.get(name, {}))
            merged.update(target)
            targets[name] = merged
    return targets


def http_json(url: str, timeout: float, method: str = "GET", payload: Any | None = None) -> tuple[int, Any]:
    data = None
    headers = {"Accept": "application/json"}
    if payload is not None:
        data = json.dumps(payload).encode("utf-8")
        headers["Content-Type"] = "application/json"
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        raw = resp.read()
        if not raw:
            return resp.status, None
        return resp.status, json.loads(raw.decode("utf-8"))


def http_status(url: str, timeout: float) -> int:
    req = urllib.request.Request(url, method="GET")
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        resp.read()
        return resp.status


def target_url(target: dict[str, str], path: str, query: dict[str, str] | None = None) -> str:
    base = target["url"].rstrip("/")
    encoded = urllib.parse.urlencode(query or {})
    return f"{base}{path}" + (f"?{encoded}" if encoded else "")


def fetch_status(target: dict[str, str], timeout: float) -> dict[str, Any]:
    _code, body = http_json(target_url(target, "/session/status"), timeout)
    return body or {}


def fetch_sessions(target: dict[str, str], timeout: float) -> list[dict[str, Any]]:
    try:
        _code, body = http_json(
            target_url(target, "/experimental/session", {"limit": "500", "archived": "false"}),
            timeout,
        )
        if isinstance(body, list):
            return body
    except Exception:
        pass
    _code, body = http_json(
        target_url(target, "/session", {"directory": target["directory"], "limit": "500"}),
        timeout,
    )
    return body if isinstance(body, list) else []


def fetch_session(target: dict[str, str], session_id: str, timeout: float) -> dict[str, Any] | None:
    try:
        path_id = urllib.parse.quote(session_id, safe="")
        _code, body = http_json(target_url(target, f"/session/{path_id}"), timeout)
        return body if isinstance(body, dict) else None
    except Exception:
        return None


def active_ids(status: dict[str, Any]) -> set[str]:
    result: set[str] = set()
    for session_id, info in status.items():
        if isinstance(info, dict) and info.get("type") in ACTIVE_TYPES:
            result.add(session_id)
    return result


def build_inventory(target_names: list[str], targets: dict[str, dict[str, str]], args: argparse.Namespace) -> dict[str, Any]:
    inventory: dict[str, Any] = {
        "createdAt": dt.datetime.now(dt.timezone.utc).isoformat(),
        "sampleIntervalSeconds": args.sample_interval,
        "targets": {},
        "resumeCandidates": [],
    }
    for name in target_names:
        target = targets[name]
        entry: dict[str, Any] = {"target": target, "errors": [], "skipped": []}
        try:
            status1 = fetch_status(target, args.http_timeout)
            time.sleep(args.sample_interval)
            status2 = fetch_status(target, args.http_timeout)
            stable_active = sorted(active_ids(status1) & active_ids(status2))
            active_metadata: dict[str, Any] = {}
            entry.update({
                "statusSample1": status1,
                "statusSample2": status2,
                "sessionMetadataFallbackCount": 0,
                "stableActiveSessionIDs": stable_active,
                "activeSessionMetadata": active_metadata,
            })
            by_id: dict[str, Any] = {}
            for session_id in stable_active:
                session = fetch_session(target, session_id, args.http_timeout)
                if not session and not by_id:
                    sessions = fetch_sessions(target, args.http_timeout)
                    by_id = {item.get("id"): item for item in sessions if isinstance(item, dict) and item.get("id")}
                    entry["sessionMetadataFallbackCount"] = len(sessions)
                session = session or by_id.get(session_id)
                if not session:
                    entry["skipped"].append({"sessionID": session_id, "reason": "active-status-without-session-metadata"})
                    continue
                active_metadata[session_id] = session
                candidate = {
                    "targetName": name,
                    "serverUrl": target["url"],
                    "sessionID": session_id,
                    "directory": session.get("directory") or target["directory"],
                    "title": session.get("title"),
                    "statusSample1": status1.get(session_id),
                    "statusSample2": status2.get(session_id),
                    "time": session.get("time"),
                }
                inventory["resumeCandidates"].append(candidate)
        except Exception as exc:  # noqa: BLE001 - this is an operator log boundary
            entry["errors"].append(str(exc))
        inventory["targets"][name] = entry
    return inventory


def run_restart(name: str, target: dict[str, str], timeout: float) -> dict[str, Any]:
    command = target["restart"]
    started = time.time()
    try:
        proc = subprocess.run(
            command,
            shell=True,
            text=True,
            capture_output=True,
            timeout=timeout,
        )
        return {
            "targetName": name,
            "command": command,
            "returncode": proc.returncode,
            "stdout": proc.stdout,
            "stderr": proc.stderr,
            "durationSeconds": round(time.time() - started, 3),
        }
    except subprocess.TimeoutExpired as exc:
        return {
            "targetName": name,
            "command": command,
            "returncode": None,
            "stdout": exc.stdout,
            "stderr": exc.stderr,
            "durationSeconds": round(time.time() - started, 3),
            "error": "restart command timed out",
        }


def wait_for_health(name: str, target: dict[str, str], args: argparse.Namespace) -> dict[str, Any]:
    deadline = time.time() + args.health_timeout
    health_url = target_url(target, "/path", {"directory": target["directory"]})
    attempts = 0
    last_error = None
    while time.time() < deadline:
        attempts += 1
        try:
            status = http_status(health_url, args.http_timeout)
            if 200 <= status < 300:
                return {"targetName": name, "ok": True, "attempts": attempts, "status": status, "url": health_url}
            last_error = f"HTTP {status}"
        except Exception as exc:  # noqa: BLE001 - recorded for operator visibility
            last_error = str(exc)
        time.sleep(args.health_interval)
    return {"targetName": name, "ok": False, "attempts": attempts, "error": last_error, "url": health_url}


def resume_candidate(candidate: dict[str, Any], target: dict[str, str], args: argparse.Namespace) -> dict[str, Any]:
    session_id = candidate["sessionID"]
    path_id = urllib.parse.quote(session_id, safe="")
    url = target_url(target, f"/session/{path_id}/prompt_async")
    payload = {"parts": [{"type": "text", "text": args.resume_message}]}
    started = time.time()
    try:
        code, _body = http_json(url, args.resume_timeout, method="POST", payload=payload)
        return {
            "targetName": candidate["targetName"],
            "sessionID": session_id,
            "title": candidate.get("title"),
            "ok": 200 <= code < 300,
            "status": code,
            "durationSeconds": round(time.time() - started, 3),
        }
    except urllib.error.HTTPError as exc:
        return {
            "targetName": candidate["targetName"],
            "sessionID": session_id,
            "title": candidate.get("title"),
            "ok": False,
            "status": exc.code,
            "error": exc.read().decode("utf-8", "replace"),
            "durationSeconds": round(time.time() - started, 3),
        }
    except Exception as exc:  # noqa: BLE001 - recorded for operator visibility
        return {
            "targetName": candidate["targetName"],
            "sessionID": session_id,
            "title": candidate.get("title"),
            "ok": False,
            "error": str(exc),
            "durationSeconds": round(time.time() - started, 3),
        }


def write_json(path: Path, data: Any) -> None:
    path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def spawn_detached(args: argparse.Namespace, unknown: list[str]) -> int:
    run_root = expand(args.run_root)
    run_dir = expand(args.run_dir) if args.run_dir else run_root / now_id()
    run_dir.mkdir(parents=True, exist_ok=True)
    log_path = run_dir / "supervisor.log"
    child_args = [sys.executable, str(Path(__file__).resolve())]
    for item in sys.argv[1:]:
        if item != "--detach":
            child_args.append(item)
    if "--run-dir" not in child_args:
        child_args.extend(["--run-dir", str(run_dir)])
    child_args.extend(unknown)
    env = dict(os.environ)
    env["OPENCODE_SAFE_RESTART_CHILD"] = "1"
    with log_path.open("ab") as log:
        subprocess.Popen(
            child_args,
            stdin=subprocess.DEVNULL,
            stdout=log,
            stderr=subprocess.STDOUT,
            start_new_session=True,
            env=env,
        )
    print(f"OpenCode safe restart supervisor launched.")
    print(f"Run directory: {run_dir}")
    print(f"Log: {log_path}")
    return 0


def parse_args() -> tuple[argparse.Namespace, list[str]]:
    parser = argparse.ArgumentParser(description="Conservatively restart OpenCode servers and resume active sessions.")
    parser.add_argument("--targets", default="mbp,dever", help="Comma-separated targets to restart. Default: mbp,dever")
    parser.add_argument("--config", default="~/.config/opencode/safe-restart-targets.json")
    parser.add_argument("--run-root", default="~/.cache/opencode-safe-restart/runs")
    parser.add_argument("--run-dir", default="")
    parser.add_argument("--resume-message", default="continue")
    parser.add_argument("--sample-interval", type=float, default=1.0)
    parser.add_argument("--http-timeout", type=float, default=8.0)
    parser.add_argument("--restart-timeout", type=float, default=45.0)
    parser.add_argument("--health-timeout", type=float, default=90.0)
    parser.add_argument("--health-interval", type=float, default=2.0)
    parser.add_argument("--resume-timeout", type=float, default=20.0)
    parser.add_argument("--grace-seconds", type=float, default=0.0, help="Optional seconds to wait after inventory before restart.")
    parser.add_argument("--detach", action="store_true", help="Launch a detached supervisor and return immediately.")
    parser.add_argument("--dry-run", action="store_true", help="Inventory only; do not restart or resume.")
    return parser.parse_known_args()


def main() -> int:
    args, unknown = parse_args()
    if args.detach and os.environ.get("OPENCODE_SAFE_RESTART_CHILD") != "1":
        return spawn_detached(args, unknown)

    run_root = expand(args.run_root)
    run_dir = expand(args.run_dir) if args.run_dir else run_root / now_id()
    run_dir.mkdir(parents=True, exist_ok=True)
    config_path = expand(args.config)
    targets = load_targets(config_path)
    target_names = [name.strip() for name in args.targets.split(",") if name.strip()]
    missing = [name for name in target_names if name not in targets]
    if missing:
        raise SystemExit(f"Unknown target(s): {', '.join(missing)}")

    print(f"Run directory: {run_dir}")
    print(f"Targets: {', '.join(target_names)}")
    print("Sampling active OpenCode sessions...")
    inventory = build_inventory(target_names, targets, args)
    write_json(run_dir / "inventory.json", inventory)
    candidates = inventory["resumeCandidates"]
    print(f"Resume candidates captured: {len(candidates)}")

    summary: dict[str, Any] = {
        "runDir": str(run_dir),
        "dryRun": args.dry_run,
        "resumeCandidateCount": len(candidates),
        "restartResults": [],
        "healthResults": [],
        "resumeResults": [],
    }
    if args.dry_run:
        write_json(run_dir / "summary.json", summary)
        print("Dry run complete; no services restarted and no sessions resumed.")
        return 0

    if args.grace_seconds > 0:
        print(f"Inventory written. Waiting {args.grace_seconds:g}s before restart...")
        time.sleep(args.grace_seconds)

    print("Restarting OpenCode services...")
    for name in target_names:
        result = run_restart(name, targets[name], args.restart_timeout)
        summary["restartResults"].append(result)
        print(f"Restart {name}: returncode={result.get('returncode')} error={result.get('error', '')}")

    print("Waiting for OpenCode health checks...")
    healthy: dict[str, bool] = {}
    for name in target_names:
        result = wait_for_health(name, targets[name], args)
        summary["healthResults"].append(result)
        healthy[name] = bool(result.get("ok"))
        print(f"Health {name}: ok={result.get('ok')} attempts={result.get('attempts')}")

    print("Resuming captured sessions...")
    for candidate in candidates:
        name = candidate["targetName"]
        if not healthy.get(name):
            result = {
                "targetName": name,
                "sessionID": candidate["sessionID"],
                "title": candidate.get("title"),
                "ok": False,
                "error": "target health check failed; resume skipped",
            }
        else:
            result = resume_candidate(candidate, targets[name], args)
        summary["resumeResults"].append(result)
        print(f"Resume {name}/{candidate['sessionID']}: ok={result.get('ok')} error={result.get('error', '')}")

    write_json(run_dir / "summary.json", summary)
    print("OpenCode safe restart complete.")
    print(f"Summary: {run_dir / 'summary.json'}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
