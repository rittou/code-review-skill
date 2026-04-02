# Code Cleanliness Review

Use this reference when maintainability, readability, and bug surface are meaningful review concerns.

## Core questions

- Does this change make the code easier or harder to reason about next month?
- Are responsibilities clear, or are multiple concerns mixed together?
- Will this structure make future defects more likely?

## What to inspect

- Duplication, dead code, oversized functions, and mixed responsibilities.
- Naming quality, hidden coupling, flag-driven behavior, and hard-to-follow control flow.
- Leaky abstractions, unclear ownership, and spread-out logic that must change together.
- Missing tests or missing seams that make future changes risky.

## High-signal defect patterns

- New abstractions that hide behavior instead of clarifying it.
- Helpers that collapse unrelated responsibilities into one shared utility.
- Refactors that increase indirection without reducing complexity.
- "Temporary" compatibility code that has no removal path.

## Review guidance

- Keep cleanliness findings grounded in defect risk, readability, or maintenance cost.
- Prefer small, local refactors over broad cleanup demands.
- Do not force a redesign when a focused follow-up task would be safer.
