# QA Process

Use this reference when you need to explain how the Shopware QA environment is laid out, why each directory exists, and how reviewers should move from setup to QA to follow-up fixes.

## Goal

- Keep the canonical repository clean.
- Give each PR or ticket one isolated QA namespace.
- Make the QA environment reusable for both validation and follow-up fixes.
- Preserve enough metadata and artifacts that the environment can be reopened without rediscovery.

## Directory layout

Each QA run lives under one slugged root such as `~/qa/pr-123-swag-456`.

```text
~/qa/pr-123-swag-456/
├── worktree/
├── artifacts/
└── env/
```

## Role of each directory

| Path | Role | Why it exists |
| --- | --- | --- |
| `~/qa/<slug>/worktree` | Active editable checkout for the QA run | This is the real Git worktree for the PR or ticket. It is where Docker builds from, where code should be inspected after handoff, and where follow-up fixes should continue if QA fails. |
| `~/qa/<slug>/artifacts` | Runtime evidence and human-readable output | Keeps `run.md`, `run.log`, and `changed-files.txt` together so the reviewer can see what was measured, what setup path was chosen, and what happened during boot or test runs. |
| `~/qa/<slug>/env` | Machine-readable state and metadata | Stores `qa-env.env`, which is the source of truth for `QA_WORKTREE`, slug, branch, app URL, database name, and other values needed for later wrapper commands. |

## Other important roles

| Item | Role | Why it exists |
| --- | --- | --- |
| Canonical repo | Source of Git objects and shared history | Keeps the main checkout clean while still letting worktrees share repository storage instead of cloning again. |
| Source ref | The PR ref, branch, or commit the QA env starts from | Defines the baseline content under review. |
| Review branch | Local named branch created inside the worktree | Makes follow-up fixes easier than detached HEAD because the same worktree can continue into commit and push flows. |
| Compose project | Docker namespace derived from the slug | Prevents container, volume, and network collisions across parallel QA runs. |
| App URL | Slugged OrbStack URL | Keeps browser routing and cookies isolated per QA env. |
| Database name | Slugged database/schema name | Prevents state collisions and makes debugging easier. |

## Why the QA env lives outside the canonical repo

- It avoids dirtying the main checkout during review.
- It makes cleanup easy because the whole namespace is under one slugged directory.
- It keeps multiple PR environments isolated from each other.
- It avoids nested-repo confusion inside the canonical Shopware checkout.

The important detail is that `worktree/` is not a second independent clone. It is still a real Git worktree backed by the canonical repository’s Git data.

## Lifecycle

1. Start from the canonical Shopware repo and a source ref for the PR.
2. Create a slugged QA namespace under `~/qa/<slug>`.
3. Create `worktree/` on a named local review branch.
4. Write `env/qa-env.env` and `artifacts/run.md`.
5. Generate `compose.override.yaml` and the managed `.env.local` block inside the worktree.
6. Boot Docker from the worktree with the slugged Compose project.
7. Run setup, optional demo data, and required indexing.
8. Perform QA using the worktree-aware helper wrappers.
9. If QA fails, continue fixes from the same worktree and same review branch.
10. Reuse the same slug for retesting until the issue is resolved.
11. Tear the env down when it is no longer needed.

## Decision tables

### Directory decision table

| Need | Location | Reason |
| --- | --- | --- |
| Edit or inspect the reviewed code | `worktree/` | This is the active checkout after handoff. |
| Read the setup summary | `artifacts/run.md` | Human-readable overview of profile, paths, URL, DB, and handoff information. |
| Read raw command output | `artifacts/run.log` | Shows the actual boot and command history. |
| Inspect changed-file detection | `artifacts/changed-files.txt` | Records which files drove auto profile selection. |
| Reload environment metadata in later commands | `env/qa-env.env` | Source of truth for slug, worktree path, review branch, app URL, and DB name. |

### Setup-profile decision table

| Diff shape | Profile | Demo data | Indexing | Reason |
| --- | --- | --- | --- | --- |
| Frontend-only or static changes | `fe-light` | No | No | Avoid heavy setup when backend state is irrelevant. |
| Infrastructure-only backend changes | `be-light` | No | No | Cache, DI, or unit-level changes usually do not need seeded storefront state. |
| Stateful backend or mixed core changes | `be-fresh` | Yes | Yes | Real domain behavior often depends on seeded data and refreshed read models. |
| Search or indexing-sensitive changes | `search-indexed` | Yes | Yes | Indexed storefront and search behavior must be current to be trusted. |

### Follow-up decision table

| QA result | Next location | Next action | Reason |
| --- | --- | --- | --- |
| QA passes | `artifacts/` + final review output | Report evidence and access details | No code changes are needed. |
| QA fails and fix is needed | `worktree/` | Continue implementation on the local review branch | Keeps code, runtime env, and slug aligned for fast retest loops. |
| QA fails but cause is unclear | `artifacts/run.log` then `worktree/` | Inspect evidence first, then adjust code or setup | Avoid guessing while logs and metadata already exist. |
| Env is no longer needed | `~/qa/<slug>` | Run `qa-env.sh down` | Cleans containers, metadata, and worktree together. |

### Branch decision table

| Situation | Branch behavior | Reason |
| --- | --- | --- |
| New QA env | Create `review/<slug>` by default | Gives the worktree a real branch for follow-up fixes. |
| Explicit branch requested | Use `--branch <name>` | Allows matching an existing naming scheme. |
| Same review branch already exists locally | Reuse it | Keeps repeated QA runs on the same follow-up branch. |
| Need to publish fixes | Push the local review branch | Makes the worktree usable beyond QA-only inspection. |

## Working after handoff

After the QA env is created, do not go back to the canonical repo for review-time code inspection or runtime checks.

Use:

- `scripts/qa-env.sh handoff --slug <slug>`
- `scripts/qa-env.sh repo --slug <slug> -- <command>`
- `scripts/qa-env.sh git --slug <slug> -- <git args>`
- `scripts/qa-env.sh compose --slug <slug> -- <compose args>`
- `scripts/qa-env.sh test --slug <slug> -- <command>`

If QA shows the PR needs fixes, prefer a Codex session rooted at `worktree/`. That is the cleanest way to continue implementation while keeping the same env slug for retesting.

## Practical rule

- Canonical repo: source of truth for shared Git history.
- `worktree/`: source of truth for the active QA checkout and follow-up fixes.
- `artifacts/`: source of truth for what happened.
- `env/`: source of truth for how to reopen the environment.
