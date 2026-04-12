# Test Coverage Review

Use this guide when the review needs test or coverage evidence across languages.

## Goal

- Measure whether changed or high-risk lines are exercised by tests.
- Prefer real tests that map back to the PR ticket or acceptance criteria when the change affects user workflows, integrations, or deployment wiring.
- When the project is Docker-first, prefer running project-native commands through Docker or Docker Compose so the review matches the real runtime shape.
- Prefer project-native test entrypoints and language-native coverage tools before inventing new commands.
- Avoid claiming exact changed-line coverage unless a report or tooling proves it.
- Keep coverage review focused on merge risk, not percentage theater.

## Quick checks

- Identify the linked ticket, PR description, or acceptance criteria before picking tests.
- Confirm the project's primary test runner and existing coverage path.
- Look for Dockerfiles, Compose files, make targets, or scripts that define how the app and tests normally run.
- Decide whether the scenario needs fresh demo data, indexing, or neither before booting the review environment.
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

Docker or Docker Compose when the project is containerized:

```bash
docker compose run --rm app pytest tests/path/test_file.py -k scenario_name
docker compose run --rm app npm test -- --runTestsByPath path/to/spec.test.ts
docker build -t review-pr:local .
docker run --rm review-pr:local <project-native-test-command>
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

## Ticket-aligned real test workflow

1. Read the PR description, linked ticket, or acceptance criteria and list the user-visible or system-visible behaviors the change claims to affect.
2. Map those behaviors to the most relevant existing test layer: unit, integration, API, end-to-end, migration, worker, or browser flow.
3. Prefer the smallest real test slice that still proves the ticket behavior, not just a nearby helper function.
4. When the repository is containerized, build or start an isolated review container from the current code changes and run the selected scenario inside that environment.
5. Apply setup only when the scenario needs it: skip demo data for frontend-only PRs, but prefer fresh demo data for backend, data-model, workflow, or integration changes that depend on realistic state.
6. Run indexing only when the ticket path depends on search, derived read models, caches, or asynchronous projections that must be current for the scenario to be valid.
7. Use Playwright-style discipline even when Playwright itself is not the tool: establish the state, execute the user or system action, assert the observable outcome, and record what remained unverified.
8. Clean up review containers, data, and ephemeral worktrees after the run unless the user explicitly wants the environment preserved for debugging.
9. Report the exact command or runtime path that was measured so the review distinguishes measured behavior from inferred behavior.

## Containerized validation guidance

- Reuse the project's existing Dockerfile, Compose stack, or wrapper scripts before inventing a custom container flow.
- Prefer a dedicated image or Compose service for the review run when that keeps the checked-out code changes isolated and reproducible.
- If the change depends on multiple services, start only the smallest set needed to validate the ticket path.
- Prefer an ephemeral worktree for PR review runs so the local checkout stays clean and the container build context matches the code under review.
- Treat build failures, boot failures, migration failures, broken assets, or service-to-service wiring issues in the review container as meaningful evidence about merge risk.
- If the container boots but the ticket scenario still cannot be exercised, say exactly what dependency, data fixture, or environment gap blocked validation.
- For UI or workflow-heavy changes, prefer browser-driven acceptance coverage when the repository already has it; otherwise emulate the same real-path validation with the project's native tooling.

## Environment setup options

- `demo data`: use when the review scenario needs realistic entities, permissions, relationships, or workflow state. Skip it for frontend-only changes or other paths that can be proven with mocked or static data.
- `fresh demo data`: prefer this for backend-heavy PRs, schema changes, seed-sensitive logic, or ticket paths that are easy to invalidate with stale state.
- `indexing`: run only when the change affects search, filtering backed by an index, denormalized views, background projections, or any ticket path that depends on asynchronous derived data.
- `cleanup`: treat cleanup as the default. Tear down containers, temporary volumes, and review worktrees after collecting evidence unless there is an explicit reason to preserve the environment.
- Record which of these options were used so the review makes clear whether the evidence came from a fresh environment, a partial bootstrap, or a lightweight FE-only run.

## Interpretation rules

- Prefer branch-risk reasoning over raw percentage chasing.
- Treat uncovered validation, permission, and error paths as more important than uncovered getters or glue code.
- Distinguish "tests exist" from "changed lines are covered."
- Distinguish "coverage exists" from "the ticket behavior was proven in a real runtime path."
- A passing unit test is weaker evidence than a passing ticket-aligned integration or acceptance test when the change modifies wiring, data flow, or user workflows.
- Stale demo data or skipped indexing can invalidate an otherwise clean-looking runtime result; call that out explicitly when it limits confidence.
- If coverage drops slightly because of a justified refactor, explain the trade-off instead of forcing a shallow test.
- Prefer naming the highest-value missing test cases over arguing about a raw percentage alone.

## When direct coverage tooling is unavailable

- Report that coverage could not be measured in the current environment.
- Suggest the smallest next step:
  - use the project's existing coverage command,
  - use the project's Docker or Compose test entrypoint,
  - seed fresh demo data if the scenario depends on backend state,
  - run indexing if the scenario depends on derived data,
  - build the review image and run the ticket scenario there,
  - reuse CI coverage artifacts,
  - or enable the missing local coverage tool if the project depends on one.
- Do not invent percentages or claim changed-line coverage or runtime confidence without evidence.

## Candidate script threshold

- Keep this as reference text while the workflow stays simple.
- If review sessions repeatedly need diff-to-coverage correlation or repeatable Docker review runs, add a `scripts/` helper that maps `git diff` output to the coverage report or wraps the standard review container flow instead of expanding this file further.
