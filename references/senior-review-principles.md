# Senior Review Principles

Use this reference first to keep the review grounded in strong senior-engineering habits.

## Review posture

- Understand the intended behavior before judging the implementation.
- Review for user impact, merge risk, and long-term maintenance cost.
- Prefer evidence over intuition, and explicit risk over vague discomfort.
- Keep findings actionable: say what is wrong, why it matters, and the smallest safe fix direction.

## Prioritization

- Review in this order unless the user asks otherwise:
  1. Code logic and correctness
  2. Security and authorization
  3. Performance and scalability
  4. Coverage and missing tests
  5. Code cleanliness
  6. Code style
- Do not spend the review budget on nits while real defects remain unresolved.

## Comment quality

- State confirmed defects as findings.
- State uncertain concerns as questions or risks, not facts.
- Separate style suggestions from merge-blocking bugs.
- Prefer concrete examples, failing scenarios, or file-and-line evidence.
- Avoid comments that only describe the code without explaining the risk.

## Scope control

- Review the changed code first, then inspect nearby code only as far as needed to understand impact.
- Avoid broad redesign requests unless the current patch is unsafe, misleading, or impossible to maintain.
- Prefer a small safe follow-up task over pushing an unrelated refactor into the current change.

## Trade-offs

- Explain when a safer or faster alternative adds complexity, coupling, or maintenance cost.
- Call out when the current implementation is acceptable despite a theoretical optimization opportunity.
- Be explicit about compatibility, rollback, and observability concerns when suggesting changes.

## Outcome

- End with a clear signal: blocking findings, non-blocking suggestions, open questions, or no findings.
- If no findings remain, still note residual risk, untested behavior, or assumptions that were not verified.
