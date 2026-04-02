#!/usr/bin/env python3

from __future__ import annotations

from pathlib import Path


COMMAND_PATH = Path("commands/dev:plan.md")


def get_section(text: str, heading: str, level: int = 2) -> str:
    marker = f"{'#' * level} {heading}\n"
    start = text.find(marker)
    if start == -1:
        raise AssertionError(f"missing section: {heading}")
    start += len(marker)
    next_marker = f"\n{'#' * level} "
    end = text.find(next_marker, start)
    if end == -1:
        end = len(text)
    return text[start:end].strip()


def require_terms(label: str, content: str, terms: list[str]) -> None:
    haystack = content.lower()
    missing = [term for term in terms if term.lower() not in haystack]
    if missing:
        raise AssertionError(f"{label} missing terms: {missing}")


def require_phrases(label: str, content: str, phrases: list[str]) -> None:
    haystack = content.lower()
    missing = [phrase for phrase in phrases if phrase.lower() not in haystack]
    if missing:
        raise AssertionError(f"{label} missing phrases: {missing}")


def forbid_terms(label: str, content: str, terms: list[str]) -> None:
    haystack = content.lower()
    present = [term for term in terms if term.lower() in haystack]
    if present:
        raise AssertionError(f"{label} contains forbidden terms: {present}")


