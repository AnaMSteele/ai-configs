#!/usr/bin/env python3

from __future__ import annotations

from pathlib import Path


COMMAND_PATHS = [Path("commands/ralph:run.md"), Path("commands/ralph:run-mm.md")]
REVIEW_AGENT_PATHS = [
    Path("agents/quality-reviewer.md"),
    Path("agents/quality-reviewer-k2.5.md"),
]

NORMALIZATION_REPLACEMENTS = {
    "developer-mm": "developer",
    "quality-reviewer-k2.5": "quality-reviewer",
}


def get_section(text: str, heading: str, level: int) -> str:
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
    missing = [phrase for phrase in phrases if phrase not in content]
    if missing:
        raise AssertionError(f"{label} missing phrases: {missing}")


def forbid_phrases(label: str, content: str, phrases: list[str]) -> None:
    present = [phrase for phrase in phrases if phrase in content]
    if present:
        raise AssertionError(f"{label} contains forbidden phrases: {present}")


def normalize(text: str) -> str:
    normalized = text
    for old, new in NORMALIZATION_REPLACEMENTS.items():
        normalized = normalized.replace(old, new)
    return normalized


def main() -> None:
    normalized_texts: dict[Path, str] = {}

    for path in COMMAND_PATHS:
        text = path.read_text()
        normalized_texts[path] = normalize(text)

        implement = get_section(text, "Iteration 1: Implement", level=4)
        require_phrases(
            f"{path} implement loop",
            implement,
            [
                "If implementation evidence or later review findings show the original test scope in this phase was too narrow, revisit the planned tests, widen coverage, and update the phase work instead of stopping at a narrow patch.",
                "If you widen tests or phase work because implementation evidence shows the original test scope or original plan was too narrow, treat that as a reassessment, update `## Decisions / Deviations Log` in the plan immediately with what changed, and keep that entry current before the next review pass.",
            ],
        )
        forbid_phrases(
            f"{path} implement loop stale deferred logging",
            implement,
            [
                "If you widen tests or phase work because implementation evidence shows the original test scope or original plan was too narrow, treat that as a reassessment and ensure it is recorded in `## Decisions / Deviations Log` before the phase advances.",
            ],
        )

        review = get_section(text, "Review Passes: Review and Fix", level=4)
        require_terms(
            f"{path} review loop",
            review,
            [
                "original test scope",
                "original plan",
                "reassess",
                "prior review",
                "reappearing",
                "cross-surface",
                "decisions / deviations log",
            ],
        )
        require_phrases(
            f"{path} review loop",
            review,
            [
                "Before each review pass after the first, summarize the immediately prior review pass into `<prior_review_memory>` with the substantive issue class, affected surface(s), and whether test scope or plan scope was widened. For the first review pass, set `<prior_review_memory>` to `none`.",
                "Prior review memory for this phase: `<prior_review_memory>`",
                "Use `<prior_review_memory>` as the authoritative summary of the immediately prior review pass when comparing current findings against prior findings. Do not rely on unstated conversation memory.",
                "Feedback-loop issues - whether a substantive miss shows the original test scope or original plan was too narrow, including same-class reappearing findings or cross-surface recurrences compared with the prior review pass in this phase",
                "For every substantive miss you fix, explicitly reassess the original test scope and the original plan assumptions for this phase.",
                "If that reassessment widens test scope or plan scope during review, update `## Decisions / Deviations Log` in the plan immediately so a mid-phase resume preserves the widened scope.",
                "Compare each current substantive finding against the immediately prior review-pass findings for this phase.",
                "If the same class of substantive issue is reappearing, or a related miss recurs on another required surface compared with the prior review pass in this phase, treat that as evidence that the original tests or original plan were too narrow.",
                "Escalate those repeated or cross-surface misses beyond a local patch: broaden coverage, update the plan when the phase assumptions were incomplete, and record the reassessment in `## Decisions / Deviations Log` immediately rather than waiting for phase completion.",
                "If you widened tests or plan scope, a `Reassessment:` section stating how the original test scope or original plan changed and whether it was logged in `## Decisions / Deviations Log`.",
            ],
        )
        forbid_phrases(
            f"{path} stale review loop behavior",
            text,
            [
                "up to 3 review/fix passes",
                "Review Passes 1-3: Review and Fix",
                'If you found zero issues, state clearly: "No issues found."',
                "If it found and fixed issues on review pass 3",
            ],
        )

        phase_completion = get_section(text, "Phase Completion", level=4)
        require_phrases(
            f"{path} phase completion",
            phase_completion,
            [
                "ensure `## Decisions / Deviations Log` already contains a structured entry recorded when the event happened; if it does not, append one now",
            ],
        )
        forbid_phrases(
            f"{path} phase completion stale review-only logging",
            phase_completion,
            [
                "including any test-scope or plan-scope reassessment triggered by review findings",
                "append a structured entry to `## Decisions / Deviations Log` in the plan file, including any test-scope or plan-scope reassessment triggered during implementation or review.",
            ],
        )

        tests_policy = get_section(text, "4) Tests Policy", level=3)
        require_phrases(
            f"{path} tests policy",
            tests_policy,
            [
                "Substantive review findings must trigger explicit reassessment of the original test scope and, when needed, the original plan for the current phase.",
                "If a miss is reappearing or recurs across required surfaces compared with the prior review pass, treat it as evidence to widen tests or plan scope rather than only patching locally.",
            ],
        )

        require_phrases(
            f"{path} loop memory",
            text,
            [
                "Within a phase, use the immediately prior review pass as loop memory for substantive findings.",
                "If the same class of substantive miss is reappearing or a related miss recurs on another required surface, do not treat it as an isolated fix; first widen the original test scope and update the original plan/deviation log as needed.",
                "Only after that reassessment still fails to converge should the loop treat the issue as potentially blocked.",
            ],
        )

    for path in REVIEW_AGENT_PATHS:
        text = path.read_text()
        require_phrases(
            f"{path} verdict compatibility",
            text,
            [
                "When the invoking review prompt requires a specific verdict format or placement, follow that contract exactly.",
                "Otherwise, state your verdict clearly and explain the reasoning that led to it.",
            ],
        )
        forbid_phrases(
            f"{path} stale verdict ordering",
            text,
            [
                "State your verdict clearly, explain your reasoning step-by-step to the user before how you arrived at this verdict.",
            ],
        )

    reference_path = COMMAND_PATHS[0]
    reference_text = normalized_texts[reference_path]
    drifted = [
        str(path)
        for path, normalized in normalized_texts.items()
        if path != reference_path and normalized != reference_text
    ]
    if drifted:
        raise AssertionError(
            "ralph:run command variants drifted beyond the intended agent/model differences: "
            + ", ".join(drifted)
        )

    print("ralph:run variants contain required review-feedback loop concepts")


if __name__ == "__main__":
    main()
