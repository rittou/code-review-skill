# Shopware Core QA

Use this reference when reviewing Shopware core pull requests that need an isolated runtime environment per PR or ticket.

## Goal

- Make one repeatable QA namespace per PR or ticket.
- Keep the canonical Shopware checkout clean by using a detached git worktree as the build root.
- Make Docker, OrbStack routing, and the database line up on the same slug so parallel QA runs do not collide.
- Run data-dependent setup only after the Shopware setup or install flow succeeds.

## Namespace model

Use one slug everywhere, such as `pr-123-swag-456`.

- Worktree root: `~/qa/pr-123-swag-456/shopware`
- Compose project: `pr-123-swag-456`
- OrbStack URL: `https://web.pr-123-swag-456.orb.local`
- Database name: `pr_123_swag_456`

This keeps code, containers, network names, volumes, cookies, and database state aligned to the same review namespace.

## Isolation rules

- Create the worktree from the canonical Shopware repo with `git worktree add --detach`.
- Build and run Docker from the worktree itself. Do not create a second Shopware clone unless a repository-specific build process absolutely requires it.
- After `scripts/qa-env.sh up` finishes, treat the generated worktree as the active QA source tree. Codex does not automatically move the thread cwd, so every follow-up code read, `git diff`, and `docker compose` command should target the saved worktree path or use the saved slug metadata.
- Always run `docker compose -p <slug> ...` so Docker resources stay namespaced.
- Generate a `compose.override.yaml` in the worktree so the web service gets the slug-specific `APP_URL`, `DATABASE_URL`, and `SYMFONY_TRUSTED_PROXIES`, and so fixed host ports are removed for OrbStack routing.
- Keep a managed block in the worktree's `.env.local` so CLI commands and local inspection reflect the same `APP_URL` and `DATABASE_URL`.
- Avoid fixed localhost ports when OrbStack routing is available.

## Setup profiles

- `auto`: compare the PR ref against the merge-base with `origin/HEAD` or a caller-provided `--base-ref`. Frontend-only diffs resolve to `fe-light`; infrastructure-only backend diffs resolve to `be-light`; stateful backend or mixed diffs resolve to `be-fresh`; search or indexing-related diffs resolve to `search-indexed`.
- `fe-light`: boot the environment and run setup only. No demo data or indexing by default.
- `be-light`: boot the environment and run setup only for backend changes that look infrastructure-only, such as cache, dependency injection, or unit-test-level updates. No demo data or indexing by default.
- `be-fresh`: boot, run setup, load demo data, then refresh DAL indexes. Treat indexing as mandatory whenever demo data is loaded.
- `search-indexed`: same as `be-fresh`, used when the ticket path explicitly depends on indexed read models or search behavior.

## Lifecycle

1. Create a slug from the PR number, ticket key, or explicit override.
2. Create a detached worktree in a dedicated QA folder.
3. Write `compose.override.yaml` and a managed `.env.local` block for that env with a unique `APP_URL` and `DATABASE_URL`.
4. Run `docker compose -p <slug> up -d --build` from the worktree.
5. Run setup commands such as `composer setup`.
6. After setup succeeds, decide whether the ticket needs:
   - demo data plus index refresh,
   - or neither.
7. Run the ticket-specific QA commands inside the app container.
8. Save logs and notes as artifacts.
9. Report the environment access details so the reviewer can keep using the env afterward:
   - app URL,
   - worktree path,
   - compose project,
   - database name,
   - artifact paths such as `run.md`, `run.log`, and `changed-files.txt`.
10. Handoff the review explicitly to the worktree by using the saved `QA_WORKTREE` path for all later repository inspection and by naming that path in the review result.
11. Tear the environment down and remove the worktree when it is no longer needed.

## Collision risks to avoid

- Reusing the same compose project name across PRs.
- Reusing the same `APP_URL`, which can mix browser cookies or sessions.
- Reusing the same database name inside a shared DB service.
- Hardcoding container names in Compose overrides.
- Running multiple watcher stacks with the same host ports.

## Helper script

Use [`scripts/qa-env.sh`](/Users/NFQ-phung.nguyen/life/code-review-skill/scripts/qa-env.sh) to automate the lifecycle.

Example:

```bash
scripts/qa-env.sh up \
  --repo ~/work/shopware-main \
  --ref origin/pull/123/head \
  --pr 123 \
  --ticket SWAG-456

scripts/qa-env.sh test --slug pr-123-swag-456 -- bin/console about
scripts/qa-env.sh down --slug pr-123-swag-456
```

The script defaults to `composer setup`, `framework:demodata`, and `dal:refresh:index`, but lets the caller override those hooks for repository-specific needs.

If demo data is enabled, the helper forces indexing on as well so the seeded data is visible on the storefront and other indexed read paths.

The generated Compose override also aligns the MariaDB bootstrap database with the slug, so a PR env like `pr-123-swag-456` uses a database named `pr_123_swag_456` instead of the Shopware default `shopware`.

The helper also writes `artifacts/changed-files.txt` plus detection metadata into `artifacts/run.md`, so reviewers can see why a PR was treated as FE-only, backend-light, backend-fresh, or search-sensitive.

The helper also writes a handoff section into `artifacts/run.md` that shows the active QA source tree, state file, and commands that should be run against the generated worktree rather than the original local checkout.

When presenting the QA result, always include the environment access summary. At minimum list:

- `APP_URL`
- worktree path
- Compose project name
- database name
- artifact paths
