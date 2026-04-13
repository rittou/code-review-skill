# Review Output Template

Use this reference right before writing the final review.

## Rules

- Put findings first.
- Order findings by severity, then by confidence and user impact.
- Keep each finding concrete and file-based.
- Omit empty sections instead of filling them with placeholders.
- If there are no findings, use the clean-review template instead of pretending to have issues.
- Use `Suggested code concepts` only when a small design direction would help the reader apply the review cleanly.
- Keep the context sections short and evidence-based; do not invent product intent or architectural trade-offs that are not supported by the code or surrounding discussion.
- When the review baseline is known, explain both the baseline and the actual change scope so the reader understands what was compared.
- When an isolated QA environment was used, include `active review root` near the top of the response and set it to the generated worktree path.

## Full review template

```md
## Context

- active review root: /abs/path/to/worktree | `not used`
- review baseline: latest diff, commit range, base branch, or `not stated`
- what changed against the baseline: short description of the changed scope
- purpose of the code: business change, technical refactor, bug fix, infrastructure change, or other short description
- solution: short description of the implemented approach
- trade-offs: short note about notable trade-offs, constraints, or `none identified`

## Findings

1. [high|medium|low|nit] Short finding title
- file: /abs/path/to/file:line
- category: logic|security|performance|cleanliness|architecture|style|coverage
- impact: what can break, leak, regress, or become harder to maintain
- evidence: concise scenario, failing path, or coverage gap
- fix direction: smallest safe change

2. [high|medium|low|nit] Short finding title
- file: /abs/path/to/file:line
- category: logic|security|performance|cleanliness|architecture|style|coverage
- impact: what can break, leak, regress, or become harder to maintain
- evidence: concise scenario, failing path, or coverage gap
- fix direction: smallest safe change

## Open questions

- Unknowns that block a firmer conclusion.
- Assumptions that should be verified before merge.

## Test And Coverage Evidence

- measured with: tool name | `not measured`
- touched lines covered: yes|partial|no|unknown
- highest-value missing test: short description

## Summary

- overall risk: high|medium|low
- merge readiness: blocked|needs follow-up|ready with caveats|ready
- residual risk: one short sentence
- suggested code concepts: short list of concepts or patterns that would improve clarity, extensibility, or maintainability, or `none`
```

## Clean review template

```md
## Context

- active review root: /abs/path/to/worktree | `not used`
- review baseline: latest diff, commit range, base branch, or `not stated`
- what changed against the baseline: short description of the changed scope
- purpose of the code: business change, technical refactor, bug fix, infrastructure change, or other short description
- solution: short description of the implemented approach
- trade-offs: short note about notable trade-offs, constraints, or `none identified`

## Findings

No blocking findings identified.

## Test And Coverage Evidence

- measured with: tool name | `not measured`
- touched lines covered: yes|partial|no|unknown
- highest-value missing test: short description or `none identified`

## Summary

- overall risk: low
- merge readiness: ready | ready with caveats
- residual risk: short note about unverified paths, assumptions, or missing coverage evidence
- suggested code concepts: short list or `none`
```

## Writing guidance

- Use `high` only for clear correctness, security, or availability risk.
- Use `nit` for non-blocking polish or preference.
- Convert uncertain concerns into `Open questions` instead of overstating them as defects.
- If coverage was not measured, keep the section honest and short.
- Keep `review baseline` factual: name the base branch, commit range, or latest diff only when it is actually known.
- When `active review root` is set, it should be the generated QA worktree path, not the original local checkout.
- Keep `what changed against the baseline` focused on the user-visible or code-structure delta, not a file dump.
- Keep `purpose of the code` focused on why the change exists, not just what files changed.
- Keep `solution` descriptive enough that a reviewer can understand the implementation shape in one pass.
- Use `trade-offs` for meaningful compromises, constraints, or follow-up costs; use `none identified` when nothing material stands out.
- Keep `suggested code concepts` directional and practical: examples include clearer boundaries, strategy extraction, value objects, set-based lookups, composition seams, or narrower interfaces.
- If the review was limited in scope, say so in `Summary`.
