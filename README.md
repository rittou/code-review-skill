# shopware-review

Codex skill for Shopware code review and isolated dev-environment setup.

It helps Codex with:

- isolated Shopware dev-environment setup per PR or ticket
- repository or product context from MCP resources when available
- business context, product intent, and decision rationale before judging the code
- code logic
- security issues
- performance issues and trade-offs
- code cleanliness
- code design and architecture
- code style
- native-function usage and composition across languages
- test and coverage evidence across languages
- ticket-aligned real test evidence and Docker-based runtime validation when the project uses containers

## Repository layout

```text
shopware-review/
├── SKILL.md
├── README.md
├── agents/
│   └── openai.yaml
    ├── scripts/
│   └── qa-env.sh
└── references/
    ├── software-design-principles.md
    ├── code-logic-review.md
    ├── security-review.md
    ├── performance-review.md
    ├── code-cleanliness-review.md
    ├── code-architecture-review.md
    ├── business-context-review.md
    ├── code-style-review.md
    ├── native-functions-review.md
    ├── shopware-core-qa.md
    ├── test-coverage-review.md
    └── review-output-template.md
```

## Install

### Option 1: Use directly from a local path

If the skill is not installed into Codex's skill directory, reference it by path when prompting:

```text
Use $shopware-review at /absolute/path/to/shopware-review to review this patch.
```

Example:

```text
Use $shopware-review at /Users/your-name/code/shopware-review to review this PR for logic, security, performance, cleanliness, style, and coverage evidence.
```

### Option 2: Install for auto-discovery

Clone or copy the folder into your Codex skills directory:

```bash
mkdir -p "${CODEX_HOME:-$HOME/.codex}/skills"
cp -R /path/to/shopware-review "${CODEX_HOME:-$HOME/.codex}/skills/"
```

After that, Codex can discover the skill by name:

```text
Use $shopware-review to review this patch.
```

### Option 3: Keep the repo in `~/code` and symlink it

This is useful if you want the repository to stay shareable in one place while still being auto-discovered by Codex:

```bash
mkdir -p "${CODEX_HOME:-$HOME/.codex}/skills"
ln -s /path/to/shopware-review "${CODEX_HOME:-$HOME/.codex}/skills/shopware-review"
```

## How to use

### Review code in general with test

```text
Use $shopware-review to review this code change in general.
Run the relevant tests, use Docker-based validation when helpful, and return the findings, measured test evidence, and any remaining unverified risk.
```

### Build dev environment

```text
Use $shopware-review to build the Shopware dev environment for this PR.
Choose the right setup path from the diff, prepare demo data only when needed, and always run indexing together with demo data so storefront results are visible.
Return the environment access details plus the observed runtime status.
```

## What the skill loads

The main workflow lives in `SKILL.md`.

The deeper review guidance is split into maintainable domain references:

- `references/software-design-principles.md`
- `references/code-logic-review.md`
- `references/security-review.md`
- `references/performance-review.md`
- `references/code-cleanliness-review.md`
- `references/code-architecture-review.md`
- `references/business-context-review.md`
- `references/code-style-review.md`
- `references/native-functions-review.md`
- `references/shopware-core-qa.md`
- `references/test-coverage-review.md`
- `references/review-output-template.md`

## Shopware Core QA Helper

When the review targets Shopware core, the repository also ships [`scripts/qa-env.sh`](/Users/NFQ-phung.nguyen/life/code-review-skill/scripts/qa-env.sh). It creates one isolated QA namespace per PR or ticket:

- named review-branch worktree at `~/qa/<slug>/worktree`
- Docker Compose project name based on the same slug
- OrbStack URL such as `https://web.<slug>.orb.local`
- database name derived from the slug
- generated `compose.override.yaml` that removes fixed host ports and injects the slug-specific Shopware env values
- diff-based auto detection that promotes backend or search-sensitive PRs into demo-data and indexing flows
- indexing is always paired with demo data so seeded storefront data is actually visible
- environment metadata and artifact files so the QA env can be accessed afterward without rediscovery
- explicit handoff metadata so Codex can continue the review from the generated worktree instead of staying anchored to the original local checkout
- explicit fix-continuation guidance so the same worktree can be used for follow-up code changes when QA fails
- worktree-aware helper wrappers for `repo`, `git`, `compose`, and `test` so post-setup commands stay on the reviewing branch
- a `handoff` helper command that prints the active worktree and the next-step commands for continuing review or fixes there

This keeps parallel QA runs separated without creating an extra Shopware clone on top of the worktree.

Example:

```bash
scripts/qa-env.sh up \
  --repo ~/work/shopware-main \
  --ref origin/pull/123/head \
  --branch review/pr-123-swag-456 \
  --pr 123 \
  --ticket SWAG-456

scripts/qa-env.sh handoff --slug pr-123-swag-456
scripts/qa-env.sh repo --slug pr-123-swag-456 -- pwd
scripts/qa-env.sh git --slug pr-123-swag-456 -- status --short
scripts/qa-env.sh compose --slug pr-123-swag-456 -- ps
scripts/qa-env.sh test --slug pr-123-swag-456 -- bin/console about
scripts/qa-env.sh down --slug pr-123-swag-456
```

By default the helper uses `--profile auto`, compares the PR ref against `origin/HEAD` or a caller-provided `--base-ref`, and then chooses:

- `fe-light` for frontend-only diffs
- `be-light` for infrastructure-only backend changes such as cache, dependency injection, or unit-test-level updates
- `be-fresh` for backend or mixed core changes
- `search-indexed` for indexing or search-sensitive changes

## Notes

- The skill is designed to keep findings risk-first and evidence-based.
- It should check relevant MCP resources first when they are available, then fall back to local repository context.
- It should gather enough business context to avoid calling a product-driven trade-off a defect without evidence.
- It prefers changed-line and branch-risk reasoning over percentage theater.
- When the project is Docker-first, it should prefer Docker or Docker Compose entrypoints for real test and runtime validation.
- It should decide setup intentionally: skip demo data for FE-only and infrastructure-only backend changes, prefer fresh demo data for stateful BE paths, always run indexing together with demo data, and clean up review environments afterward by default.
- For Shopware core, it should prefer one named review-branch worktree per PR or ticket and use that worktree itself as the Docker build root.
- After creating a Shopware core QA env, it should treat the generated worktree as the active review source tree and use `scripts/qa-env.sh repo/git/compose/test` for later commands so the session stays on that reviewing branch.
- If QA shows the PR needs changes, it should continue from that generated worktree as the editable checkout and reuse the same env slug for retesting.
- When it creates a QA env, it should always list the access details afterward: URL, worktree path, compose project, DB name, and artifact locations.
- When it creates a QA env, the final review should begin with `active review root: <worktree path>` so the handoff from local checkout to worktree is obvious.
- It should tie real test selection back to the linked PR ticket or acceptance criteria whenever that context exists.
- If direct coverage tooling is unavailable, the skill should report that clearly instead of inventing coverage claims.
