# Performance Review

Use this reference when the change could affect latency, throughput, memory, or scalability.

## Core questions

- Will this get expensive at production data size or traffic level?
- Does this add repeated I/O, redundant work, or unbounded growth?
- Is the optimization worth its complexity, coupling, or loss of clarity?

## What to inspect

- Nested loops, repeated queries, per-item network calls, and repeated serialization or transformation.
- Large allocations, retained caches, wide object graphs, and unnecessary copies.
- Synchronization, locking, contention, retry storms, and fan-out under load.
- Cache invalidation, batching, pagination, streaming, and data-access patterns.
- Startup cost, cold-path overhead, and work done before a cheap early exit.

## High-signal defect patterns

- N+1 data access in newly introduced loops.
- Recomputing heavy values instead of caching or passing them through.
- Pulling entire datasets where filtered or paginated access would do.
- Optimizations that improve microbenchmarks while hurting readability or correctness.
- Fast paths that bypass observability, cleanup, or safety checks.

## Review guidance

- Focus on material hotspots, not theoretical micro-optimizations.
- Explain trade-offs when a faster design would make the code harder to understand or maintain.
- Prefer evidence such as complexity changes, hot-path reasoning, or profiling data when available.
