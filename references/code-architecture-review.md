# Code Architecture Review

Use this reference when the change affects boundaries, layering, dependency direction, extension points, or how easily the codebase can evolve over time.

## Core questions

- Does this design make future changes easier or harder in the area it touches?
- Are responsibilities separated at the right level, or are domain, infrastructure, and orchestration concerns mixed together?
- Do dependencies point in a direction that preserves clear ownership and replaceability?
- Will this shape help the next feature fit naturally, or will it force more special cases and coupling?

## What to inspect

- Module boundaries, package ownership, layering rules, and dependency direction.
- Whether business rules are embedded in controllers, transports, persistence code, or presentation layers.
- How new behavior is extended: composition, interfaces, hooks, policies, strategies, configuration, or branching flags.
- Whether state, side effects, and integration details are isolated behind stable seams.
- Testability signals such as injectable dependencies, narrow contracts, and the ability to exercise behavior without large setup.

## High-signal defect patterns

- Cross-layer leakage where UI, HTTP, database, or framework details spread into core behavior.
- "God" services or managers that accumulate unrelated responsibilities because they are convenient central entry points.
- New abstractions that are generic in name but tightly coupled to one workflow.
- Feature flags or conditional branches that encode long-term product variation without a clear model behind them.
- Circular or bidirectional dependencies that make ownership and change impact hard to reason about.
- Shared utilities that become hidden integration points across unrelated domains.

## Review guidance

- Ground architecture feedback in changeability, defect risk, coupling, or boundary clarity, not abstract purity.
- Prefer the smallest structural improvement that protects future work over broad redesign demands.
- Distinguish "architecture mismatch that will keep hurting us" from "local code could be slightly cleaner."
- Respect existing repository conventions when they are intentional, but call out new drift that makes the design harder to extend or test.
- When a full redesign is too large for the current patch, suggest the safest localized correction or a follow-up seam to introduce.

## Helpful review language

- "This pushes domain decisions into the transport layer, which makes future non-HTTP callers harder to support."
- "This helper centralizes multiple responsibilities, so small changes here will keep expanding its blast radius."
- "The new abstraction hides framework details, but the dependency direction still points inward from infrastructure to core behavior."
- "This works for the current case, but the branching model suggests the next variant will add more conditional paths instead of a clear extension seam."

## Rule of thumb

Ask these during review:

- Where should this responsibility live long term?
- What will need to change next, and will this structure help or fight that change?
- Can this behavior be tested without dragging in unrelated systems?
- Are we adding a reusable seam, or only moving complexity to a new file?
