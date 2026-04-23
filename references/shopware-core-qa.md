# Shopware Core QA

Use this reference when reviewing Shopware core pull requests that need an isolated runtime environment per PR or ticket.

For the full directory layout, ownership, lifecycle, and decision tables, load [qa-process.md](./qa-process.md).

This file is intentionally narrower than `qa-process.md`. It focuses on the `qa-env.sh` helper, the assumptions behind its generated environment, and the commands reviewers should use after setup.

## Isolation rules

- Separate the QA runtime root from the QA source root. `~/qa/<slug>` stays the stable runtime namespace for metadata, logs, and cleanup, while the source root can be a managed worktree or a reused current/system worktree.
- Prefer `--source-root-mode auto`. It reuses the current linked worktree when the current session is already rooted at the right Shopware repo, and otherwise falls back to a managed worktree under `~/qa/<slug>/worktree`.
- Use `--source-root-mode system` when the current session is already rooted at a supported system-managed worktree such as Codex under `~/.codex/worktrees/...`.
- Use `--source-root-mode current` when you intentionally want to reuse the current checkout even if it is not a system-managed worktree.
- Build and run Docker from the selected source root. Do not create a second Shopware clone unless a repository-specific build process absolutely requires it.
- When the runtime also depends on a local plugin repository, attach that plugin inside the selected source root, ideally as a nested Git worktree under `custom/plugins/<PluginName>` instead of copying files.
- After `scripts/qa-env.sh create` finishes, treat the selected source root as the active QA source tree. Codex does not automatically move the thread cwd, so every follow-up code read, `git diff`, and `docker compose` command should use the helper wrappers and saved slug metadata instead of assuming the thread moved by itself.
- If QA shows the PR needs follow-up implementation work, continue from that same source root instead of switching back to the canonical repo. Prefer a Codex session rooted at the active source root for edits, and keep the same slug for retesting.
- Always run `docker compose -p <slug> ...` so Docker resources stay namespaced.
- Generate the QA `compose.override.yaml` under the runtime metadata directory so reused source roots are not forced to keep a committed override file.
- Keep a managed block in the source root `.env.local` so CLI commands and local inspection reflect the same `APP_URL` and `DATABASE_URL`.
- Write `.qa/current` and `.qa/<slug>` symlinks inside the active source root so the runtime metadata and artifacts are discoverable from the checkout without duplicating files.
- After demo data and indexing, verify storefront readiness before treating the env as ready. The helper can check active product counts plus rendered category/product markup so “generated” is not mistaken for “visible.”
- Avoid fixed localhost ports when OrbStack routing is available.

## Helper-specific profile behavior

The helper resolves or respects these profiles:

- `auto`: detect the profile from the diff against `origin/HEAD` or a caller-provided `--base-ref`
- `fe-light`: setup only, no demo data or indexing
- `be-light`: setup only for infrastructure-style backend changes
- `be-fresh`: setup plus demo data and index refresh
- `search-indexed`: same as `be-fresh`, used when indexed or search-dependent behavior is involved

For the reasoning behind those profiles, use the decision tables in [qa-process.md](./qa-process.md).

For manual QA selection, do not treat `be-light` as the default for every backend ticket. Let the ticketed runtime scenario win over the diff shape. If the reviewer needs products, customers, carts, orders, stock movements, warehouse assignments, or other seeded commerce data to exercise the behavior, choose `be-fresh` or force `--demodata always --indexing always` even when the changed files are mostly subscribers, services, or tests.

## Helper script

Use [../scripts/qa-env.sh](../scripts/qa-env.sh) to automate the lifecycle.

Example:

```bash
scripts/qa-env.sh create \
  --repo ~/work/shopware-main \
  --ref origin/pull/123/head \
  --source-root-mode auto \
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

For plugin-bearing QA envs, the helper now also supports a runtime-first flow directly in `create`: use `--main-process-command` for plugin refresh and activation, `--copy-system-config-from-container` with repeatable `--copy-system-config-key` to copy live Shopware config such as commercial license keys without logging raw values, and `--runtime-package-root` or `--runtime-package-dir` to install only runtime package directories before the generic `--after-setup-command` hooks. Keep `--include-test-package-dirs` disabled unless the QA path explicitly needs those test packages.

If demo data is enabled, the helper forces indexing on as well so the seeded data is visible on the storefront and other indexed read paths.

`--verify-storefront auto|always|never` controls the rendered-storefront check. `auto` runs it when demo data is enabled.

The generated Compose override keeps the MariaDB bootstrap database on the familiar Shopware default `shopware`. Isolation comes from the slugged Compose project, separate DB container, and separate volume, not from renaming the schema.

The helper also writes `artifacts/changed-files.txt` plus detection metadata into `artifacts/run.md`, so reviewers can see why a PR was treated as FE-only, backend-light, backend-fresh, or search-sensitive.

The helper also writes an access section into `artifacts/run.md` that shows the active QA source tree, runtime root, source-root `.qa` pointer, source-root mode, state file, source ref, QA branch, and wrapper commands that should be used against the selected source root rather than the original local checkout.

Use `scripts/qa-env.sh access --slug <slug>` when you want a short, copyable summary of the editable worktree path plus the wrapper commands for continuing review, runtime checks, or follow-up fixes.

## Plugin-bearing QA environments

Some Shopware reviews need more than the core worktree. Treat attached plugins as part of environment setup, not as an afterthought.

Recommended sequence:

1. Create the core QA env with `scripts/qa-env.sh create`.
2. Read `QA_WORKTREE` from `env/qa-env.env` and treat it as the active source root immediately.
3. If the plugin lives in a separate local repository, create a nested plugin worktree inside `QA_WORKTREE/custom/plugins/<PluginName>` on its own local QA branch.
4. Run `php bin/console plugin:refresh` inside the QA app container before installing the plugin.
5. For licensed plugins such as SwagCommercial, copy the live `core.store.licenseHost` and raw `core.store.licenseKey` into the QA env before activation. Prefer the running `shopware` container as the source of truth. If `system:config:get` prints `core.store.licenseKey => <value>`, only store `<value>`. Strip optional leading whitespace before that label too, because the console output may be indented. If the value is read from Adminer or SQL, use the raw `system_config.configuration_value`.
6. Run `php bin/console plugin:install --activate <PluginName>`.
7. For manual QA setup, install only the plugin dependencies that the runtime build actually needs. Prefer the plugin root `package.json` and any non-test app package directories under `Resources/app`, then run the real asset build path that works in the QA env. Do not install `tests/acceptance` or `tests/jest/*` packages during initial env setup unless later verification explicitly needs them.
8. For SwagCommercial specifically, prefer the main-process installation first: runtime plugin install, root JS dependencies, any non-test app-local packages such as `src/ConfigSharing/Resources/app/administration/package.json` when needed, then `composer build:js:admin`. Keep broad helper scripts like `composer npm:ci:all` as a fallback for debugging or full development workflows, not as the default manual-QA path.
9. Clear caches or run other required follow-up commands, then verify `plugin:list`, the app URL, and the behavior under review.

Practical license-copy note:

- Do not trust key length alone after copying `core.store.licenseKey`. Re-read the QA value with the same whitespace-safe normalization or inspect `system_config.configuration_value` directly to confirm the stored value is the raw token, not a formatted `system:config:get` line.

Typical helper shape for that sequence:

```bash
scripts/qa-env.sh create \
  --repo ~/work/shopware \
  --ref origin/pull/2471/head \
  --source-root-mode auto \
  --copy-system-config-from-container shopware-web-1 \
  --copy-system-config-key core.store.licenseHost \
  --copy-system-config-key core.store.licenseKey \
  --main-process-command "bin/console plugin:refresh" \
  --main-process-command "bin/console plugin:install --activate SwagCommercial" \
  --runtime-package-root custom/plugins/SwagCommercial \
  --after-setup-command "composer build:js:admin"
```

Practical note:

- SwagCommercial activation can dirty the QA core `composer.json` by adding `shopware/commercial`. Treat that as QA setup state unless the review specifically targets the resulting composer changes.

When presenting the QA result, always include the environment access summary. At minimum list:

- `APP_URL`
- `ADMINER_URL`
- `MAILER_URL`
- worktree path
- runtime root
- source-root `.qa/current` pointer
- Compose project name
- database name
- database URL or explicit DB credentials
- artifact paths
- attached plugin worktree path or paths when applicable
- plugin QA branch or branches when applicable
- whether any dev license was copied from the live `shopware` container
