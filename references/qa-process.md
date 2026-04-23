# QA Process

Use this reference when you need to explain how the Shopware QA environment is laid out, why each directory exists, and how reviewers should move from setup to QA to follow-up fixes.

## Goal

- Keep the canonical repository clean.
- Give each PR or ticket one isolated QA namespace.
- Make the QA environment reusable for both validation and follow-up fixes.
- Preserve enough metadata and artifacts that the environment can be reopened without rediscovery.

## Directory layout

Each QA run lives under one slugged runtime root such as `~/qa/pr-123-swag-456`.

```text
~/qa/pr-123-swag-456/
├── artifacts/
└── env/
```

The active source root can be one of these:

- a managed worktree at `~/qa/<slug>/worktree`
- the current linked worktree when the current session already matches the target Shopware repo
- a supported system-managed worktree such as Codex under `~/.codex/worktrees/...`

Every active source root also gets:

- `.qa/current` -> `~/qa/<slug>`
- `.qa/<slug>` -> `~/qa/<slug>`

Optional plugin-bearing QA runs may also place nested plugin worktrees under paths such as `<source-root>/custom/plugins/SwagCommercial`.

## Role of each directory

| Path | Role | Why it exists |
| --- | --- | --- |
| `~/qa/<slug>/worktree` | Managed source root for the QA run | Used when the helper creates its own worktree instead of reusing the current or system worktree. |
| `~/qa/<slug>/artifacts` | Runtime evidence and human-readable output | Keeps `run.md`, `run.log`, and `changed-files.txt` together so the reviewer can see what was measured, what setup path was chosen, and what happened during boot or test runs. |
| `~/qa/<slug>/env` | Machine-readable state and metadata | Stores `qa-env.env` and the generated Compose override. This is the source of truth for `QA_WORKTREE`, slug, branch, app URL, database access details, and other values needed for later wrapper commands. |
| `<source-root>/.qa/current` | Source-root pointer back to the runtime root | Makes `env/` and `artifacts/` discoverable from the active checkout without duplicating them into the source tree. |
| `<source-root>/custom/plugins/<PluginName>` | Optional nested plugin worktree | Used when the QA run depends on a plugin that lives in a separate local repository but must be built and tested inside the same Shopware source root. |

## Other important roles

| Item | Role | Why it exists |
| --- | --- | --- |
| Canonical repo | Source of Git objects and shared history | Keeps the main checkout clean while still letting worktrees share repository storage instead of cloning again. |
| Source root mode | How the active source root was selected | `auto` prefers a matching linked/system worktree, `system` requires a supported system-managed worktree, `current` reuses the current checkout, and `managed` always creates `~/qa/<slug>/worktree`. |
| Source ref | The PR ref, branch, or commit the QA env starts from | Defines the baseline content under review. This can be something like `codex/bugbash-4642` or `origin/pull/123/head`. |
| Active source root | The checkout used for code reads, Docker, and fixes | This may be a managed worktree or a reused current/system worktree. |
| Source-root QA pointer | Local `.qa/current` symlink inside the active source root | Lets the reviewer jump from the checkout to the slugged runtime metadata and artifacts quickly. |
| QA branch | Local named branch used inside the active source root | Makes follow-up fixes easier than detached HEAD because the same source root can continue into commit and push flows. This intentionally differs from the source ref when the helper creates or switches to a dedicated QA branch. |
| Compose project | Docker namespace derived from the slug | Prevents container, volume, and network collisions across parallel QA runs. |
| App URL | Slugged OrbStack URL | Keeps browser routing and cookies isolated per QA env. |
| Adminer URL | Slugged OrbStack URL for Adminer | Gives direct DB UI access without guessing service routes. |
| Mailer URL | Slugged OrbStack URL for Mailer/Mailpit | Gives direct mail preview access during QA. |
| Database name | Stable Shopware schema name | Keeps DB access easy in Adminer and CLI because each QA env is already isolated by its own DB container, volume, and Compose project. |

## Why the QA env lives outside the canonical repo

- It avoids dirtying the main checkout during review.
- It makes cleanup easy because the whole namespace is under one slugged directory.
- It keeps multiple PR environments isolated from each other.
- It avoids nested-repo confusion inside the canonical Shopware checkout.

