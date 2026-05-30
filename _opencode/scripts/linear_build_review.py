#!/usr/bin/env python3
"""Run auditable Codex and Claude Code reviews for linear builds.

The linear build workflow requires two implementation reviewers: Codex and
Claude Code. This helper makes that requirement mechanical by invoking the
approved review paths and writing artifacts whose first line is the exact
ledger verdict.
"""

from __future__ import annotations

import argparse
import hashlib
import os
import re
import shlex
import subprocess
import sys
import tempfile
import time
from pathlib import Path


CODEX_WRAPPER = Path.home() / ".agents/skills/codex-review-partner/scripts/run-review.sh"
VERDICT_RE = re.compile(r"^\s*(?:VERDICT:\s*)?([A-Z][A-Z0-9_]+)\s*$", re.MULTILINE)

PLAN_ALLOWED = {"EXECUTION_READY", "PASS_NO_ISSUES", "BLOCKED_BY_SCOPE_QUESTION", "BLOCKED_RESEARCH_OR_DECISION"}
CODE_ALLOWED = {"CODE_REVIEW_ACCEPTABLE", "PASS_SCOPED", "PASS_NO_ISSUES", "CODE_REVIEW_BLOCKED", "FIX_IN_SCOPE_FINDINGS", "BLOCKED_BY_SCOPE_QUESTION"}
PM_ALLOWED = {"PM_ACCEPTABLE_FOR_CODE_REVIEW", "PM_NOT_ACCEPTABLE"}


def run(args: list[str], cwd: str | None = None, check: bool = True, timeout: int | None = None) -> str:
    proc = subprocess.run(args, cwd=cwd, text=True, capture_output=True, timeout=timeout)
    if check and proc.returncode != 0:
        raise SystemExit(f"command failed: {' '.join(args)}\n{proc.stderr or proc.stdout}")
    return proc.stdout.strip()


def changed_files(base_ref: str) -> str:
    merge_base = run(["git", "merge-base", "HEAD", base_ref])
    names: list[str] = []
    for cmd in (
        ["git", "diff", "--name-only", f"{merge_base}...HEAD"],
        ["git", "diff", "--name-only", "--cached"],
        ["git", "diff", "--name-only"],
        ["git", "ls-files", "--others", "--exclude-standard"],
    ):
        for name in run(cmd).splitlines():
            if name and name not in names:
                names.append(name)
    return "\n".join(names) or "No committed or working-tree diff yet; review the plan artifacts."


def build_prompt(kind: str, plan: str, issue_key: str, base_ref: str) -> str:
    files = changed_files(base_ref) if kind in {"code", "pm"} else plan
    if kind == "plan":
        return f"""Read-only plan review. Do not edit files.

Plan: {plan}
Issue: {issue_key}
Base ref: {base_ref}

Review whether the plan is execution-ready for the repo workflow. Check product intent alignment, BDD coverage, verification commands, native/manual evidence expectations, and unresolved decisions.

First line must be exactly one of:
EXECUTION_READY
PASS_NO_ISSUES
BLOCKED_BY_SCOPE_QUESTION
BLOCKED_RESEARCH_OR_DECISION

Then list findings with evidence. If the verdict is non-passing, include a literal `Evidence:` section. Do not ask the operator for technical questions that can be answered by reading Linear, repo docs, code, tests, specs, or bounded research.
"""
    if kind == "code":
        return f"""Read-only implementation review. Do not edit files.

Plan: {plan}
Issue: {issue_key}
Base/comparison: {base_ref}
Changed files:
{files}

Review only whether this diff correctly implements the plan. Classify every finding as exactly one of IN_PLAN, PLAN_PREREQUISITE, REGRESSION_FROM_THIS_DIFF, OUT_OF_SCOPE_FOLLOW_UP, or QUESTION.

First line must be exactly one of:
CODE_REVIEW_ACCEPTABLE
PASS_SCOPED
PASS_NO_ISSUES
CODE_REVIEW_BLOCKED
FIX_IN_SCOPE_FINDINGS
BLOCKED_BY_SCOPE_QUESTION

If the verdict is non-passing, include a literal `Evidence:` section. Do not recommend unrelated cleanup, broad audits, or scope expansion. Technical uncertainty must be resolved from the repo, tests, docs, specs, or focused research before using QUESTION.
"""
    return f"""Read-only PM/product implementation review. Do not edit files.

Plan: {plan}
Issue: {issue_key}
Base/comparison: {base_ref}
Changed files:
{files}

Review whether the implemented behavior satisfies the user-visible acceptance criteria and product intent without expanding scope. Focus on missed workflow outcomes, unsafe defaults, misleading evidence, and behavior gaps.

First line must be exactly one of:
PM_ACCEPTABLE_FOR_CODE_REVIEW
PM_NOT_ACCEPTABLE

If not acceptable, include a literal `Evidence:` section and list only concrete in-scope remediation needed to satisfy the plan. Do not ask the operator for technical questions that can be answered by repository research.
"""


