#!/usr/bin/env python3
"""Maintain and enforce a deterministic OpenCode Linear build ledger.

The ledger is a Markdown file with an embedded JSON state block. Humans can read
it; commands can enforce it. This helper is intentionally small: it does not
implement product work, but it makes stage transitions, exact artifact verdicts,
blockers, command logs, and resume state mechanical instead of advisory.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


STATE_BEGIN = "<!-- OPENCODE_LINEAR_BUILD_STATE_BEGIN -->"
STATE_END = "<!-- OPENCODE_LINEAR_BUILD_STATE_END -->"

STAGES = [
    "ISSUE_CAPTURE",
    "WORKSPACE_READY",
    "LEDGER_READY",
    "PLAN",
    "PLAN_GATES",
    "IMPLEMENTATION",
    "VALIDATION",
    "EVIDENCE",
    "CODE_REVIEW",
    "PM_REVIEW",
    "PR_READY",
    "PR_CREATED",
    "PR_FEEDBACK",
    "COMPLETE",
]

PASS_VERDICTS = {
    "PASS",
    "OPENCODE_PLAN_READY",
    "EXECUTION_READY",
    "VALIDATION_PASSED",
    "PM_ACCEPTABLE_FOR_CODE_REVIEW",
    "PM_ACCEPTABLE_FOR_IMPLEMENTATION",
    "CODE_REVIEW_ACCEPTABLE",
    "PR_FEEDBACK_CLEAR",
    "PR_READY",
    "PR_CREATED",
    "COMPLETE",
}

TERMINAL_BLOCKED_PREFIXES = ("BLOCKED_", "VALIDATION_FAILED", "PM_NOT_ACCEPTABLE", "CODE_REVIEW_BLOCKED")
RESEARCH_EVIDENCE_REQUIRED = {"BLOCKED_RESEARCH_OR_DECISION", "BLOCKED_BY_SCOPE_QUESTION"}
REQUIRED_ARTIFACT_PATTERNS = {
    "PLAN_GATES": ("codex-plan-review-", "claude-plan-review-"),
    "VALIDATION": ("opencode-validation-",),
    "CODE_REVIEW": ("codex-code-review-", "claude-code-review-"),
    "PM_REVIEW": ("pm-post-implementation-review-",),
    "PR_FEEDBACK": ("pr-feedback-",),
}
REVIEW_REVISION_STAGES = {"PLAN_GATES", "CODE_REVIEW", "PM_REVIEW"}
LOOP_LIMIT_STAGES = {"CODE_REVIEW", "PM_REVIEW", "PR_FEEDBACK"}
MAX_REMEDIATION_LOOPS = 3


def now() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat()


def slugify(value: str, limit: int = 80) -> str:
    slug = re.sub(r"[^a-z0-9]+", "-", value.lower()).strip("-")
    slug = re.sub(r"-+", "-", slug)
    return slug[:limit].strip("-") or "linear-build"


def default_ledger_path(issue_key: str, title: str) -> Path:
    return Path("thoughts/runs") / f"{issue_key.lower()}-{slugify(title, 48)}.md"


def read_state(path: Path) -> dict[str, Any]:
    if not path.exists():
        raise SystemExit(f"ledger does not exist: {path}")
    text = path.read_text()
    start = text.find(STATE_BEGIN)
    end = text.find(STATE_END)
    if start == -1 or end == -1 or end < start:
        raise SystemExit(f"ledger is missing state markers: {path}")
    raw = text[start + len(STATE_BEGIN) : end].strip()
    try:
        return json.loads(raw)
    except json.JSONDecodeError as exc:
        raise SystemExit(f"ledger state JSON is invalid: {exc}") from exc


def write_state(path: Path, state: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    rendered = render_ledger(state)
    path.write_text(rendered)


def stage_index(stage: str) -> int:
    if stage not in STAGES:
        raise SystemExit(f"unknown stage {stage!r}; expected one of: {', '.join(STAGES)}")
    return STAGES.index(stage)


def is_pass(verdict: str) -> bool:
    if verdict == "PASS_WITH_CAVEAT":
        return False
    return verdict in PASS_VERDICTS or verdict.startswith("PASS_")


def run(args: list[str], check: bool = True) -> str:
    proc = subprocess.run(args, text=True, capture_output=True)
    if check and proc.returncode != 0:
        raise SystemExit(f"command failed: {' '.join(args)}\n{proc.stderr or proc.stdout}")
    return proc.stdout.strip()


def is_orchestration_artifact_path(path: str) -> bool:
    normalized = path.replace(os.sep, "/")
    return normalized.startswith("thoughts/reviews/") or normalized.startswith("thoughts/runs/")


def current_review_revision() -> str:
    hasher = hashlib.sha256()
    for cmd in (
        ["git", "rev-parse", "HEAD"],
        ["git", "diff", "--binary", "--", ".", ":(exclude)thoughts/reviews/**", ":(exclude)thoughts/runs/**"],
        ["git", "diff", "--binary", "--cached", "--", ".", ":(exclude)thoughts/reviews/**", ":(exclude)thoughts/runs/**"],
    ):
        hasher.update("\0".join(cmd).encode("utf-8"))
        hasher.update(b"\0")
        hasher.update(run(cmd, check=False).encode("utf-8", errors="replace"))
        hasher.update(b"\0")
    status_lines = [line for line in run(["git", "status", "--porcelain=v1", "--untracked-files=all"], check=False).splitlines() if not is_orchestration_artifact_path(line[3:])]
    hasher.update("git status --porcelain=v1 --untracked-files=all".encode("utf-8"))
    hasher.update(b"\0")
    hasher.update("\n".join(status_lines).encode("utf-8", errors="replace"))
    hasher.update(b"\0")
    for name in run(["git", "ls-files", "--others", "--exclude-standard"], check=False).splitlines():
        if is_orchestration_artifact_path(name):
            continue
        path = Path(name)
        hasher.update(name.encode("utf-8", errors="replace"))
        hasher.update(b"\0")
        if path.is_file():
            hasher.update(path.read_bytes())
        hasher.update(b"\0")
    return hasher.hexdigest()


def is_blocked(verdict: str) -> bool:
    return verdict.startswith(TERMINAL_BLOCKED_PREFIXES)


def require_prior_passes(state: dict[str, Any], next_stage: str) -> None:
    target = stage_index(next_stage)
    stages = state.get("stages", {})
    for stage in STAGES[:target]:
        entry = stages.get(stage)
        verdict = entry.get("verdict") if isinstance(entry, dict) else None
        if not verdict:
            raise SystemExit(f"cannot enter {next_stage}: missing verdict for prior stage {stage}")
        if not is_pass(verdict):
            raise SystemExit(f"cannot enter {next_stage}: prior stage {stage} verdict is {verdict}")
        if stage == "EVIDENCE":
            manual_status = (state.get("manualEvidence") or {}).get("status")
            if manual_status not in {"passed", "not_required"}:
                raise SystemExit(f"cannot enter {next_stage}: manual/native evidence status is {manual_status or 'missing'}")
        require_stage_artifacts(state, stage)
    require_validation_revision(state, next_stage)
    require_cross_stage_review_revision(state, next_stage)


def require_stage_artifacts(state: dict[str, Any], stage: str) -> None:
    patterns = REQUIRED_ARTIFACT_PATTERNS.get(stage)
    if not patterns:
        return
    artifacts = [item.get("path", "") for item in state.get("artifacts", []) if item.get("stage") == stage]
    missing = [pattern for pattern in patterns if not any(Path(path).name.startswith(pattern) for path in artifacts)]
    if missing:
        raise SystemExit(f"stage {stage} is missing required artifact(s): {', '.join(missing)}")
    latest_required = latest_required_artifacts(state, stage)
    for latest in latest_required:
        verdict = latest.get("verdict")
        pattern = latest.get("requiredPattern", "")
        if not verdict or not is_pass(verdict):
            raise SystemExit(f"stage {stage} required artifact {pattern} latest verdict is not passing: {verdict or 'missing'}")

    if stage in REVIEW_REVISION_STAGES:
        revisions = {item.get("reviewRevision") for item in latest_required}
        if any(not item.get("reviewRevision") for item in latest_required):
            raise SystemExit(f"stage {stage} required artifacts must all include Review-Revision")
        if len(revisions) != 1:
            raise SystemExit(f"stage {stage} required artifacts must share one Review-Revision; got {sorted(revisions) or ['missing']}")
    if stage == "VALIDATION":
        latest = latest_required[-1]
        if not latest.get("validationRevision"):
            raise SystemExit("VALIDATION artifact must include Validation-Revision")


def latest_required_artifacts(state: dict[str, Any], stage: str) -> list[dict[str, Any]]:
    patterns = REQUIRED_ARTIFACT_PATTERNS.get(stage) or ()
    latest_required = []
    for pattern in patterns:
        matching = [item for item in state.get("artifacts", []) if item.get("stage") == stage and Path(item.get("path", "")).name.startswith(pattern)]
        latest = dict(matching[-1])
        latest["requiredPattern"] = pattern
        latest_required.append(latest)
    return latest_required


def require_cross_stage_review_revision(state: dict[str, Any], next_stage: str) -> None:
    if stage_index(next_stage) < stage_index("PR_READY"):
        return
    review_artifacts = latest_required_artifacts(state, "CODE_REVIEW") + latest_required_artifacts(state, "PM_REVIEW")
    revisions = {item.get("reviewRevision") for item in review_artifacts}
    if any(not item.get("reviewRevision") for item in review_artifacts):
        raise SystemExit("CODE_REVIEW and PM_REVIEW artifacts must all include Review-Revision before PR readiness")
    if len(revisions) != 1:
        raise SystemExit(f"CODE_REVIEW and PM_REVIEW artifacts must share one Review-Revision before PR readiness; got {sorted(revisions)}")
    current_revision = current_review_revision()
    if current_revision not in revisions:
        raise SystemExit("current implementation revision does not match latest CODE_REVIEW/PM_REVIEW Review-Revision; rerun review gates")


def require_validation_revision(state: dict[str, Any], next_stage: str) -> None:
    if stage_index(next_stage) < stage_index("CODE_REVIEW"):
        return
    latest = latest_required_artifacts(state, "VALIDATION")[-1]
    validation_revision = latest.get("validationRevision")
    if not validation_revision:
        raise SystemExit("VALIDATION artifact must include Validation-Revision before review/PR stages")
    if validation_revision != current_review_revision():
        raise SystemExit("current implementation revision does not match latest VALIDATION artifact; rerun validation")


def load_workspace_json(path: Path) -> dict[str, Any]:
    try:
        data = json.loads(path.read_text())
    except Exception as exc:  # noqa: BLE001 - user-facing CLI error
        raise SystemExit(f"could not read workspace JSON {path}: {exc}") from exc
    workspace = data.get("workspace") if isinstance(data, dict) else None
    return {
        "id": data.get("workspaceID") or (workspace or {}).get("id"),
        "directory": data.get("directory") or (workspace or {}).get("directory"),
        "branch": data.get("branch") or (workspace or {}).get("branch"),
        "baseRef": data.get("baseRef"),
        "status": data.get("status"),
    }


def init(args: argparse.Namespace) -> int:
    ledger = Path(args.ledger) if args.ledger else default_ledger_path(args.issue_key, args.title)
    if ledger.exists():
        read_state(ledger)
        print(str(ledger))
        return 0
    workspace = load_workspace_json(Path(args.workspace_json))
    missing = [key for key in ("id", "directory", "branch") if not workspace.get(key)]
    if missing:
        raise SystemExit(f"workspace JSON missing required fields: {', '.join(missing)}")
    state = {
        "version": 1,
        "createdAt": now(),
        "updatedAt": now(),
        "issue": {
            "key": args.issue_key.upper(),
            "title": args.title,
            "url": args.url,
            "state": args.state,
            "project": args.project,
        },
        "workspace": workspace,
        "baseRef": args.base_ref or workspace.get("baseRef"),
        "currentStage": "LEDGER_READY",
        "planPath": args.plan_path or f"thoughts/plans/{args.issue_key.lower()}-{slugify(args.title, 48)}.md",
        "ledgerPath": str(ledger),
        "stages": {
            "ISSUE_CAPTURE": {"verdict": "PASS", "updatedAt": now(), "notes": ["Linear issue metadata captured."]},
            "WORKSPACE_READY": {"verdict": "PASS", "updatedAt": now(), "notes": ["OpenCode workspace is registered and selected as orchestration unit."]},
            "LEDGER_READY": {"verdict": "PASS", "updatedAt": now(), "notes": ["Durable run ledger initialized."]},
        },
        "artifacts": [],
        "commands": [],
        "blockers": [],
        "remediationLoops": {},
        "manualEvidence": {"required": False, "status": "not_assessed", "paths": [], "caveats": []},
        "pr": {"url": "", "head": "", "base": ""},
        "resume": f"Continue /cmd:linear-build-workspace {args.issue_key.upper()} {args.base_ref or workspace.get('baseRef') or 'origin/develop'} from {workspace.get('directory')}",
    }
    write_state(ledger, state)
    print(str(ledger))
    return 0


def record_stage(args: argparse.Namespace) -> int:
    path = Path(args.ledger)
    state = read_state(path)
    stage_index(args.stage)
    if args.enforce_prior:
        require_prior_passes(state, args.stage)
    if args.stage == "EVIDENCE" and is_pass(args.verdict):
        manual_status = (state.get("manualEvidence") or {}).get("status")
        if manual_status not in {"passed", "not_required"}:
            raise SystemExit(f"refusing EVIDENCE pass while manual/native evidence status is {manual_status or 'missing'}")
    entry = state.setdefault("stages", {}).setdefault(args.stage, {})
    existing_verdict = entry.get("verdict")
    if existing_verdict and not is_pass(existing_verdict) and is_pass(args.verdict) and not getattr(args, "from_artifact", False):
        raise SystemExit(
            f"refusing to overwrite {args.stage} verdict {existing_verdict} with {args.verdict} outside artifact-verdict; "
            "rerun the gated artifact review after remediation"
        )
    if getattr(args, "from_artifact", False) and args.stage in LOOP_LIMIT_STAGES and not is_pass(args.verdict):
        loops = state.setdefault("remediationLoops", {})
        loop_count = int(loops.get(args.stage, 0)) + 1
        loops[args.stage] = loop_count
        if loop_count > MAX_REMEDIATION_LOOPS:
            state.setdefault("blockers", []).append(
                {
                    "stage": args.stage,
                    "code": "BLOCKED_REVIEW_CONVERGENCE",
                    "note": f"{args.stage} exceeded {MAX_REMEDIATION_LOOPS} non-passing artifact cycles.",
                    "updatedAt": now(),
                }
            )
            args.verdict = "BLOCKED_REVIEW_CONVERGENCE"
            if args.note:
                args.note = f"{args.note} Review remediation loop limit exceeded."
            else:
                args.note = "Review remediation loop limit exceeded."
    entry["verdict"] = args.verdict
    entry["updatedAt"] = now()
    if args.artifact:
        entry.setdefault("artifacts", []).append(args.artifact)
        artifact_entry = {"stage": args.stage, "path": args.artifact, "verdict": args.verdict, "updatedAt": now()}
        if getattr(args, "review_revision", ""):
            artifact_entry["reviewRevision"] = args.review_revision
        if getattr(args, "validation_revision", ""):
            artifact_entry["validationRevision"] = args.validation_revision
        state.setdefault("artifacts", []).append(artifact_entry)
    if args.note:
        entry.setdefault("notes", []).append(args.note)
    state["currentStage"] = args.stage
    state["updatedAt"] = now()
    write_state(path, state)
    print(f"{args.stage}: {args.verdict}")
    if not is_pass(args.verdict):
        return 2
    return 0


def guard(args: argparse.Namespace) -> int:
    state = read_state(Path(args.ledger))
    require_prior_passes(state, args.next_stage)
    print(f"OK_TO_ENTER {args.next_stage}")
    return 0


def artifact_verdict(args: argparse.Namespace) -> int:
    artifact = Path(args.artifact)
    if not artifact.exists():
        raise SystemExit(f"artifact does not exist: {artifact}")
    artifact_text = artifact.read_text(errors="replace")
    first = artifact_text.splitlines()[0].strip() if artifact_text.splitlines() else ""
    if first not in args.expect:
        raise SystemExit(f"artifact verdict mismatch for {artifact}: got {first!r}, expected one of {args.expect}")
    if not is_pass(first) and "Evidence:" not in artifact_text and "Research evidence:" not in artifact_text:
        raise SystemExit(f"non-passing verdict {first} in {artifact} requires an Evidence: section")
    review_revision = ""
    for line in artifact_text.splitlines()[1:6]:
        if line.startswith("Review-Revision:"):
            review_revision = line.split(":", 1)[1].strip()
            break
    if args.stage in REVIEW_REVISION_STAGES and not review_revision:
        raise SystemExit(f"artifact {artifact} is missing Review-Revision")
    validation_revision = current_review_revision() if args.stage == "VALIDATION" else ""
    stage_args = argparse.Namespace(
        ledger=args.ledger,
        stage=args.stage,
        verdict=first,
        artifact=str(artifact),
        note=args.note or f"Accepted artifact first-line verdict {first}.",
        enforce_prior=args.enforce_prior,
        from_artifact=True,
        review_revision=review_revision,
        validation_revision=validation_revision,
    )
    return record_stage(stage_args)


def log_command(args: argparse.Namespace) -> int:
    path = Path(args.ledger)
    state = read_state(path)
    state.setdefault("commands", []).append(
        {
            "stage": args.stage,
            "command": args.command,
            "result": args.result,
            "updatedAt": now(),
        }
    )
    state["updatedAt"] = now()
    write_state(path, state)
    print("COMMAND_LOGGED")
    return 0


def block(args: argparse.Namespace) -> int:
    path = Path(args.ledger)
    state = read_state(path)
    if args.code in RESEARCH_EVIDENCE_REQUIRED and not args.evidence:
        raise SystemExit(
            f"{args.code} requires --evidence with a research/review artifact. "
            "Resolve technical uncertainty from repo evidence before blocking on operator input."
        )
    blocker = {"stage": args.stage, "code": args.code, "note": args.note, "updatedAt": now()}
    if args.evidence:
        blocker["evidence"] = args.evidence
    state.setdefault("blockers", []).append(blocker)
    entry = state.setdefault("stages", {}).setdefault(args.stage, {})
    entry["verdict"] = args.code
    entry["updatedAt"] = now()
    entry.setdefault("notes", []).append(args.note)
    state["currentStage"] = args.stage
    state["updatedAt"] = now()
    write_state(path, state)
    print(args.code)
    return 2


def evidence(args: argparse.Namespace) -> int:
    path = Path(args.ledger)
    state = read_state(path)
    manual = state.setdefault("manualEvidence", {"required": False, "status": "not_assessed", "paths": [], "caveats": []})
    manual["required"] = args.required
    manual["status"] = args.status
    manual.setdefault("paths", []).extend(args.path or [])
    manual.setdefault("caveats", []).extend(args.caveat or [])
    state["updatedAt"] = now()
    write_state(path, state)
    print(f"EVIDENCE_STATUS {args.status}")
    return 0 if args.status in {"passed", "not_required"} else 2


def status(args: argparse.Namespace) -> int:
    state = read_state(Path(args.ledger))
    print(json.dumps({
        "issue": state.get("issue"),
        "workspace": state.get("workspace"),
        "currentStage": state.get("currentStage"),
        "stages": state.get("stages"),
        "blockers": state.get("blockers", []),
        "manualEvidence": state.get("manualEvidence"),
        "resume": state.get("resume"),
    }, indent=2))
    return 0


def render_ledger(state: dict[str, Any]) -> str:
    issue = state.get("issue", {})
    workspace = state.get("workspace", {})
    lines = [
        f"# Linear Build Run: {issue.get('key', '')} - {issue.get('title', '')}".rstrip(),
        "",
        "## Summary",
        f"- Issue: {issue.get('key', '')}",
        f"- URL: {issue.get('url', '')}",
        f"- State: {issue.get('state', '')}",
        f"- Project: {issue.get('project', '')}",
        f"- Workspace: {workspace.get('id', '')}",
        f"- Directory: {workspace.get('directory', '')}",
        f"- Branch: {workspace.get('branch', '')}",
        f"- Base ref: {state.get('baseRef', '')}",
        f"- Current stage: {state.get('currentStage', '')}",
        f"- Plan: {state.get('planPath', '')}",
        "",
        "## Stage Verdicts",
        "| Stage | Verdict | Updated |",
        "| --- | --- | --- |",
    ]
    stages = state.get("stages", {})
    for stage in STAGES:
        entry = stages.get(stage, {})
        lines.append(f"| {stage} | {entry.get('verdict', '')} | {entry.get('updatedAt', '')} |")
    lines.extend(["", "## Artifacts"])
    for artifact in state.get("artifacts", []):
        lines.append(f"- {artifact.get('stage')}: `{artifact.get('path')}` ({artifact.get('updatedAt')})")
    if not state.get("artifacts"):
        lines.append("- None yet")
    lines.extend(["", "## Command Log"])
    for command in state.get("commands", []):
        lines.append(f"- {command.get('stage')}: `{command.get('command')}` => {command.get('result')} ({command.get('updatedAt')})")
    if not state.get("commands"):
        lines.append("- None yet")
    lines.extend(["", "## Blockers"])
    for blocker in state.get("blockers", []):
        lines.append(f"- {blocker.get('stage')} {blocker.get('code')}: {blocker.get('note')} ({blocker.get('updatedAt')})")
    if not state.get("blockers"):
        lines.append("- None")
    manual = state.get("manualEvidence", {})
    lines.extend([
        "",
        "## Manual / Native Evidence",
        f"- Required: {manual.get('required')}",
        f"- Status: {manual.get('status')}",
    ])
    for path in manual.get("paths", []):
        lines.append(f"- Evidence path: `{path}`")
    for caveat in manual.get("caveats", []):
        lines.append(f"- Caveat: {caveat}")
    lines.extend([
        "",
        "## Resume Instructions",
        state.get("resume", ""),
        "",
        STATE_BEGIN,
        json.dumps(state, indent=2, sort_keys=True),
        STATE_END,
        "",
    ])
    return "\n".join(lines)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="OpenCode Linear build orchestration ledger helper")
    sub = parser.add_subparsers(dest="cmd", required=True)

    init_parser = sub.add_parser("init", help="initialize a run ledger from issue and workspace metadata")
    init_parser.add_argument("--issue-key", required=True)
    init_parser.add_argument("--title", required=True)
    init_parser.add_argument("--url", default="")
    init_parser.add_argument("--state", default="")
    init_parser.add_argument("--project", default="")
    init_parser.add_argument("--base-ref", default="origin/develop")
    init_parser.add_argument("--workspace-json", required=True)
    init_parser.add_argument("--ledger", default="")
    init_parser.add_argument("--plan-path", default="")
    init_parser.set_defaults(func=init)

    stage_parser = sub.add_parser("stage", help="record a stage verdict")
    stage_parser.add_argument("--ledger", required=True)
    stage_parser.add_argument("--stage", required=True)
    stage_parser.add_argument("--verdict", required=True)
    stage_parser.add_argument("--artifact", default="")
    stage_parser.add_argument("--note", default="")
    stage_parser.add_argument("--no-enforce-prior", dest="enforce_prior", action="store_false")
    stage_parser.set_defaults(func=record_stage, enforce_prior=True)

    guard_parser = sub.add_parser("guard", help="verify all prior stages passed before entering next stage")
    guard_parser.add_argument("--ledger", required=True)
    guard_parser.add_argument("--next-stage", required=True)
    guard_parser.set_defaults(func=guard)

    artifact_parser = sub.add_parser("artifact-verdict", help="read an artifact first line and record it as a stage verdict")
    artifact_parser.add_argument("--ledger", required=True)
    artifact_parser.add_argument("--stage", required=True)
    artifact_parser.add_argument("--artifact", required=True)
    artifact_parser.add_argument("--expect", action="append", required=True)
    artifact_parser.add_argument("--note", default="")
    artifact_parser.add_argument("--no-enforce-prior", dest="enforce_prior", action="store_false")
    artifact_parser.set_defaults(func=artifact_verdict, enforce_prior=True)

    command_parser = sub.add_parser("log-command", help="append a command/result entry")
    command_parser.add_argument("--ledger", required=True)
    command_parser.add_argument("--stage", required=True)
    command_parser.add_argument("--command", required=True)
    command_parser.add_argument("--result", required=True)
    command_parser.set_defaults(func=log_command)

    block_parser = sub.add_parser("block", help="record a blocking condition and stop")
    block_parser.add_argument("--ledger", required=True)
    block_parser.add_argument("--stage", required=True)
    block_parser.add_argument("--code", required=True)
    block_parser.add_argument("--note", required=True)
    block_parser.add_argument("--evidence", default="", help="research/review artifact proving the blocker is not answerable from available evidence")
    block_parser.set_defaults(func=block)

    evidence_parser = sub.add_parser("evidence", help="record manual/native evidence status")
    evidence_parser.add_argument("--ledger", required=True)
    evidence_parser.add_argument("--required", action="store_true")
    evidence_parser.add_argument("--status", choices=["not_required", "pending", "passed", "blocked", "failed"], required=True)
    evidence_parser.add_argument("--path", action="append")
    evidence_parser.add_argument("--caveat", action="append")
    evidence_parser.set_defaults(func=evidence)

    status_parser = sub.add_parser("status", help="print machine-readable status summary")
    status_parser.add_argument("--ledger", required=True)
    status_parser.set_defaults(func=status)

    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main())
