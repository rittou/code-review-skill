# Shopware Core QA

Use this reference when reviewing Shopware core pull requests that need an isolated runtime environment per PR or ticket.

For the full directory layout, ownership, lifecycle, and decision tables, load [qa-process.md](./qa-process.md).

This file is intentionally narrower than `qa-process.md`. It focuses on the `qa-env.sh` helper, the assumptions behind its generated environment, and the commands reviewers should use after setup.

## Isolation rules

- Create the worktree from the canonical Shopware repo on a named local QA branch so follow-up fixes are easier to continue and publish.
- Build and run Docker from the worktree itself. Do not create a second Shopware clone unless a repository-specific build process absolutely requires it.
- After `scripts/qa-env.sh create` finishes, treat the generated worktree as the active QA source tree. Codex does not automatically move the thread cwd, so every follow-up code read, `git diff`, and `docker compose` command should use the helper wrappers and saved slug metadata instead of assuming the thread moved by itself.
- If QA shows the PR needs follow-up implementation work, continue from that same worktree instead of switching back to the canonical repo. Prefer a Codex session rooted at the worktree for edits, and keep the same slug for retesting.
- Always run `docker compose -p <slug> ...` so Docker resources stay namespaced.
- Generate a `compose.override.yaml` in the worktree so the web service gets the slug-specific `APP_URL`, `DATABASE_URL`, and `SYMFONY_TRUSTED_PROXIES`, and so fixed host ports are removed for OrbStack routing.
- Keep a managed block in the worktree's `.env.local` so CLI commands and local inspection reflect the same `APP_URL` and `DATABASE_URL`.
- Avoid fixed localhost ports when OrbStack routing is available.

## Helper-specific profile behavior

The helper resolves or respects these profiles:

- `auto`: detect the profile from the diff against `origin/HEAD` or a caller-provided `--base-ref`
- `fe-light`: setup only, no demo data or indexing
- `be-light`: setup only for infrastructure-style backend changes
- `be-fresh`: setup plus demo data and index refresh
- `search-indexed`: same as `be-fresh`, used when indexed or search-dependent behavior is involved

For the reasoning behind those profiles, use the decision tables in [qa-process.md](./qa-process.md).

## Helper script

Use [../scripts/qa-env.sh](../scripts/qa-env.sh) to automate the lifecycle.

Example:

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

The script defaults to `composer setup`, `framework:demodata`, and `dal:refresh:index`, but lets the caller override those hooks for repository-specific needs.

If demo data is enabled, the helper forces indexing on as well so the seeded data is visible on the storefront and other indexed read paths.

The generated Compose override also aligns the MariaDB bootstrap database with the slug, so a PR env like `pr-123-swag-456` uses a database named `pr_123_swag_456` instead of the Shopware default `shopware`.

The helper also writes `artifacts/changed-files.txt` plus detection metadata into `artifacts/run.md`, so reviewers can see why a PR was treated as FE-only, backend-light, backend-fresh, or search-sensitive.

The helper also writes an access section into `artifacts/run.md` that shows the active QA source tree, state file, source ref, QA branch, and wrapper commands that should be used against the generated worktree rather than the original local checkout.

Use `scripts/qa-env.sh access --slug <slug>` when you want a short, copyable summary of the editable worktree path plus the wrapper commands for continuing review, runtime checks, or follow-up fixes.

When presenting the QA result, always include the environment access summary. At minimum list:

- `APP_URL`
- worktree path
- Compose project name
- database name
- artifact paths