def extract_verdict(output: str, allowed: set[str]) -> str:
    first = output.splitlines()[0].strip() if output.splitlines() else ""
    first = first.removeprefix("VERDICT:").strip()
    if first in allowed:
        return first
    raise SystemExit(f"review first line did not return an allowed verdict. Allowed={sorted(allowed)}\n\n{output[:4000]}")


def write_artifact(path: Path, verdict: str, output: str, reviewer: str) -> None:
    if path.exists():
        raise SystemExit(f"refusing to overwrite existing review artifact: {path}")
    path.write_text(f"{verdict}\nReview-Revision: {review_revision()}\nReviewer: {reviewer}\n\n{output.strip()}\n")


def review_revision() -> str:
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
    for name in run(["git", "ls-files", "--others", "--exclude-standard"]).splitlines():
        if is_orchestration_artifact_path(name):
            continue
        path = Path(name)
        hasher.update(name.encode("utf-8", errors="replace"))
        hasher.update(b"\0")
        if path.is_file():
            hasher.update(path.read_bytes())
        hasher.update(b"\0")
    return hasher.hexdigest()


def is_orchestration_artifact_path(path: str) -> bool:
    normalized = path.replace(os.sep, "/")
    return normalized.startswith("thoughts/reviews/") or normalized.startswith("thoughts/runs/")


def run_codex(prompt: str, cwd: str, output_path: Path, kind: str) -> str:
    if not CODEX_WRAPPER.exists():
        raise SystemExit(f"missing Codex review wrapper: {CODEX_WRAPPER}")
    prompt_path = output_path.with_suffix(".prompt.md")
    raw_path = output_path.with_suffix(".raw.md")
    prompt_path.write_text(prompt)
    mode = "plan-review" if kind == "plan" else "implementation-review"
    run([str(CODEX_WRAPPER), "--mode", mode, "--input", str(prompt_path), "--cwd", cwd, "--output", str(raw_path)], timeout=900)
    return raw_path.read_text(errors="replace")


def ensure_codex_tmux() -> None:
    if subprocess.run(["tmux", "has-session", "-t", "codex"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
        return
    subprocess.run(
        ["zellij", "--session", "main", "run", "--name", "codex-tmux-bootstrap", "--close-on-exit", "--", "/bin/zsh", "-ilc", "tmux new-session -d -s codex"],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        check=True,
    )


def run_claude(prompt: str, cwd: str, output_path: Path, issue_key: str, kind: str) -> str:
    ensure_codex_tmux()
    prompt_path = output_path.with_suffix(".prompt.md")
    raw_path = output_path.with_suffix(".raw.md")
    prompt_path.write_text(prompt)
    raw_path.unlink(missing_ok=True)
    window = f"claude-{kind.lower()}-{issue_key.lower()}"[:32]
    inner = f"claude -p \"$(< {shlex.quote(str(prompt_path))})\" > {shlex.quote(str(raw_path))} 2>&1; echo EXIT=$? >> {shlex.quote(str(raw_path))}"
    command = (
        f"cd {shlex.quote(cwd)} && "
        f"zsh -ilc {shlex.quote(inner)}"
    )
    run(["tmux", "new-window", "-t", "codex", "-n", window, command])
    for _ in range(900):
        if raw_path.exists() and raw_path.read_text(errors="replace").splitlines()[-1:].count("EXIT=0"):
            break
        if raw_path.exists() and raw_path.read_text(errors="replace").splitlines()[-1:] and raw_path.read_text(errors="replace").splitlines()[-1].startswith("EXIT="):
            break
        time.sleep(1)
    else:
        raise SystemExit(f"Claude review timed out; inspect tmux window codex:{window}")
    output = raw_path.read_text(errors="replace")
    return re.sub(r"\nEXIT=\d+\s*$", "", output).strip()


def main() -> int:
    parser = argparse.ArgumentParser(description="Run required linear build reviews")
    parser.add_argument("--kind", choices=["plan", "code", "pm"], required=True)
    parser.add_argument("--reviewer", choices=["codex", "claude"], required=True)
    parser.add_argument("--issue-key", required=True)
    parser.add_argument("--plan", required=True)
    parser.add_argument("--base-ref", default="origin/develop")
    parser.add_argument("--output", required=True)
    args = parser.parse_args()

    cwd = os.getcwd()
    allowed = PLAN_ALLOWED if args.kind == "plan" else CODE_ALLOWED if args.kind == "code" else PM_ALLOWED
    prompt = build_prompt(args.kind, args.plan, args.issue_key.upper(), args.base_ref)
    output_path = Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    raw_output = run_codex(prompt, cwd, output_path, args.kind) if args.reviewer == "codex" else run_claude(prompt, cwd, output_path, args.issue_key, args.kind)
    verdict = extract_verdict(raw_output, allowed)
    write_artifact(output_path, verdict, raw_output, args.reviewer)
    print(f"{args.reviewer}:{args.kind}:{verdict}:{output_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
