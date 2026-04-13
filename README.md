# shopware-review

Codex skill for two focused Shopware workflows:

- review code with tests and runtime evidence
- build an isolated QA environment per PR or ticket

## What is special here

- one QA namespace per PR or ticket
- named QA-branch worktree at `~/qa/<slug>/worktree`
- Docker, OrbStack URL, and database all use the same slug
- demo data implies indexing when storefront visibility depends on it
- the same worktree can continue into follow-up fixes and retesting

## Repo layout

```text
shopware-review/
├── SKILL.md
├── README.md
├── agents/
│   └── openai.yaml
├── scripts/
│   └── qa-env.sh
└── references/
    ├── business-context-review.md
    ├── code-architecture-review.md
    ├── code-cleanliness-review.md
    ├── code-logic-review.md
    ├── code-style-review.md
    ├── native-functions-review.md
    ├── performance-review.md
    ├── qa-process.md
    ├── review-output-template.md
    ├── security-review.md
    ├── shopware-core-qa.md
    ├── software-design-principles.md
    └── test-coverage-review.md
```

## Use

Review code with tests:

```text
Use $shopware-review to review this code change in general.
Run the relevant tests, use Docker-based validation when helpful, and return the findings, measured test evidence, and any remaining unverified risk.
```

Build a dev environment:

```text
Use $shopware-review to build the Shopware dev environment for this PR.
Choose the right setup path from the diff, prepare demo data only when needed, and always run indexing together with demo data so storefront results are visible.
Return the environment access details plus the observed runtime status.
```

## QA helper

The core helper is [scripts/qa-env.sh](scripts/qa-env.sh).

Typical flow:

```bash
scripts/qa-env.sh create \
  --repo ~/work/shopware-main \
  --ref origin/pull/123/head \
  --branch qa/pr-123-swag-456 \
  --pr 123 \
  --ticket SWAG-456

scripts/qa-env.sh access --slug pr-123-swag-456
scripts/qa-env.sh run --slug pr-123-swag-456 -- pwd
scripts/qa-env.sh git --slug pr-123-swag-456 -- status --short
scripts/qa-env.sh compose --slug pr-123-swag-456 -- ps
scripts/qa-env.sh app --slug pr-123-swag-456 -- bin/console about
scripts/qa-env.sh cleanup --slug pr-123-swag-456
```

The helper supports:

- `auto`, `fe-light`, `be-light`, `be-fresh`, `search-indexed`
- named QA branches for follow-up fixes
- access output with worktree path, branch, URL, DB, and next steps

## References

- Process and directory roles: [references/qa-process.md](references/qa-process.md)
- Shopware QA helper details: [references/shopware-core-qa.md](references/shopware-core-qa.md)
- Review workflow: [SKILL.md](SKILL.md)

## Install

Symlink into Codex skills:

```bash
mkdir -p "${CODEX_HOME:-$HOME/.codex}/skills"
ln -s /path/to/shopware-review "${CODEX_HOME:-$HOME/.codex}/skills/shopware-review"
```
