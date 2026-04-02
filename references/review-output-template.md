# Review Output Template

Use this reference right before writing the final review.

## Rules

- Put findings first.
- Order findings by severity, then by confidence and user impact.
- Keep each finding concrete and file-based.
- Omit empty sections instead of filling them with placeholders.
- If there are no findings, use the clean-review template instead of pretending to have issues.

## Full review template

```md
## Findings

1. [high|medium|low|nit] Short finding title
- file: /abs/path/to/file:line
- category: logic|security|performance|cleanliness|style|coverage
- impact: what can break, leak, regress, or become harder to maintain
- evidence: concise scenario, failing path, or coverage gap
- fix direction: smallest safe change

2. [high|medium|low|nit] Short finding title
- file: /abs/path/to/file:line
- category: logic|security|performance|cleanliness|style|coverage
- impact: what can break, leak, regress, or become harder to maintain
- evidence: concise scenario, failing path, or coverage gap
- fix direction: smallest safe change

## Open questions

- Unknowns that block a firmer conclusion.
- Assumptions that should be verified before merge.

## Coverage

- measured with: `pcov` | `not measured`
- touched lines covered: yes|partial|no|unknown
- highest-value missing test: short description

## Summary

- overall risk: high|medium|low
- merge readiness: blocked|needs follow-up|ready with caveats|ready
- residual risk: one short sentence
```

## Clean review template

```md
## Findings

No blocking findings identified.

## Coverage

- measured with: `pcov` | `not measured`
- touched lines covered: yes|partial|no|unknown
- highest-value missing test: short description or `none identified`

## Summary

- overall risk: low
- merge readiness: ready | ready with caveats
- residual risk: short note about unverified paths, assumptions, or missing coverage evidence
```

## Writing guidance

- Use `high` only for clear correctness, security, or availability risk.
- Use `nit` for non-blocking polish or preference.
- Convert uncertain concerns into `Open questions` instead of overstating them as defects.
- If coverage was not measured, keep the section honest and short.
- If the review was limited in scope, say so in `Summary`.
