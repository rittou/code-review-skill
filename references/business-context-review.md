# Business Context Review

Use this reference when the code only makes sense with product intent, business rules, operational goals, or decision rationale.

## Core questions

- What problem is this change trying to solve for the business, operators, or end users?
- Is the code optimizing for the right thing: correctness, speed of delivery, flexibility, compliance, cost, supportability, or user experience?
- Are there explicit product rules, workflow constraints, or organizational decisions behind the implementation?
- Is an apparent technical compromise actually an intentional business trade-off?

## Where to look first

- MCP resources or templates that describe product areas, internal terminology, policy, workflows, or integrations.
- PR descriptions, linked tickets, ADRs, design docs, issue comments, and release notes.
- Names in the code that hint at domain concepts, user states, billing rules, permissions, lifecycle states, or operational processes.
- Tests that encode business rules more clearly than the implementation does.

## What to inspect

- Whether the code preserves the intended user workflow and expected business outcomes.
- Whether business rules are implemented consistently across validation, persistence, UI, APIs, and background jobs.
- Whether the change creates hidden operational cost, support burden, or migration risk.
- Whether exceptions, fallbacks, retries, defaults, and edge cases match real business expectations.

## High-signal defect patterns

- A change that is technically tidy but breaks an important workflow, contract, or policy.
- Review feedback that treats a deliberate product decision as a bug because the reviewer lacks context.
- Business logic duplicated in multiple places with slightly different interpretations.
- Implicit rules encoded in flags, magic values, or status checks without a clear domain model.
- Operational shortcuts that reduce code complexity but create manual support work or confusing user outcomes.

## Review guidance

- Use business context to sharpen review judgment, not to excuse weak code automatically.
- Distinguish "this is a bad implementation" from "this is a hard business rule implemented under constraints."
- If the business goal is unclear, turn that uncertainty into an open question instead of assuming the current design is wrong.
- Call out when missing context materially limits confidence in the review.
- Prefer comments that connect technical risk to user impact, policy risk, cost, or maintainability over purely aesthetic arguments.

## Helpful review language

- "This may be intentional if the workflow prioritizes operator speed over strict normalization, but that product constraint is not visible in the code or tests."
- "The implementation appears to encode a business rule about account state transitions; I would verify that this matches the intended policy before calling it a defect."
- "This reduces duplication technically, but it also merges two workflows that may have different business semantics."
- "The fallback path is resilient, but it may hide an operational failure that the business would rather surface explicitly."

## Rule of thumb

Ask these during review:

- What decision was the team trying to make easier here?
- Who is affected if this behavior is wrong: end users, operators, finance, support, or other systems?
- Is the implementation aligned with the real workflow, not just the happy-path code shape?
- Are we reviewing a technical defect, or are we missing the business reason behind the current trade-off?
