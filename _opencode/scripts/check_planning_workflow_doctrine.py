#!/usr/bin/env python3

from __future__ import annotations

from pathlib import Path


SKILL_PATH = Path("skills/planning-workflow/SKILL.md")


def get_section(text: str, heading: str) -> str:
    marker = f"## {heading}\n"
    start = text.find(marker)
    if start == -1:
        raise AssertionError(f"missing section: {heading}")
    start += len(marker)
    end = text.find("\n## ", start)
    if end == -1:
        end = len(text)
    return text[start:end].strip()


def require_terms(label: str, content: str, terms: list[str]) -> None:
    missing = [term for term in terms if term not in content]
    if missing:
        raise AssertionError(f"{label} missing terms: {missing}")


def require_any_phrase(label: str, content: str, phrases: list[str]) -> None:
    if not any(phrase in content for phrase in phrases):
        raise AssertionError(f"{label} missing grouped phrase: one of {phrases}")


def require_phrases(label: str, content: str, phrases: list[str]) -> None:
    missing = [phrase for phrase in phrases if phrase not in content]
    if missing:
        raise AssertionError(f"{label} missing grouped phrases: {missing}")


def main() -> None:
    text = SKILL_PATH.read_text()

    boundaries = get_section(text, "Boundaries")
    require_phrases(
        "boundaries",
        boundaries,
        [
            "writes the actual plan file once discovery has produced enough evidence to choose the correct readiness state",
            "`execution-ready` when foundational decisions are resolved",
            "a single non-ready `research-ready` artifact when further research is the next handoff",
            "Before that handoff point, the work remains `discovery`",
        ],
    )
    if "after discovery is complete" in boundaries:
        raise AssertionError(
            "boundaries must not require discovery to be complete before a research-ready plan artifact can be written"
        )

    ready_bar = get_section(text, "Ready bar")
    require_terms(
        "ready bar",
        ready_bar,
        [
            "execution-ready",
            "no unresolved low-confidence decisions remain",
            "foundational decisions are not deferred into later execution phases",
            "not ready",
            "discovery",
            "research-ready",
        ],
    )
    require_phrases(
        "ready bar",
        ready_bar,
        [
            "An `execution-ready` plan is ready only when all of the following are true:",
            "If any item above is still missing, the plan is `not ready`: stay in `discovery` while evidence is still being gathered, or emit a `research-ready` artifact when research is the explicit next handoff",
        ],
    )

    readiness = get_section(text, "Readiness states")
    require_terms(
        "readiness states",
        readiness,
        ["execution-ready", "not ready", "discovery", "research-ready"],
    )
    require_any_phrase(
        "readiness states",
        readiness,
        [
            "foundational decisions are deferred",
            "deferred into later execution phases",
        ],
    )
    require_phrases(
        "readiness states",
        readiness,
        [
            "`discovery` means planning evidence is still being gathered and the work is not yet plan-finalization-ready; it is a pre-handoff state, not a substitute for a written research handoff",
            "`research-ready` means exactly one non-ready plan artifact may be written once discovery has established that research is the next handoff",
            "that artifact must capture unresolved decisions, the next research step, and the condition for later promotion",
            "`execution-ready` means the plan can hand off to execution without inventing missing contracts, rollout semantics, compatibility rules, or other foundational behavior",
        ],
    )

    low_confidence = get_section(text, "Low-confidence decision workflow")
    require_terms(
        "low-confidence workflow",
        low_confidence,
        [
            "low-confidence",
            "resolve",
            "repo evidence",
            "ask the user",
            "delegate research",
            "research plan",
        ],
    )
    require_phrases(
        "low-confidence workflow",
        low_confidence,
        [
            "Resolve low-confidence decisions from repo evidence first",
            "ask the user before finalizing the plan",
            "delegate research immediately or emit a non-ready `research-ready` research plan artifact",
            "make the exact next research action explicit",
            "Never bury low-confidence decisions inside future execution phases",
        ],
    )

    completeness = get_section(text, "Complexity-aware completeness")
    require_terms(
        "complexity-aware completeness",
        completeness,
        [
            "complexity-aware",
            "lightweight",
            "non-trivial",
            "complete contracts",
            "test coverage matrix",
            "acceptance",
            "domain-agnostic",
        ],
    )
    require_phrases(
        "complexity-aware completeness",
        completeness,
        [
            "Keep the doctrine `complexity-aware` and domain-agnostic: scale planning depth to the real task shape, not the stack",
            "Simple local wiring or narrow refactor tasks should stay `lightweight`",
            "Non-trivial, migration-heavy, compatibility-sensitive, or multi-surface work requires complete contracts before it can be `execution-ready`",
            "Every non-trivial ready plan must include a `test coverage matrix` that maps acceptance criteria and BDD scenarios to planned test layers, intended suites or files, and `### Verify` commands strong enough to catch partial implementations",
        ],
    )

    verification = get_section(text, "Verification ownership")
    require_terms(
        "verification ownership",
        verification,
        ["### Verify", "agent-run", "semantic coherence"],
    )
    require_phrases(
        "verification ownership",
        verification,
        [
            "Phase `### Verify` checks are agent-run execution gates",
            "Final completion still requires a semantic coherence review across the shared files touched by the work",
        ],
    )

    phase_template = get_section(text, "Phase template")
    require_terms(
        "phase template",
        phase_template,
        [
            "### End State",
            "### Tests first",
            "### Work",
            "### Expected files",
            "### Verify",
        ],
    )
    if "### End state" in phase_template:
        raise AssertionError(
            "phase template should require the canonical heading `### End State`, not both case variants"
        )

    doctrine_only = "\n\n".join(
        [ready_bar, readiness, low_confidence, completeness, verification]
    ).lower()
    banned_terms = ["rust", "mcp", "react", "next.js", "tokio"]
    present = [term for term in banned_terms if term in doctrine_only]
    if present:
        raise AssertionError(f"doctrine sections must stay domain-agnostic: {present}")

    print("planning-workflow doctrine contains required hardening concepts")


if __name__ == "__main__":
    main()
