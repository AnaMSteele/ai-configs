#!/usr/bin/env python3

from __future__ import annotations

from pathlib import Path


SKILL_PATH = Path("skills/product-principles/SKILL.md")


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


def main() -> None:
    text = SKILL_PATH.read_text()

    doctrine = get_section(text, "Core doctrine")
    require_terms(
        "core doctrine",
        doctrine,
        ["obvious", "simple", "safe", "operators", "agents"],
    )

    defaults = get_section(text, "Safe defaults and inference rules")
    require_terms(
        "defaults",
        defaults,
        [
            "canonical discovery",
            "Persist healed or discovered defaults",
            "Do not silently guess",
            "fail closed",
        ],
    )

    healing = get_section(text, "Self-healing systems")
    require_terms(
        "self-healing",
        healing,
        ["detect", "repair", "retry", "persist", "misleading status"],
    )

    errors = get_section(text, "Errors must always provide a path forward")
    require_terms(
        "errors",
        errors,
        ["what failed", "why", "exact next action", "commands", "flags"],
    )

    architecture = get_section(text, "Architectural implications")
    require_terms(
        "architecture",
        architecture,
        [
            "canonical sources of truth",
            "discovery from the primary product surface",
            "backfilled",
            "repair paths",
            "status surfaces",
        ],
    )

    testing = get_section(text, "Testing doctrine")
    require_terms(
        "testing",
        testing,
        [
            "Golden-path workflow tests",
            "Override and explicit-option tests",
            "Self-healing tests",
            "Error-guidance tests",
            "cross-surface contract parity",
        ],
    )

    audit = get_section(text, "Repository alignment / dissonance audit")
    require_terms(
        "alignment audit",
        audit,
        [
            "AGENTS.md",
            "product-intent docs",
            "onboarding/install docs",
            "config defaults",
            "regression suites",
            "concrete file updates",
        ],
    )

    print("product-principles skill contains required doctrine")


if __name__ == "__main__":
    main()
