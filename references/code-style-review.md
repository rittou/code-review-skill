# Code Style Review

Use this reference when repository conventions, formatting, naming, or architecture rules matter.

## Core questions

- Does this follow the repository's established conventions?
- Will this style drift fight the formatter, linter, or architectural rules?
- Is the issue a real maintenance problem or only a personal preference?

## What to inspect

- Project-local linters, formatters, naming patterns, import order, and file organization.
- Architecture conventions such as layering, dependency direction, and module boundaries.
- Consistency with nearby code when the repository intentionally differs from general best practice.

## Review guidance

- Treat formatting-only issues as low severity unless they break tooling or obscure meaning.
- Mention style drift only when it increases maintenance cost or makes the code harder to scan.
- Prefer auto-fixable suggestions when project tooling can handle them.
- Avoid personal taste comments that are unsupported by repository convention.
