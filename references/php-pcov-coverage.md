# PHP PCOV Coverage

Use this guide when the review touches PHP and you need line coverage evidence.

## Goal

- Measure whether changed or high-risk PHP lines are exercised by tests.
- Prefer project-native test entrypoints, but force PCOV only when needed.
- Avoid claiming exact changed-line coverage unless a report or tooling proves it.
- Keep coverage review focused on merge risk, not percentage theater.

## Quick checks

- Confirm the project uses PHPUnit or a compatible runner.
- Check whether `pcov` is available with `php -m`.
- Look for existing coverage commands in `composer.json`, CI workflows, or project docs before inventing a new command.
- Prefer the smallest test slice that still exercises the touched lines.

## Common command pattern

Use a project-local PHPUnit entrypoint when available:

```bash
php -dpcov.enabled=1 -dpcov.directory=. vendor/bin/phpunit --coverage-text
```

Generate a machine-readable report when helpful:

```bash
php -dpcov.enabled=1 -dpcov.directory=. vendor/bin/phpunit --coverage-clover build/logs/clover.xml
```

Limit noise and overhead when the repository is large:

```bash
php -dpcov.enabled=1 -dpcov.directory=src -dpcov.exclude='~(tests|vendor|var/cache)~' vendor/bin/phpunit --coverage-text
```

## Review workflow

1. Run the smallest relevant test subset that exercises the changed PHP code.
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

## When PCOV is unavailable

- Report that coverage could not be measured with PCOV in the current environment.
- Suggest the smallest next step:
  - enable the `pcov` extension locally,
  - reuse CI coverage artifacts,
  - or run the project's existing coverage command if it already configures PCOV.
- Do not invent percentages or claim changed-line coverage without evidence.

## Candidate script threshold

- Keep this as reference text while the workflow stays simple.
- If review sessions repeatedly need diff-to-coverage correlation, add a `scripts/` helper that maps `git diff` output to Clover or PHPUnit coverage output instead of expanding this file further.
