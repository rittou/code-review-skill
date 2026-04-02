---
name: review-code
description: Perform senior-style code reviews for source code, diffs, pull requests, and commits. Use when Codex needs to review logic, security, performance trade-offs, code cleanliness, code style, or PHP PCOV line coverage, and return findings that are risk-first, evidence-based, and easy to act on.
---

# Review Code

Use this workflow to review code like a strong senior engineer: understand intent first, prioritize real risk over taste, and return findings that are specific, justified, and actionable.

## Workflow

### 1) Build context before commenting

- Determine the scope first: file, diff, commit, pull request, or branch.
- Read enough surrounding code to understand contracts, callers, side effects, and tests.
- Confirm repository conventions before judging style, structure, or layering.

### 2) Review in risk order

- Start with code logic and security before style or cleanliness.
- Escalate externally reachable inputs, permissions, secrets, persistence, shell execution, deserialization, redirects, file access, and template rendering into the security pass.
- Check loops, repeated queries, cache behavior, large allocations, duplicate work, and hot paths in the performance pass.

### 3) Gather evidence before concluding

- Prefer concrete proof: failing tests, coverage output, execution traces, or file-and-line references.
- Mark uncertain points as risks or open questions instead of confirmed defects.
- Keep style and cleanliness findings separate from behavioral defects unless they create a real correctness or maintenance risk.

### 4) Load deeper references only when needed

- Load `references/senior-review-principles.md` first for review posture and severity discipline.
- Load `references/code-logic-review.md` when behavior, state, contracts, or edge cases changed.
- Load `references/security-review.md` when untrusted input, permissions, secrets, persistence, networking, templates, files, or execution paths are involved.
- Load `references/performance-review.md` when scale, loops, queries, memory, caching, or throughput matter.
- Load `references/code-cleanliness-review.md` when maintainability, structure, naming, or duplication are relevant.
- Load `references/code-style-review.md` when repository conventions, formatting, or architecture rules matter.
- Load `references/php-pcov-coverage.md` when the review touches PHP or the user asks for line coverage evidence.
- Load `references/review-output-template.md` before writing the final review so the response shape stays consistent.

### 5) Return review output

- Use `references/review-output-template.md` as the default final response shape.
- Start with findings ordered by severity.
- For each finding, include file and line, impact, evidence, and the smallest safe fix direction.
- Separate confirmed defects from trade-offs, questions, suggestions, and style nits.
- If no issues are found, say so explicitly and call out residual risk, missing tests, or unverified areas.

## Guardrails

- Do not block on personal taste when behavior, security, or performance risk remains unresolved.
- Do not invent coverage claims, exploitability, or production impact without evidence.
- Prefer the smallest safe fix over speculative refactors.
- Keep the review scoped to merge risk unless the user explicitly asks for broader design advice.

## Output

- Keep the final review concise and decision-ready.
- Use the full template when there are findings, and the clean-review template when there are none.
- Include coverage only when it was measured or is materially missing.

## Example prompts

- "Review this patch for logic bugs, security issues, performance regressions, code cleanliness, style, and PCOV coverage gaps."
- "Use this skill to review the changed PHP files and tell me which touched lines are not covered."
- "Review this PR like a senior engineer and separate confirmed defects from nits."
