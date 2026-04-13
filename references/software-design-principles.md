# Software Design Principles

Use this reference when the review needs a clear design and maintainability lens.

These principles help explain why code feels too coupled, too indirect, too repetitive, or too hard to change. They do not replace logic, security, performance, or test evidence. Use them to strengthen design findings, not to invent style-only objections.

## Review posture

- Start with behavior and risk first. Design principles matter when they affect correctness, changeability, clarity, or operational safety.
- Prefer the smallest principle that explains the issue. Do not stack five labels onto one simple problem.
- Treat principles as heuristics, not laws. A local trade-off can still be reasonable when the code is clearer or safer overall.
- Avoid principle theater. Name the concrete maintenance or extension cost, not just the acronym.

## Principle checklist

### KISS

- Favor the simplest implementation that still handles the real requirements.
- Look for unnecessary indirection, over-generalized helpers, or control flow that hides the main behavior.
- Raise a KISS concern when the complexity makes the feature harder to reason about, debug, or safely modify.
- Do not use KISS to reject necessary domain complexity.

### YAGNI

- Resist abstractions, extension points, or configuration layers that are not needed by the current behavior.
- Look for speculative hooks, extra interfaces, or generic builders that exist only for imagined future reuse.
- Raise a YAGNI concern when the extra structure increases cognitive load without solving a real current need.
- Do not use YAGNI to remove a seam that already supports known extension or testing needs.

### DRY

- Remove duplication that creates parallel maintenance paths or inconsistent behavior.
- Look for copied branching logic, validation rules, mapping code, or query construction that can drift apart.
- Raise a DRY concern when the same rule must be changed in multiple places to stay correct.
- Do not force DRY when duplication is small, local, and clearer than a shared abstraction.

### Separation of Concerns

- Keep domain logic, infrastructure wiring, formatting, persistence, and transport concerns from leaking into each other.
- Look for controllers building domain state, entities knowing too much about transport, or services mixing orchestration with low-level IO details.
- Raise a SoC concern when one unit becomes harder to test, reuse, or evolve because unrelated responsibilities are mixed together.

### Abstraction

- Use abstractions that clarify intent and hide irrelevant detail.
- Look for abstractions that are either too thin to help or so broad that they hide important behavior.
- Raise an abstraction concern when a layer obscures business rules, makes debugging harder, or forces callers to understand too many hidden cases.
- Prefer concrete code over abstraction when the behavior is still local and stable.

### Law of Demeter

- Prefer shallow collaboration boundaries. A unit should talk to close collaborators, not reach deep through object chains.
- Look for chains such as `a()->b()->c()` that expose too much internal structure or create brittle knowledge of nested objects.
- Raise a LoD concern when the calling code becomes tightly coupled to internal graph shape or lifecycle details.
- Do not force wrapper methods that add no clarity beyond hiding a harmless chain.

### SOLID

- Use SOLID as a practical checklist, not a mandate to create many tiny interfaces.
- Single Responsibility: flag units that change for unrelated reasons.
- Open/Closed: prefer extension seams over repeated patching of condition-heavy core flows when the variation is real.
- Liskov Substitution: flag subclasses or implementations that weaken expected behavior or invariants.
- Interface Segregation: prefer smaller contracts when callers only need a subset of a broad surface.
- Dependency Inversion: prefer stable boundaries around infrastructure or external systems when that reduces coupling and test friction.
- Raise SOLID concerns when broken boundaries make the code unsafe to extend or hard to substitute.

### GRASP

- Use GRASP to judge object responsibility and collaboration shape.
- Information Expert: place logic where the needed knowledge naturally lives.
- Creator: create objects where ownership and lifecycle already make sense.
- Controller: keep orchestration in clear entry-point coordinators instead of scattering it across unrelated classes.
- Low Coupling / High Cohesion: prefer focused units with clear reasons to change.
- Polymorphism: use behavior dispatch when it removes type or mode branching cleanly.
- Pure Fabrication / Indirection / Protected Variations: introduce seams only when they reduce meaningful coupling.
- Raise a GRASP concern when responsibilities are assigned to the wrong place and the design becomes harder to follow or extend.

## How to write findings with these principles

- State the concrete issue first.
- Name the principle only if it helps explain the maintenance or design risk.
- Tie the principle to a real consequence such as duplicated bug fixes, brittle extension points, hidden invariants, or test friction.
- Suggest the smallest design adjustment that improves the situation.

Good:

- "This validation rule is duplicated in two handlers, so future fixes can drift apart. This is a DRY problem with a correctness cost."
- "The controller reaches through multiple nested services to assemble domain state. That increases coupling and makes the flow brittle, which is a Law of Demeter and separation-of-concerns issue."

Weak:

- "Violates SOLID."
- "Not clean architecture."

## Guardrails

- Do not turn every preference into a principle violation.
- Do not recommend bigger abstractions just to satisfy a principle label.
- When behavior is correct and the code is easy to change, prefer leaving a small imperfection alone.
- If a principle conflicts with simplicity, observability, or current delivery needs, explain the trade-off instead of pretending the rule is absolute.
