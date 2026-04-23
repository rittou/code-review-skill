usage() {
  cat <<'EOF'
Create isolated Shopware core QA environments from git worktrees.

Usage:
  qa-env.sh create --repo PATH --ref REF [options]
  qa-env.sh access (--slug SLUG | --env-root PATH) [options]
  qa-env.sh run (--slug SLUG | --env-root PATH) -- COMMAND...
  qa-env.sh git (--slug SLUG | --env-root PATH) -- GIT_ARGS...
  qa-env.sh compose (--slug SLUG | --env-root PATH) -- COMPOSE_ARGS...
  qa-env.sh app (--slug SLUG | --env-root PATH) [options] -- COMMAND...
  qa-env.sh info (--slug SLUG | --env-root PATH) [options]
  qa-env.sh cleanup (--slug SLUG | --env-root PATH) [options]

Commands:
  create  Create one QA env from a PR ref: select or create the source root, attach a QA branch, write env files, start Docker, and run setup.
  access  Print the paths and identifiers you need afterward: source root, runtime root, QA branch, source ref, app URL, Adminer/Mailer URLs, DB credentials, and next steps.
  run     Execute any shell command from the active QA source root, for example `pwd`, `ls`, or `rg`.
  git     Run Git against the active QA source root, for example `status`, `diff`, `switch`, `commit`, or `push`.
  compose Run Docker Compose for the QA env from the active QA source root, for example `ps`, `logs`, `up`, or `down`.
  app     Run a command inside the app container, for example `bin/console`, `phpunit`, or `composer`.
  info    Show the saved QA env metadata and then try `docker compose ps`.
  cleanup Stop Docker, remove the QA worktree, and delete the QA env directory unless keep flags are used.

Common options:
  --base-dir PATH        Root directory for generated QA envs. Default: ~/qa
  --slug SLUG            Explicit env slug. Otherwise built from PR/ticket/ref.
  --env-root PATH        Use an explicit existing env root instead of --slug.

`create` options:
  --repo PATH            Canonical Shopware repo used to create the worktree. Required.
  --ref REF              Source ref being reviewed, such as a PR branch, remote ref, tag, or commit. Required.
  --source-root-mode MODE
                        One of: auto, managed, system, current. Default: auto
  --branch NAME          Local QA branch to use in the worktree. Default: qa/<slug>
  --pr NUMBER            PR number used in slug generation.
  --ticket KEY           Ticket key used in slug generation.
  --profile NAME         One of: auto, fe-light, be-light, be-fresh, search-indexed. Default: auto
  --base-ref REF         Base ref used for diff detection when --profile auto is used. Default: repo's origin/HEAD
  --fetch                Run `git fetch --all --prune` in the canonical repo first.
  --app-service NAME     Compose service that runs Shopware commands. Default: web
  --db-service NAME      Metadata only; DB service label shown in summaries. Default: database
  --db-host HOST         Host used in DATABASE_URL. Default: database
  --db-port PORT         Port used in DATABASE_URL. Default: 3306
  --db-user USER         User used in DATABASE_URL. Default: root
  --db-password PASS     Password used in DATABASE_URL. Default: root
  --db-name NAME         Database name used in DATABASE_URL. Default: shopware
  --app-url URL          Explicit APP_URL. Default: https://web.<slug>.orb.local
  --setup-command CMD    Repeatable. Commands run after `docker compose up`. Default: composer setup
  --main-process-command CMD
                        Repeatable. Commands run after base setup and before runtime package installs and after-setup hooks.
  --demodata auto|always|never
                        When demo data is enabled, indexing is also forced on so storefront data is visible.
  --indexing auto|always|never
                        Auto-resolved from the selected profile, and forced to always when demo data is enabled.
  --verify-storefront auto|always|never
                        Verify rendered storefront visibility after setup. Default: auto
  --demodata-command CMD Command used when demo data is enabled. Default: bin/console framework:demodata
  --index-command CMD    Command used when indexing is enabled. Default: bin/console dal:refresh:index
  --copy-system-config-from-container NAME
                        Copy repeatable --copy-system-config-key values from a live container into the QA env.
  --copy-system-config-key KEY
                        Repeatable. Reads one Shopware system config key from the live container and writes it to the QA env.
  --runtime-package-root PATH
                        Repeatable. Discover runtime package.json files under this QA-worktree-relative root and install them before after-setup hooks.
  --runtime-package-dir PATH
                        Repeatable. Install one explicit QA-worktree-relative runtime package directory before after-setup hooks.
  --include-test-package-dirs
                        Include discovered test package directories. Default: disabled for faster manual QA setup.
  --after-setup-command CMD
                        Repeatable. Extra commands run after setup and optional data/indexing hooks.

`app` options:
  --app-service NAME     Compose service that runs the test command. Default: web

`cleanup` options:
  --keep-worktree        Keep the worktree checkout on disk.
  --keep-volumes         Run `docker compose down` without `-v`.

Examples:
  qa-env.sh create --repo ~/work/shopware-main --ref origin/trunk --pr 123 --ticket SWAG-456
  qa-env.sh access --slug pr-123-swag-456
  qa-env.sh run --slug pr-123-swag-456 -- pwd
  qa-env.sh git --slug pr-123-swag-456 -- status --short
  qa-env.sh compose --slug pr-123-swag-456 -- ps
  qa-env.sh app --slug pr-123-swag-456 -- bin/console about
  qa-env.sh cleanup --slug pr-123-swag-456
EOF
}

log() {
  printf '[qa-env] %s\n' "$*" >&2
}

die() {
  log "ERROR: $*"
  exit 1
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"
}

sanitize_token() {
  local raw="${1:-}"
  raw="$(printf '%s' "$raw" | tr '[:upper:]' '[:lower:]')"
  raw="$(printf '%s' "$raw" | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//; s/-{2,}/-/g')"
  printf '%s' "$raw"
}

sanitize_branch_name() {
  local raw="${1:-}"

  raw="$(printf '%s' "$raw" | tr '[:upper:]' '[:lower:]')"
  raw="$(printf '%s' "$raw" | sed -E 's@[^a-z0-9._/-]+@-@g; s@/{2,}@/@g; s@^-+@@; s@-+$@@; s@^/+@@; s@/+$@@')"
  printf '%s' "$raw"
}

shorten_with_hash() {
  local value="$1"
  local limit="$2"
  local suffix

  if [ "${#value}" -le "$limit" ]; then
    printf '%s' "$value"
    return 0
  fi

  suffix="$(printf '%s' "$value" | cksum | awk '{print $1}' | cut -c1-8)"
  printf '%s-%s' "${value:0:$((limit - 9))}" "$suffix"
}

build_service_url() {
  local host_prefix="$1"
  local slug="$2"

  printf '%s://%s.%s.orb.local' "$DEFAULT_APP_SCHEME" "$host_prefix" "$slug"
}

resolve_dir() {
  local path="$1"

  [ -d "$path" ] || return 1
  (
    cd "$path"
    pwd -P
  )
}

join_for_shell() {
  local joined=""
  local arg

  for arg in "$@"; do
    joined+=$(printf '%q ' "$arg")
  done

  printf '%s' "${joined% }"
}

ensure_parent_dir() {
  local path="$1"
  mkdir -p "$(dirname "$path")"
}