The important detail is that the active source root is not a second independent clone. It is either a real Git worktree backed by the canonical repository’s Git data, or the current matching checkout that the helper intentionally reuses.

## Lifecycle

1. Start from the canonical Shopware repo and a source ref for the PR.
2. Create a slugged QA namespace under `~/qa/<slug>`.
3. Resolve the active source root from `--source-root-mode`.
4. If needed, create `worktree/` on a named local QA branch. Otherwise reuse the current or system worktree and align it to the QA branch.
5. Write `env/qa-env.env` and `artifacts/run.md`.
6. Generate `env/compose.override.yaml`, the managed `.env.local` block, and the source-root `.qa` pointer inside the active source root.
7. If required, attach nested plugin worktrees inside the active source root and prepare any plugin-specific licensing, install, or dependency steps.
8. Boot Docker from the active source root with the slugged Compose project.
9. Run setup, optional demo data, required indexing, and plugin activation or asset builds that the target runtime depends on.
10. When demo data is used, verify storefront readiness so rendered category/product pages actually show seeded products.
11. Perform QA using the source-root-aware helper wrappers.
12. If QA fails, continue fixes from the same source root and same QA branch.
13. Reuse the same slug for retesting until the issue is resolved.
14. Tear the env down when it is no longer needed.

## Decision tables

### Directory decision table

| Need | Location | Reason |
| --- | --- | --- |
| Edit or inspect the reviewed code | `QA_WORKTREE` from `env/qa-env.env` | This is the active checkout after access, regardless of whether it is managed or reused. |
| Jump from the active checkout to runtime metadata | `QA_WORKTREE/.qa/current` | Provides a stable in-checkout pointer to `env/` and `artifacts/`. |
| Read the setup summary | `artifacts/run.md` | Human-readable overview of profile, paths, URL, DB, and access information. |
| Read raw command output | `artifacts/run.log` | Shows the actual boot and command history. |
| Inspect changed-file detection | `artifacts/changed-files.txt` | Records which files drove auto profile selection. |
| Reload environment metadata in later commands | `env/qa-env.env` | Source of truth for slug, source root, runtime root, QA branch, app URL, and DB access details. |
| Inspect an attached plugin used by the QA run | `QA_WORKTREE/custom/plugins/<PluginName>` | Keeps plugin code, asset builds, and runtime validation anchored to the same QA source tree. |

### Setup-profile decision table

| Diff shape | Profile | Demo data | Indexing | Reason |
| --- | --- | --- | --- | --- |
| Frontend-only or static changes | `fe-light` | No | No | Avoid heavy setup when backend state is irrelevant. |
| Infrastructure-only backend changes with no catalog, customer, cart, or order dependency | `be-light` | No | No | Cache, DI, or unit-level changes can stay light only when the QA path does not need seeded commerce state. |
| Checkout, cart, order, stock, warehouse, pricing, shipping, or fulfillment flows | `be-fresh` | Yes | Yes | These scenarios usually need products and other seeded commerce data before a reviewer can create carts or orders and observe the business effect. |
| Stateful backend or mixed core changes | `be-fresh` | Yes | Yes | Real domain behavior often depends on seeded data and refreshed read models. |
| Search or indexing-sensitive changes | `search-indexed` | Yes | Yes | Indexed storefront and search behavior must be current to be trusted. |

### Storefront-readiness decision table

| Situation | Verification behavior | Reason |
| --- | --- | --- |
| Demo data enabled and `--verify-storefront auto` | Run storefront-ready checks | Seeded data should be proven visible, not only inserted. |
| `--verify-storefront always` | Always run storefront-ready checks | Useful when the ticket depends on storefront rendering even without demo data. |
| `--verify-storefront never` | Skip storefront-ready checks | Useful for backend-only env prep where rendered storefront visibility is irrelevant. |

### Source-root decision table

| Mode | Selected source root | Reason |
| --- | --- | --- |
| `auto` | Matching current linked/system worktree, otherwise managed worktree | Best default for portability and low friction. |
| `system` | Current supported system-managed worktree only | Lets Codex and similar tools reuse their own worktree directly. |
| `current` | Current matching checkout or worktree | Useful when the caller intentionally wants to reuse the current source tree. |
| `managed` | `~/qa/<slug>/worktree` | Strongest isolation when no reusable source root is available. |

