# Test Coverage Review

Use this guide when the review needs test or coverage evidence across languages.

## Goal

- Measure whether changed or high-risk lines are exercised by tests.
- Prefer project-native test entrypoints and language-native coverage tools before inventing new commands.
- Avoid claiming exact changed-line coverage unless a report or tooling proves it.
- Keep coverage review focused on merge risk, not percentage theater.

## Quick checks

- Confirm the project's primary test runner and existing coverage path.
- Look for existing coverage commands in package manifests, build files, CI workflows, or project docs before inventing a new command.
- Prefer the smallest test slice that still exercises the touched lines.

## Common command patterns

PHP with PHPUnit and PCOV when available:

```bash
php -dpcov.enabled=1 -dpcov.directory=. vendor/bin/phpunit --coverage-text
```

Python with `pytest`:

```bash
pytest --cov --cov-report term-missing
```

JavaScript or TypeScript with Jest or Vitest:

```bash
npm test -- --coverage
```

Go:

```bash
go test ./... -coverprofile=coverage.out
```

Rust:

```bash
cargo llvm-cov --summary-only
```

Generate a machine-readable report when helpful and supported by the toolchain:

```bash
php -dpcov.enabled=1 -dpcov.directory=. vendor/bin/phpunit --coverage-clover build/logs/clover.xml
```

## Review workflow

1. Run the smallest relevant test subset that exercises the changed code.
2. Collect line coverage output for touched files.
3. Compare the diff against the covered lines or inspect the report for the changed methods.
4. Call out uncovered changed lines, untested branches, and missing negative-path coverage.
5. If only global coverage is available, say so and avoid overstating certainty.

## Interpretation rules

- Prefer branch-risk reasoning over raw percentage chasing.
- Treat uncovered validation, permission, and error paths as more important than uncovered getters or glue code.
- Distinguish "tests exist" from "changed lines are covered."
- If coverage drops slightly because of a justified refactor, explain the trade-off instead of forcing a shallow test.
- Prefer naming the highest-value missing test cases over arguing about a raw percentage alone.

## When direct coverage tooling is unavailable

- Report that coverage could not be measured in the current environment.
- Suggest the smallest next step:
  - use the project's existing coverage command,
  - reuse CI coverage artifacts,
  - or enable the missing local coverage tool if the project depends on one.
- Do not invent percentages or claim changed-line coverage without evidence.

## Candidate script threshold

- Keep this as reference text while the workflow stays simple.
- If review sessions repeatedly need diff-to-coverage correlation, add a `scripts/` helper that maps `git diff` output to the project's machine-readable coverage report instead of expanding this file further.