def main() -> None:
    text = COMMAND_PATH.read_text()

    require_phrases(
        "command intro",
        text,
        [
            "You are leaving read-only discovery mode and entering plan-materialization mode. This is still non-execution work: synthesize validated research into the actual plan artifact.",
            "If safe plan materialization is blocked on new user intent, ask one targeted question and stop without writing the plan.",
            "Do not edit any file except `plan_path` unless the user explicitly broadens scope.",
        ],
    )
    forbid_terms(
        "command text",
        text,
        [
            "Task(subagent_type=",
            "ask once with `question`",
            "keeps the plan in draft",
            "execution plan file",
            "delegate research immediately or write a non-ready `research-ready` plan artifact",
            "delegate research or produce a non-ready `research-ready` artifact",
        ],
    )

    resolve_path = get_section(text, "1) Resolve Plan Path", level=3)
    require_phrases(
        "resolve path",
        resolve_path,
        [
            "If `$ARGUMENTS` looks like a path to an existing `.md` file, treat it as `plan_path`.",
            "If multiple plausible slugs exist, ask the user exactly one targeted question, explain the slug ambiguity, and stop; use the answer on the next invocation.",
            "Set `plan_path` to `thoughts/plans/<slug>.md`.",
            "Ensure the parent directory for `plan_path` exists (create it if missing).",
        ],
    )

    output_contract = get_section(text, "Output Contract")
    require_phrases(
        "output contract",
        output_contract,
        [
            "When plan materialization is safe in this invocation, write exactly one file:",
            "`plan_path` (normally `thoughts/plans/<slug>.md` when `$ARGUMENTS` is not an existing plan path)",
            "If unresolved foundational decisions remain, still preserve the single-file contract by writing exactly one non-ready `research-ready` plan artifact at `plan_path` instead of pretending the work is `execution-ready`.",
            "The written non-ready artifact must set `Status:` to `research-ready`, explicitly list the unresolved decisions, the exact next research action, and the condition for later promotion to `execution-ready`.",
            "If a foundational decision needs new user intent before any safe plan can be written, ask exactly one targeted question and stop without writing `plan_path`.",
            "If a foundational decision needs new user intent, ask exactly one targeted question, explain why the plan is not yet safe to materialize, and do not write or partially rewrite `plan_path`.",
            "Do not create `spec.md`, `tasks.md`, per-plan directories, or any non-plan file unless the user explicitly asks.",
        ],
    )

    require_phrases(
        "completion condition",
        text,
        [
            "Completion condition for this command when a plan artifact can be written safely:",
            "The final response reports the plan path and readiness state, then suggests follow-up work that matches that state without running anything.",
            "Only suggest `/cmd:execute-plan <plan_path>` when the written plan is `execution-ready`.",
            "For a written `research-ready` artifact, point the user to the exact next research action captured in the plan instead of suggesting execution.",
        ],
    )

    repo_reality = get_section(text, "4) Validate Repo Reality", level=3)
    require_phrases(
        "repo reality",
        repo_reality,
        [
            "Use `Glob`, `Grep`, and `Read` for targeted research.",
            "If broad discovery is still needed, continue with additional targeted passes yourself or delegate read-only planning research only through helpers that actually exist in the current runtime.",
            "Do not run side-effecting commands while doing this validation.",
        ],
    )

    readiness_gate = get_section(
        text, "5) Choose readiness state before writing", level=3
    )
    require_terms(
        "readiness gate",
        readiness_gate,
        [
            "fail closed",
            "execution-ready",
            "low-confidence",
            "foundational",
            "ask the user",
            "delegate",
            "research-ready",
        ],
    )
    require_phrases(
        "readiness gate",
        readiness_gate,
        [
            "Treat unresolved contracts, migrations, rollout semantics, compatibility behavior, safety constraints, and other materially outcome-shaping unknowns as `low-confidence` foundational decisions.",
            "Fail closed: do not mark the plan `execution-ready` while any foundational decision remains unresolved.",
            "If repo evidence is insufficient and the decision needs user intent, ask the user before finalizing the plan and do not write or update `plan_path` until that decision is resolved.",
            "If the gap is researchable without new user intent, continue with targeted planning research yourself or delegate read-only planning research only if it can still resolve the decision in this invocation before writing.",
            "If research still remains the next handoff after that validation, write a non-ready `research-ready` plan artifact whose next handoff is that research.",
            "Do not end `dev:plan` by delegating or suggesting follow-up research without writing `plan_path` when research is still the next handoff.",
            "Never bury a low-confidence decision inside a later execution phase just to keep the plan moving.",
        ],
    )

    write_plan = get_section(text, "6) Write `plan_path`", level=3)
    require_terms(
        "write plan",
        write_plan,
        [
            "lightweight",
            "non-trivial",
            "test coverage matrix",
            "acceptance",
            "execution-ready",
        ],
    )
    require_phrases(
        "write plan",
        write_plan,
        [
            "Before any write or side-effecting action, verify it only updates `plan_path` or creates the missing parent directory needed for `plan_path`.",
            "Keep simple local wiring or narrow refactor work `lightweight`; do not force heavyweight schema, protocol, or rollout sections when they do not improve confidence.",
            "Require complete contracts and a `test coverage matrix` only for non-trivial, migration-heavy, compatibility-sensitive, or multi-surface work before calling the plan `execution-ready`.",
            "For non-trivial ready plans, map acceptance criteria and BDD scenarios to intended test layers, planned suites or files, and `### Verify` commands strong enough to catch partial implementations.",
            "Resolve every important question before finalizing an `execution-ready` plan.",
            "If confidence is not high enough, ask the user when intent is required; otherwise either close the gap with additional targeted planning research in this invocation, delegate read-only planning research that can still close it now, or produce a non-ready `research-ready` artifact instead of forcing an `execution-ready` handoff.",
            "Plans that require dependency/library evaluation are not ready until that checkpoint is documented; a missing official-SDK/library decision keeps the work in a non-ready state rather than silently treating it as `execution-ready`.",
        ],
    )

    consistency = get_section(text, "7) Consistency Pass", level=3)
    require_phrases(
        "consistency pass",
        consistency,
        [
            "The chosen readiness state is explicit and internally consistent.",
            "A research-first handoff uses `Status: research-ready` so the written artifact cannot be mistaken for an `execution-ready` plan.",
            "There are no unresolved foundational decisions hiding inside later execution phases.",
            "There are no unresolved decision points left in an `execution-ready` plan; a `research-ready` artifact keeps them explicit as unresolved next-handoff items.",
        ],
    )

    next_steps = get_section(text, "Next Steps For The User")
    require_phrases(
        "next steps",
        next_steps,
        [
            "If the written plan is `execution-ready`, suggest:",
            "`/review:change <plan_path>`",
            "`/cmd:execute-plan <plan_path>`",
            "If the written plan is `research-ready`, suggest reviewing the plan and then doing the exact next research action recorded in that artifact instead of `/cmd:execute-plan`.",
        ],
    )

    print("dev:plan command contains required hardening concepts")


if __name__ == "__main__":
    main()
