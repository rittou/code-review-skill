# Security Review

Use this reference when the change touches trust boundaries, data exposure, permissions, or externally influenced input.

## Core questions

- Can an untrusted actor influence this path?
- What guard prevents unauthorized access, modification, or disclosure?
- What sensitive data could be leaked in success, error, or logging paths?

## What to inspect

- Authentication, authorization, ownership checks, tenant isolation, and privilege escalation paths.
- Input validation, canonicalization, encoding, escaping, and schema enforcement.
- SQL, shell execution, templates, redirects, file paths, uploads, deserialization, and outbound requests.
- Secret handling in config, logs, exceptions, responses, and telemetry.
- Webhooks, callbacks, background jobs, admin-only paths, and "internal" interfaces that can still be abused.

## High-signal defect patterns

- Access checks in controllers but not in deeper service layers.
- Data writes that trust client-provided identifiers or state.
- Logging or returning sensitive values under error paths.
- Templating or command execution paths that interpolate untrusted input.
- Security checks that are bypassed in batch, async, retry, or migration flows.

## Review guidance

- Prefer explicit exploit paths, authorization gaps, or data exposure scenarios over generic warnings.
- Keep severity tied to reachable impact, not only the presence of a suspicious primitive.
- When certainty is limited, say which assumption must hold for the issue to be real.
