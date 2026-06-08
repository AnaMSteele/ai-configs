# Prompt Templates

Use these as starting points for the input file passed to `run-review.sh`.

## implementation-review

```md
Review this implementation.

Repo: /absolute/path/to/repo
Goal: <what the change is supposed to accomplish>
Files:
- path/to/file1
- path/to/file2

Changed behavior:
- <bullet>
- <bullet>

Checks already run:
- <command/result>

Review for:
- correctness
- missed callsites
- edge cases
- test gaps
- maintainability

If you find issues, rank them by severity and cite files/lines when possible.
```

## plan-review

```md
Review this implementation plan.

Repo: /absolute/path/to/repo
Goal: <what the plan is trying to accomplish>
Constraints:
- <bullet>
- <bullet>

Plan:
<paste the plan here>

If the plan is HTML, treat the HTML file as the authoritative plan artifact. Do not require Markdown conversion.

Review for:
- missing steps
- unsafe assumptions
- architectural risks
- verification gaps
- rollback or migration issues

Return concrete objections and suggested corrections.
```

## pair

```md
Act as a pairing partner on this technical problem.

Repo: /absolute/path/to/repo
Question: <what needs to be figured out>
Relevant files:
- path/to/file1
- path/to/file2

Known facts:
- <bullet>
- <bullet>

Unknowns:
- <bullet>
- <bullet>

Help me reason through the tradeoffs, likely failure modes, and the next best debugging or implementation step.
```
