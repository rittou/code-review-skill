# Code Logic Review

Use this reference when behavior, state transitions, or business rules are the main review surface.

## Core questions

- What contract changed?
- What inputs, state, or sequence would make this code behave incorrectly?
- What invariants must still hold before and after this change?

## What to inspect

- Preconditions, postconditions, defaults, and fallbacks.
- Null handling, empty inputs, boundary values, and ordering assumptions.
- Partial writes, transactional boundaries, retries, rollback behavior, and idempotency.
- State transitions, lifecycle changes, and compatibility with existing callers.
- Error handling: swallowed exceptions, misleading success paths, or inconsistent failure behavior.
- Time, locale, cache, and concurrency assumptions when correctness depends on them.

## High-signal defect patterns

- Conditionals that invert or weaken existing guarantees.
- New code paths that skip validation or cleanup.
- Refactors that preserve syntax but subtly change behavior.
- Mismatched read/write models or stale assumptions about data shape.
- Hidden coupling between flags, callbacks, hooks, or side effects.

## Review guidance

- Compare the change with nearby established patterns before calling it incorrect.
- Prefer concrete failing scenarios over abstract concern.
- If the risk is real but proof is incomplete, report it as a risk with the missing assumption called out.
