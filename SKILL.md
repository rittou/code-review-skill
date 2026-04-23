---
name: shopware-review
description: Review Shopware core pull requests and other Docker-first code changes, or build isolated Shopware QA environments for PR validation. Use when Codex needs code-review findings with test evidence or a clean dev environment with access details and runtime status.
---

# Shopware Review

Use this workflow to review code with strong engineering judgment: understand intent first, prioritize real risk over taste, and return findings that are specific, justified, and actionable.

## Workflow

### 1) Build context before commenting

- Determine the scope first: file, diff, commit, pull request, or branch.
- Check for relevant MCP resources or templates first when they are available, and use them to load product, repository, domain, or integration context before reading code.
- Look for business or product context early: feature intent, user workflow, policy constraints, operational goals, success metrics, or known trade-offs.
- Prefer MCP-provided source-of-truth context over guessing from filenames or local fragments alone.
- If no relevant MCP context is available, fall back to local code, tests, docs, ADRs, tickets, PR descriptions, and repository history.
- For pull requests, extract linked ticket scope or acceptance criteria early so review findings and test selection stay tied to the intended behavior.
- Read enough surrounding code to understand contracts, callers, side effects, and tests.
- Plan review-environment setup intentionally: use the diff and the ticket path to decide whether the change is frontend-only, infrastructure-only backend work, or stateful backend behavior that needs fresh demo data. Let the ticketed user journey win over file-shape heuristics when they disagree. When demo data is used, run indexing with it so storefront-visible results are valid.
- Treat checkout, cart, order, stock, warehouse, reservation, fulfillment, shipping, and pricing tickets as stateful commerce flows by default. If the QA path needs products, customers, carts, or orders to reproduce the issue, do not choose a light profile just because the diff mostly touches subscribers, services, or unit tests.
- When the runtime depends on local plugins or commercial extensions, treat plugin attachment, activation, licensing, and asset builds as part of the setup plan rather than optional follow-up work.
- When the project is Docker-first, prefer Docker or Docker Compose entrypoints, container definitions, and container logs over ad-hoc host commands.
- Confirm repository conventions before judging style, structure, or layering.

### 2) Review in risk order

- Start with code logic and security before style or cleanliness.
- Escalate externally reachable inputs, permissions, secrets, persistence, shell execution, deserialization, redirects, file access, and template rendering into the security pass.
- Check loops, repeated queries, cache behavior, large allocations, duplicate work, and hot paths in the performance pass.

### 3) Gather evidence before concluding

- Prefer concrete proof: failing tests, ticket-aligned real test runs, coverage output, container logs, execution traces, or file-and-line references.
- When environment setup affected the result, record whether demo data, indexing, or cleanup steps were used. Treat indexing as part of the demo-data path, not an unrelated optional step.
- When a QA environment is created, switch the review baseline from the local skill repo or canonical checkout to the active QA source root immediately. Read the env state file, use the saved `QA_WORKTREE` path for all follow-up file reads, `git` commands, and Docker Compose commands, and reference files from that path in the review output.
- Do not assume the Codex thread cwd automatically follows the worktree. Treat the access step as explicit: after `scripts/qa-env.sh create`, continue through the helper wrappers such as `scripts/qa-env.sh run`, `scripts/qa-env.sh git`, `scripts/qa-env.sh compose`, and `scripts/qa-env.sh app` so later commands stay anchored to the QA branch.
- Prefer `--source-root-mode auto` for Shopware core QA. It should reuse the current linked/system worktree when the current session already matches the target Shopware repo, and otherwise fall back to a managed worktree under the slugged QA runtime root.
- When the QA source root is selected, expect a local `.qa/current` pointer inside that checkout so the slugged runtime metadata and artifacts can be reopened directly from the source tree.
- When the QA env needs plugins from separate local repositories, attach them inside `QA_WORKTREE` first, preferably as nested Git worktrees under `custom/plugins/<PluginName>`, and keep their QA branches separate from the core QA branch.
- For SwagCommercial or other licensed commercial plugins, copy the live system config into the QA env before activation. Use `core.store.licenseHost` and the raw `core.store.licenseKey` value only. If the source command prints `core.store.licenseKey => <value>`, strip the `key =>` prefix instead of storing it as part of the value. Treat leading whitespace before that label as part of the console formatting and strip it too. Prefer copying from the running `shopware` container or the corresponding live `system_config.configuration_value`.
- After copying `core.store.licenseKey`, sanity-check that the stored QA value is the raw token and not a formatted `system:config:get` line. A malformed copied value can look present by length but still fail later with licensing errors during plugin activation or commercial demo-data generation.
- For manual QA env creation, prefer the main runtime path first: `plugin:refresh`, `plugin:install --activate`, only the runtime dependency installs needed for the affected plugin, the real asset build path that works in that env, and cache clear or other required follow-up commands. Do not install test packages up front unless the review explicitly needs automated test execution.
- For SwagCommercial, start with the root plugin `package.json` and any non-test app packages that are actually part of the runtime build. Skip `tests/acceptance` and `tests/jest/*` during initial QA setup unless later verification requires them.
- When `scripts/qa-env.sh create` is used for that flow, prefer the helper’s dedicated flags over ad-hoc shell glue: `--main-process-command` for plugin refresh and activation, `--copy-system-config-from-container` with repeatable `--copy-system-config-key` for license state, and `--runtime-package-root` or `--runtime-package-dir` for runtime-only JS installs. Leave `--include-test-package-dirs` off unless the review truly needs test-package installs.
- Before choosing `be-light`, ask whether the manual QA path needs seeded catalog or customer state to create or inspect the business scenario. If the answer is yes, prefer `be-fresh` or explicitly force `--demodata always --indexing always`, even when the code diff itself looks infrastructure-like.
- When demo data is part of the setup path, prefer storefront-ready verification instead of assuming seeded data is immediately visible. A QA env is stronger when it proves rendered category/product visibility after indexing, not just database row counts.
- If QA shows the PR does not satisfy the requirements and follow-up code changes are needed, treat the active QA source root as the editable continuation checkout. Prefer a Codex session rooted at `QA_WORKTREE` for code changes; that source root should already be on a local QA branch. Then reuse the same env slug for runtime rechecks.
- Mark uncertain points as risks or open questions instead of confirmed defects.
- Keep style and cleanliness findings separate from behavioral defects unless they create a real correctness or maintenance risk.