### Follow-up decision table

| QA result | Next location | Next action | Reason |
| --- | --- | --- | --- |
| QA passes | `artifacts/` + final review output | Report evidence and access details | No code changes are needed. |
| QA fails and fix is needed | `QA_WORKTREE` | Continue implementation on the local QA branch | Keeps code, runtime env, and slug aligned for fast retest loops. |
| QA fails but cause is unclear | `artifacts/run.log` then `QA_WORKTREE` | Inspect evidence first, then adjust code or setup | Avoid guessing while logs and metadata already exist. |
| Env is no longer needed | `~/qa/<slug>` | Run `qa-env.sh cleanup` | Cleans containers, metadata, and worktree together. |

### Plugin-bearing QA decision table

| Situation | Recommended action | Reason |
| --- | --- | --- |
| Core runtime also depends on a local plugin repo | Attach the plugin as a nested worktree under `QA_WORKTREE/custom/plugins/<PluginName>` | Preserves plugin Git history while keeping the runtime rooted in one Shopware checkout. |
| SwagCommercial or another licensed plugin is required | Copy `core.store.licenseHost` and the raw `core.store.licenseKey` from the live `shopware` container or matching live `system_config` row before activation | Prevents activation failures caused by missing or malformed license state. |
| `system:config:get` output is used as the license source | Strip optional leading whitespace plus the `key =>` prefix, and store only the raw value | Avoids persisting console label text as part of `configuration_value`. |
| A copied QA key looks present by length but commercial flows still fail | Re-read the stored QA value with the same whitespace-safe normalization or inspect `system_config.configuration_value` directly | A malformed copied value can pass superficial checks yet still fail in commercial runtime paths such as demo-data generation. |
| `qa-env.sh create` is handling the plugin-bearing setup | Use `--main-process-command` for plugin refresh and activation, `--copy-system-config-from-container` plus repeatable `--copy-system-config-key` for live config copy, and `--runtime-package-root` or `--runtime-package-dir` for runtime-only JS installs | Keeps the scripted QA path aligned with the manual runtime-first sequence and avoids logging raw license values. |
| Manual QA env needs plugin admin assets | Install only the plugin root package and any non-test runtime app packages first | Keeps initial QA setup focused on the working runtime instead of spending time on acceptance or Jest packages that manual QA does not need. |
| Plugin admin build still fails with missing `vite` or plugin-local modules after the runtime packages are installed | Expand to the next smallest plugin dependency install step, and keep broad scripts like `composer npm:ci:all` as a fallback rather than the default | Plugin-local admin apps may need extra `node_modules`, but full test-package installs should not be the first move in a manual QA setup. |

### Branch decision table

| Situation | Branch behavior | Reason |
| --- | --- | --- |
| New QA env | Create `qa/<slug>` by default | Gives the worktree a real branch for follow-up fixes. |
| Explicit branch requested | Use `--branch <name>` | Allows matching an existing naming scheme. |
| Same QA branch already exists locally | Reuse it | Keeps repeated QA runs on the same follow-up branch. |
| Need to publish fixes | Push the local QA branch | Makes the worktree usable beyond QA-only inspection. |

## Working after access

After the QA env is created, do not go back to the canonical repo for review-time code inspection or runtime checks.

Use:

- `scripts/qa-env.sh access --slug <slug>`
- `scripts/qa-env.sh run --slug <slug> -- <command>`
- `scripts/qa-env.sh git --slug <slug> -- <git args>`
- `scripts/qa-env.sh compose --slug <slug> -- <compose args>`
- `scripts/qa-env.sh app --slug <slug> -- <command>`
- `scripts/qa-env.sh info --slug <slug>`
- `scripts/qa-env.sh cleanup --slug <slug>`

If QA shows the PR needs fixes, prefer a Codex session rooted at `QA_WORKTREE`. That is the cleanest way to continue implementation while keeping the same env slug for retesting.

## Practical rule

- Canonical repo: source of truth for shared Git history.
- `QA_WORKTREE`: source of truth for the active QA checkout and follow-up fixes.
- `artifacts/`: source of truth for what happened.
- `env/`: source of truth for how to reopen the environment.