### 4) Load deeper references only when needed

- Load `references/software-design-principles.md` first when the review needs a design or maintainability lens such as KISS, YAGNI, DRY, SoC, abstraction, LoD, SOLID, or GRASP.
- Load `references/code-logic-review.md` when behavior, state, contracts, or edge cases changed.
- Load `references/security-review.md` when untrusted input, permissions, secrets, persistence, networking, templates, files, or execution paths are involved.
- Load `references/performance-review.md` when scale, loops, queries, memory, caching, or throughput matter.
- Load `references/code-cleanliness-review.md` when maintainability, structure, naming, or duplication are relevant.
- Load `references/code-architecture-review.md` when boundaries, layering, dependency direction, extension points, or long-term changeability are relevant.
- Load `references/business-context-review.md` when the review needs product intent, business rules, decision rationale, user impact, or operational context to judge the change fairly.
- Load `references/code-style-review.md` when repository conventions, formatting, or architecture rules matter.
- Load `references/native-functions-review.md` when reviewing standard-library collection handling, lookup structures, deduplication, key preservation, null semantics, or native-function composition across languages.
- Load `references/shopware-core-qa.md` and inspect `scripts/qa-env.sh` when the review targets Shopware core and needs one isolated QA environment per PR or ticket.
- Load `references/test-coverage-review.md` when the review needs test and coverage evidence, changed-line confidence, ticket-aligned runtime validation, Docker-based verification, or language-specific coverage tooling.
- Load `references/review-output-template.md` before writing the final review so the response shape stays consistent.

### 5) Return review output

- Use `references/review-output-template.md` as the default final response shape.
- Capture the intended purpose of the change before summarizing merge risk.
- Capture what changed against the review baseline, such as the latest diff, commit range, or base branch, so the reader sees the scope in context.
- Summarize the solution shape and meaningful trade-offs when they are clear from the diff or surrounding context.
- Start with findings ordered by severity.
- For each finding, include file and line, impact, evidence, and the smallest safe fix direction.
- Tie test evidence back to the PR or ticket when possible: say which behavior was exercised, how it was measured, and whether it used real runtime validation or only static reasoning.
- When runtime validation required setup steps, note whether fresh demo data, indexing, or environment cleanup were part of the measured path. If demo data was loaded, indexing should have run as well.
- When storefront-ready verification was used, say so explicitly and distinguish “seeded data exists” from “seeded data rendered on storefront.”
- When a QA environment was created, always list the access details needed for follow-up work: app URL, adminer URL, mailer URL, worktree path, runtime root, source-root `.qa/current` pointer, compose project, database name, full DB credentials or URL, and artifact locations.
- When a plugin-bearing QA environment was created, also list the attached plugin worktree path or paths, the plugin QA branch or branches, and whether any dev license was copied from the live `shopware` container. Do not print raw license keys unless the user explicitly asks for them.
- When a QA environment was created, include a short access note that the active QA source tree is the selected `QA_WORKTREE` and name that path explicitly.
- When fixes are needed after QA, say explicitly that the same source root can be used to continue implementation and the same env slug can be reused for retesting.
- Separate confirmed defects from trade-offs, questions, suggestions, and style nits.
- If no issues are found, say so explicitly and call out residual risk, missing tests, or unverified areas.

## Guardrails

- Do not block on personal taste when behavior, security, or performance risk remains unresolved.
- Do not invent coverage claims, exploitability, or production impact without evidence.
- Prefer the smallest safe fix over speculative refactors.
- Keep the review scoped to merge risk unless the user explicitly asks for broader design advice.

## Output

- Keep the final review concise and decision-ready.
- Use the full template when there are findings, and the clean-review template when there are none.
- Include test, coverage, or runtime validation evidence only when it was measured or is materially missing.
- When an isolated QA env was used, include a short environment access section so the user can reopen or continue using that env afterward.

## Example prompts

- "Use $shopware-review to review this code change in general, run the relevant tests, and return findings plus measured test evidence."
- "Use $shopware-review to build the Shopware dev environment for this PR and return the environment access details plus the runtime status."
- "Use $shopware-review to build a Shopware QA env for this SwagCommercial PR, attach the commercial plugin worktree, copy the live license host and raw license key from the `shopware` container, install the plugin, rebuild assets, and return the access details plus measured validation."
