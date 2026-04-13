#!/usr/bin/env bash

set -euo pipefail

PROGRAM_NAME="${0##*/}"

DEFAULT_BASE_DIR="${QA_BASE_DIR:-$HOME/qa}"
DEFAULT_APP_SERVICE="${QA_APP_SERVICE:-web}"
DEFAULT_DB_SERVICE="${QA_DB_SERVICE:-database}"
DEFAULT_DB_HOST="${QA_DB_HOST:-database}"
DEFAULT_DB_PORT="${QA_DB_PORT:-3306}"
DEFAULT_DB_USER="${QA_DB_USER:-root}"
DEFAULT_DB_PASSWORD="${QA_DB_PASSWORD:-root}"
DEFAULT_APP_SCHEME="${QA_APP_SCHEME:-https}"
DEFAULT_APP_HOST_PREFIX="${QA_APP_HOST_PREFIX:-web}"
DEFAULT_TRUSTED_PROXIES="${QA_TRUSTED_PROXIES:-private_ranges}"
ENV_MANAGED_BLOCK_START="# >>> qa-env managed block >>>"
ENV_MANAGED_BLOCK_END="# <<< qa-env managed block <<<"

RUN_LOG=""
RUN_SUMMARY=""
CURRENT_WORKTREE=""
CURRENT_SLUG=""
REMAINING_ARGS=()
PARSED_BASE_DIR=""
PARSED_SLUG=""
PARSED_ENV_ROOT=""

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
  create  Create one QA env from a PR ref: make the worktree, attach a local QA branch, write env files, start Docker, and run setup.
  access  Print the paths and identifiers you need afterward: worktree path, QA branch, source ref, app URL, DB name, and next steps.
  run     Execute any shell command from the QA worktree, for example `pwd`, `ls`, or `rg`.
  git     Run Git against the QA worktree, for example `status`, `diff`, `switch`, `commit`, or `push`.
  compose Run Docker Compose for the QA env from the QA worktree, for example `ps`, `logs`, `up`, or `down`.
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
  --app-url URL          Explicit APP_URL. Default: https://web.<slug>.orb.local
  --setup-command CMD    Repeatable. Commands run after `docker compose up`. Default: composer setup
  --demodata auto|always|never
                        When demo data is enabled, indexing is also forced on so storefront data is visible.
  --indexing auto|always|never
                        Auto-resolved from the selected profile, and forced to always when demo data is enabled.
  --demodata-command CMD Command used when demo data is enabled. Default: bin/console framework:demodata
  --index-command CMD    Command used when indexing is enabled. Default: bin/console dal:refresh:index
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

build_slug() {
  local explicit_slug="$1"
  local pr_number="$2"
  local ticket_key="$3"
  local ref_name="$4"
  local slug=""
  local ref_part=""

  if [ -n "$explicit_slug" ]; then
    slug="$(sanitize_token "$explicit_slug")"
  else
    if [ -n "$pr_number" ]; then
      slug="pr-${pr_number}"
    fi

    if [ -n "$ticket_key" ]; then
      ticket_key="$(sanitize_token "$ticket_key")"
      if [ -n "$slug" ]; then
        slug="${slug}-${ticket_key}"
      else
        slug="$ticket_key"
      fi
    fi

    if [ -z "$slug" ]; then
      ref_part="${ref_name##*/}"
      slug="$(sanitize_token "$ref_part")"
    fi
  fi

  [ -n "$slug" ] || die "Could not build a slug. Provide --slug, --pr, --ticket, or --ref."
  shorten_with_hash "$slug" 48
}

build_db_name() {
  local slug="$1"
  local db_name

  db_name="$(printf '%s' "$slug" | tr '-' '_')"
  db_name="$(shorten_with_hash "$db_name" 48)"
  printf '%s' "$db_name"
}

build_qa_branch() {
  local explicit_branch="$1"
  local slug="$2"
  local branch_name=""

  if [ -n "$explicit_branch" ]; then
    branch_name="$(sanitize_branch_name "$explicit_branch")"
  else
    branch_name="qa/$slug"
  fi

  [ -n "$branch_name" ] || die "Could not build a QA branch. Provide --branch or a valid slug."
  printf '%s' "$branch_name"
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

write_state_file() {
  local state_file="$1"

  ensure_parent_dir "$state_file"
  {
    printf 'QA_ENV_ROOT=%q\n' "$QA_ENV_ROOT"
    printf 'QA_WORKTREE=%q\n' "$QA_WORKTREE"
    printf 'QA_ARTIFACTS_DIR=%q\n' "$QA_ARTIFACTS_DIR"
    printf 'QA_METADATA_DIR=%q\n' "$QA_METADATA_DIR"
    printf 'QA_COMPOSE_OVERRIDE=%q\n' "$QA_COMPOSE_OVERRIDE"
    printf 'QA_SLUG=%q\n' "$QA_SLUG"
    printf 'QA_PROFILE_REQUESTED=%q\n' "$QA_PROFILE_REQUESTED"
    printf 'QA_PROFILE_SOURCE=%q\n' "$QA_PROFILE_SOURCE"
    printf 'QA_PROFILE=%q\n' "$QA_PROFILE"
    printf 'QA_REPO=%q\n' "$QA_REPO"
    printf 'QA_REF=%q\n' "$QA_REF"
    printf 'QA_QA_BRANCH=%q\n' "$QA_QA_BRANCH"
    printf 'QA_REVIEW_BRANCH=%q\n' "$QA_REVIEW_BRANCH"
    printf 'QA_BRANCH_STATE=%q\n' "$QA_BRANCH_STATE"
    printf 'QA_BASE_REF=%q\n' "$QA_BASE_REF"
    printf 'QA_MERGE_BASE=%q\n' "$QA_MERGE_BASE"
    printf 'QA_DETECTION_REASON=%q\n' "$QA_DETECTION_REASON"
    printf 'QA_CHANGED_FILES_FILE=%q\n' "$QA_CHANGED_FILES_FILE"
    printf 'QA_CHANGED_FILES_COUNT=%q\n' "$QA_CHANGED_FILES_COUNT"
    printf 'QA_PR_NUMBER=%q\n' "$QA_PR_NUMBER"
    printf 'QA_TICKET=%q\n' "$QA_TICKET"
    printf 'QA_COMPOSE_PROJECT=%q\n' "$QA_COMPOSE_PROJECT"
    printf 'QA_APP_URL=%q\n' "$QA_APP_URL"
    printf 'QA_APP_SERVICE=%q\n' "$QA_APP_SERVICE"
    printf 'QA_DB_SERVICE=%q\n' "$QA_DB_SERVICE"
    printf 'QA_DB_HOST=%q\n' "$QA_DB_HOST"
    printf 'QA_DB_PORT=%q\n' "$QA_DB_PORT"
    printf 'QA_DB_USER=%q\n' "$QA_DB_USER"
    printf 'QA_DB_PASSWORD=%q\n' "$QA_DB_PASSWORD"
    printf 'QA_DB_NAME=%q\n' "$QA_DB_NAME"
    printf 'QA_TRUSTED_PROXIES=%q\n' "$QA_TRUSTED_PROXIES"
    printf 'QA_DEMODATA_MODE=%q\n' "$QA_DEMODATA_MODE"
    printf 'QA_INDEXING_MODE=%q\n' "$QA_INDEXING_MODE"
    printf 'QA_MODE_NOTE=%q\n' "$QA_MODE_NOTE"
  } >"$state_file"
}

write_summary_file() {
  local summary_file="$1"

  cat >"$summary_file" <<EOF
# Shopware QA Environment

- slug: \`$QA_SLUG\`
- profile requested: \`$QA_PROFILE_REQUESTED\`
- profile resolved: \`$QA_PROFILE\`
- profile source: \`$QA_PROFILE_SOURCE\`
- profile: \`$QA_PROFILE\`
- repo: \`$QA_REPO\`
- source ref: \`$QA_REF\`
- qa branch: \`$QA_QA_BRANCH\`
- branch state: \`$QA_BRANCH_STATE\`
- base ref: \`$QA_BASE_REF\`
- merge base: \`$QA_MERGE_BASE\`
- worktree: \`$QA_WORKTREE\`
- compose override: \`$QA_COMPOSE_OVERRIDE\`
- compose project: \`$QA_COMPOSE_PROJECT\`
- app url: [$QA_APP_URL]($QA_APP_URL)
- app service: \`$QA_APP_SERVICE\`
- db service: \`$QA_DB_SERVICE\`
- db name: \`$QA_DB_NAME\`
- demo data: \`$QA_DEMODATA_MODE\`
- indexing: \`$QA_INDEXING_MODE\`
- setup note: ${QA_MODE_NOTE:-none}
- changed files: \`$QA_CHANGED_FILES_COUNT\` (see [$QA_CHANGED_FILES_FILE]($QA_CHANGED_FILES_FILE))
- detection: $QA_DETECTION_REASON

## Environment Access

- app url: [$QA_APP_URL]($QA_APP_URL)
- worktree path: \`$QA_WORKTREE\`
- qa branch: \`$QA_QA_BRANCH\`
- compose project: \`$QA_COMPOSE_PROJECT\`
- database name: \`$QA_DB_NAME\`
- compose override: [compose.override.yaml]($QA_COMPOSE_OVERRIDE)
- env state: [qa-env.env]($QA_METADATA_DIR/qa-env.env)
- artifacts:
  - [run.md]($QA_ARTIFACTS_DIR/run.md)
  - [run.log]($QA_ARTIFACTS_DIR/run.log)
  - [changed-files.txt]($QA_CHANGED_FILES_FILE)

## Worktree Access

- active QA source tree: \`$QA_WORKTREE\`
- active QA branch: \`$QA_QA_BRANCH\`
- source ref stays the original PR branch, tag, or commit being reviewed: \`$QA_REF\`
- QA branch is the local branch attached to the worktree for follow-up fixes: \`$QA_QA_BRANCH\`
- do not continue the review from the original local checkout after setup
- state file: [qa-env.env]($QA_METADATA_DIR/qa-env.env)
- continue with the helper wrappers so commands cannot drift back to the original checkout, for example:
  - \`scripts/qa-env.sh run --slug "$QA_SLUG" -- pwd\`
  - \`scripts/qa-env.sh git --slug "$QA_SLUG" -- status --short\`
  - \`scripts/qa-env.sh git --slug "$QA_SLUG" -- switch "$QA_QA_BRANCH"\`
  - \`scripts/qa-env.sh git --slug "$QA_SLUG" -- diff "$QA_BASE_REF...$QA_REF"\`
  - \`scripts/qa-env.sh compose --slug "$QA_SLUG" -- ps\`

## Fix Continuation

- if QA shows the PR does not satisfy the requirements, treat \`$QA_WORKTREE\` as the editable follow-up checkout
- for code changes, prefer opening a Codex session rooted at \`$QA_WORKTREE\`, which is already on local QA branch \`$QA_QA_BRANCH\`
- keep reusing the same slug \`$QA_SLUG\` for runtime checks so fixes are verified against the same environment
- while staying in the current thread, use the helper wrappers for runtime actions and reference files from \`$QA_WORKTREE\`
- to publish follow-up work on a separate branch, push \`$QA_QA_BRANCH\` from the worktree when ready

## Lifecycle

1. Create worktree at \`$QA_WORKTREE\` on local QA branch \`$QA_QA_BRANCH\`
2. Write \`compose.override.yaml\` and a managed \`.env.local\` block for this PR env
3. Run \`docker compose -p $QA_COMPOSE_PROJECT up -d --build\`
4. Run setup and optional post-setup hooks
5. Save command output to [run.log]($QA_ARTIFACTS_DIR/run.log)
EOF
}

write_changed_files_file() {
  local changed_files_file="$1"
  shift

  ensure_parent_dir "$changed_files_file"
  if [ "$#" -eq 0 ]; then
    : >"$changed_files_file"
    return 0
  fi

  printf '%s\n' "$@" >"$changed_files_file"
}

write_env_local() {
  local env_file="$1"
  local temp_file="${env_file}.tmp"

  if [ -f "$env_file" ]; then
    awk -v start="$ENV_MANAGED_BLOCK_START" -v end="$ENV_MANAGED_BLOCK_END" '
      $0 == start { skip = 1; next }
      $0 == end { skip = 0; next }
      !skip { print }
    ' "$env_file" >"$temp_file"
  else
    : >"$temp_file"
  fi

  if [ -s "$temp_file" ]; then
    printf '\n' >>"$temp_file"
  fi

  cat >>"$temp_file" <<EOF
$ENV_MANAGED_BLOCK_START
APP_URL=${QA_APP_URL}
DATABASE_URL=mysql://${QA_DB_USER}:${QA_DB_PASSWORD}@${QA_DB_HOST}:${QA_DB_PORT}/${QA_DB_NAME}
SYMFONY_TRUSTED_PROXIES=${QA_TRUSTED_PROXIES}
$ENV_MANAGED_BLOCK_END
EOF

  mv "$temp_file" "$env_file"
}

write_compose_override() {
  local compose_override_file="$1"

  cat >"$compose_override_file" <<EOF
services:
  web:
    ports: !override []
    environment:
      APP_URL: ${QA_APP_URL}
      DATABASE_URL: mysql://${QA_DB_USER}:${QA_DB_PASSWORD}@${QA_DB_HOST}:${QA_DB_PORT}/${QA_DB_NAME}
      SYMFONY_TRUSTED_PROXIES: '${QA_TRUSTED_PROXIES}'
  database:
    ports: !override []
    environment:
      MARIADB_DATABASE: ${QA_DB_NAME}
  adminer:
    ports: !override []
  valkey:
    ports: !override []
  mailer:
    ports: !override []
  opensearch:
    ports: !override []
EOF
}

run_in_dir_logged() {
  local dir="$1"
  shift
  local rendered

  rendered="$(join_for_shell "$@")"
  {
    printf '\n[cwd] %s\n' "$dir"
    printf '$ %s\n' "$rendered"
  } >>"$RUN_LOG"

  (
    cd "$dir"
    "$@"
  ) 2>&1 | tee -a "$RUN_LOG"
}

run_in_app_logged() {
  local command_text="$1"

  run_in_dir_logged "$CURRENT_WORKTREE" docker compose -p "$CURRENT_SLUG" exec -T "$QA_APP_SERVICE" sh -lc "$command_text"
}

resolve_modes_from_profile() {
  case "$QA_PROFILE" in
    auto)
      die "Internal error: profile should be resolved before mode selection."
      ;;
    fe-light | be-light)
      if [ "$QA_DEMODATA_MODE" = "auto" ]; then
        QA_DEMODATA_MODE="never"
      fi
      if [ "$QA_INDEXING_MODE" = "auto" ]; then
        QA_INDEXING_MODE="never"
      fi
      ;;
    be-fresh | search-indexed)
      if [ "$QA_DEMODATA_MODE" = "auto" ]; then
        QA_DEMODATA_MODE="always"
      fi
      if [ "$QA_INDEXING_MODE" = "auto" ]; then
        QA_INDEXING_MODE="always"
      fi
      ;;
    *)
      die "Unsupported profile: $QA_PROFILE"
      ;;
  esac
}

enforce_mode_constraints() {
  QA_MODE_NOTE=""

  if [ "$QA_DEMODATA_MODE" = "always" ] && [ "$QA_INDEXING_MODE" != "always" ]; then
    QA_INDEXING_MODE="always"
    QA_MODE_NOTE="Indexing was forced to always because demo data was enabled; storefront visibility depends on refreshed indexes."
  fi
}

detect_default_base_ref() {
  local repo="$1"
  local candidate=""

  candidate="$(git -C "$repo" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null || true)"
  if [ -n "$candidate" ]; then
    printf '%s' "$candidate"
    return 0
  fi

  for candidate in origin/trunk origin/main origin/master trunk main master; do
    if git -C "$repo" rev-parse --verify --quiet "$candidate" >/dev/null 2>&1; then
      printf '%s' "$candidate"
      return 0
    fi
  done

  printf ''
}

is_frontend_or_static_file() {
  local file="$1"

  case "$file" in
    src/Administration/* | src/Storefront/* | tests/e2e/* | tests/acceptance/* | \
    *.md | *.txt | *.png | *.jpg | *.jpeg | *.gif | *.svg | *.css | *.scss | *.sass | \
    *.less | *.js | *.mjs | *.cjs | *.ts | *.tsx | *.vue | *.twig)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

is_search_sensitive_file() {
  local file="$1"

  case "$file" in
    src/Elasticsearch/* | src/Core/Framework/DataAbstractionLayer/Indexing/* | \
    *Indexer*.php | *indexer*.php | */Search/* | *Search*.php | *search*.php)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

is_backend_light_file() {
  local file="$1"

  case "$file" in
    src/Core/Framework/Adapter/Cache/* | \
    src/Core/Framework/DependencyInjection/* | \
    src/Core/Framework/Log/* | \
    src/Core/Framework/Util/* | \
    src/Core/Framework/Uuid/* | \
    src/Core/Framework/Validation/* | \
    src/Core/DevOps/* | \
    tests/unit/* | \
    *.editorconfig | *.neon | *.xml.dist | *.json.dist)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

is_stateful_backend_file() {
  local file="$1"

  case "$file" in
    src/Core/Content/* | \
    src/Core/Checkout/* | \
    src/Core/System/* | \
    src/Core/Framework/Api/* | \
    src/Core/Framework/StoreApi/* | \
    src/Core/Framework/DataAbstractionLayer/* | \
    src/Core/Framework/MessageQueue/* | \
    src/Core/Migration/* | \
    tests/integration/* | \
    tests/migration/*)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

classify_changed_files() {
  local frontend_only="true"
  local backend_light_only="true"
  local backend_light="false"
  local stateful_backend="false"
  local search_sensitive="false"
  local file

  if [ "$#" -eq 0 ]; then
    QA_PROFILE="be-fresh"
    QA_PROFILE_SOURCE="auto-fallback"
    QA_DETECTION_REASON="No changed files detected from diff; falling back to be-fresh for safety."
    return 0
  fi

  for file in "$@"; do
    if is_frontend_or_static_file "$file"; then
      continue
    fi

    frontend_only="false"

    if is_search_sensitive_file "$file"; then
      search_sensitive="true"
      stateful_backend="true"
      backend_light_only="false"
      continue
    fi

    if is_stateful_backend_file "$file"; then
      stateful_backend="true"
      backend_light_only="false"
      continue
    fi

    if is_backend_light_file "$file"; then
      backend_light="true"
      continue
    fi

    stateful_backend="true"
    backend_light_only="false"
  done

  if [ "$frontend_only" = "true" ]; then
    QA_PROFILE="fe-light"
    QA_PROFILE_SOURCE="auto"
    QA_DETECTION_REASON="All changed files look frontend-only or static-doc changes; skipping demo data and indexing by default."
  elif [ "$search_sensitive" = "true" ]; then
    QA_PROFILE="search-indexed"
    QA_PROFILE_SOURCE="auto"
    QA_DETECTION_REASON="Detected backend search/indexing-related files; including demo data and index refresh."
  elif [ "$stateful_backend" = "true" ]; then
    QA_PROFILE="be-fresh"
    QA_PROFILE_SOURCE="auto"
    QA_DETECTION_REASON="Detected stateful Shopware backend changes affecting real domain behavior; including demo data and index refresh."
  elif [ "$backend_light_only" = "true" ] && [ "$backend_light" = "true" ]; then
    QA_PROFILE="be-light"
    QA_PROFILE_SOURCE="auto"
    QA_DETECTION_REASON="Detected infrastructure-only backend changes such as cache, dependency injection, or unit-test-level updates; skipping demo data and indexing by default."
  else
    QA_PROFILE="be-fresh"
    QA_PROFILE_SOURCE="auto"
    QA_DETECTION_REASON="Detected mixed or unclassified backend changes; including demo data and index refresh for safety."
  fi
}

resolve_profile_from_diff() {
  local changed_files=()

  if [ -z "$QA_BASE_REF" ]; then
    QA_BASE_REF="$(detect_default_base_ref "$QA_REPO")"
  fi

  if [ -z "$QA_BASE_REF" ]; then
    QA_PROFILE="be-fresh"
    QA_PROFILE_SOURCE="auto-fallback"
    QA_DETECTION_REASON="Could not determine a base ref for diff detection; falling back to be-fresh."
    QA_MERGE_BASE="not-determined"
    QA_CHANGED_FILES_COUNT="0"
    : >"$QA_CHANGED_FILES_FILE"
    return 0
  fi

  QA_MERGE_BASE="$(git -C "$QA_REPO" merge-base "$QA_BASE_REF" "$QA_REF" 2>/dev/null || true)"
  if [ -z "$QA_MERGE_BASE" ]; then
    QA_PROFILE="be-fresh"
    QA_PROFILE_SOURCE="auto-fallback"
    QA_DETECTION_REASON="Could not compute merge-base with $QA_BASE_REF; falling back to be-fresh."
    QA_MERGE_BASE="not-determined"
    QA_CHANGED_FILES_COUNT="0"
    : >"$QA_CHANGED_FILES_FILE"
    return 0
  fi

  while IFS= read -r file; do
    changed_files+=("$file")
  done < <(git -C "$QA_REPO" diff --name-only "$QA_MERGE_BASE" "$QA_REF")
  QA_CHANGED_FILES_COUNT="${#changed_files[@]}"
  write_changed_files_file "$QA_CHANGED_FILES_FILE" "${changed_files[@]}"
  classify_changed_files "${changed_files[@]}"
}

load_state_from_args() {
  local base_dir="$1"
  local slug="$2"
  local env_root="$3"
  local state_file=""

  if [ -n "$env_root" ]; then
    state_file="$env_root/env/qa-env.env"
  elif [ -n "$slug" ]; then
    state_file="$base_dir/$slug/env/qa-env.env"
  else
    die "Provide --slug or --env-root."
  fi

  [ -f "$state_file" ] || die "State file not found: $state_file"

  # shellcheck disable=SC1090
  source "$state_file"
  : "${QA_COMPOSE_OVERRIDE:=$QA_WORKTREE/compose.override.yaml}"
  : "${QA_PROFILE_REQUESTED:=$QA_PROFILE}"
  : "${QA_PROFILE_SOURCE:=unknown}"
  : "${QA_QA_BRANCH:=${QA_REVIEW_BRANCH:-unknown}}"
  : "${QA_REVIEW_BRANCH:=$QA_QA_BRANCH}"
  : "${QA_BRANCH_STATE:=unknown}"
  : "${QA_BASE_REF:=not-recorded}"
  : "${QA_MERGE_BASE:=not-recorded}"
  : "${QA_DETECTION_REASON:=not-recorded}"
  : "${QA_CHANGED_FILES_FILE:=$QA_ARTIFACTS_DIR/changed-files.txt}"
  : "${QA_CHANGED_FILES_COUNT:=0}"
  : "${QA_DB_PASSWORD:=$DEFAULT_DB_PASSWORD}"
  : "${QA_TRUSTED_PROXIES:=$DEFAULT_TRUSTED_PROXIES}"
  RUN_LOG="$QA_ARTIFACTS_DIR/run.log"
  RUN_SUMMARY="$QA_ARTIFACTS_DIR/run.md"
  CURRENT_WORKTREE="$QA_WORKTREE"
  CURRENT_SLUG="$QA_SLUG"
}

parse_env_selector_args() {
  local base_dir="$DEFAULT_BASE_DIR"
  local slug=""
  local env_root=""

  while [ "$#" -gt 0 ]; do
    case "$1" in
      --base-dir)
        base_dir="$2"
        shift 2
        ;;
      --slug)
        slug="$2"
        shift 2
        ;;
      --env-root)
        env_root="$2"
        shift 2
        ;;
      --)
        shift
        break
        ;;
      -h | --help)
        usage
        exit 0
        ;;
      *)
        break
        ;;
    esac
  done

  PARSED_BASE_DIR="$base_dir"
  PARSED_SLUG="$slug"
  PARSED_ENV_ROOT="$env_root"
  REMAINING_ARGS=("$@")
}

cmd_create() {
  local base_dir="$DEFAULT_BASE_DIR"
  local repo=""
  local ref=""
  local qa_branch=""
  local explicit_slug=""
  local pr_number=""
  local ticket=""
  local fetch_first="false"
  local setup_commands=()
  local after_setup_commands=()
  local demodata_command="bin/console framework:demodata"
  local index_command="bin/console dal:refresh:index"
  local base_ref=""

  QA_PROFILE="auto"
  QA_PROFILE_REQUESTED="auto"
  QA_PROFILE_SOURCE="manual"
  QA_APP_SERVICE="$DEFAULT_APP_SERVICE"
  QA_DB_SERVICE="$DEFAULT_DB_SERVICE"
  QA_DB_HOST="$DEFAULT_DB_HOST"
  QA_DB_PORT="$DEFAULT_DB_PORT"
  QA_DB_USER="$DEFAULT_DB_USER"
  QA_DB_PASSWORD="$DEFAULT_DB_PASSWORD"
  QA_TRUSTED_PROXIES="$DEFAULT_TRUSTED_PROXIES"
  QA_APP_URL=""
  QA_DEMODATA_MODE="auto"
  QA_INDEXING_MODE="auto"
  QA_MODE_NOTE=""
  QA_BASE_REF=""
  QA_MERGE_BASE="not-determined"
  QA_DETECTION_REASON="Profile was set manually."
  QA_CHANGED_FILES_COUNT="0"

  while [ "$#" -gt 0 ]; do
    case "$1" in
      --base-dir)
        base_dir="$2"
        shift 2
        ;;
      --repo)
        repo="$2"
        shift 2
        ;;
      --ref)
        ref="$2"
        shift 2
        ;;
      --branch)
        qa_branch="$2"
        shift 2
        ;;
      --slug)
        explicit_slug="$2"
        shift 2
        ;;
      --pr)
        pr_number="$2"
        shift 2
        ;;
      --ticket)
        ticket="$2"
        shift 2
        ;;
      --profile)
        QA_PROFILE="$2"
        QA_PROFILE_REQUESTED="$2"
        shift 2
        ;;
      --base-ref)
        base_ref="$2"
        shift 2
        ;;
      --fetch)
        fetch_first="true"
        shift
        ;;
      --app-service)
        QA_APP_SERVICE="$2"
        shift 2
        ;;
      --db-service)
        QA_DB_SERVICE="$2"
        shift 2
        ;;
      --db-host)
        QA_DB_HOST="$2"
        shift 2
        ;;
      --db-port)
        QA_DB_PORT="$2"
        shift 2
        ;;
      --db-user)
        QA_DB_USER="$2"
        shift 2
        ;;
      --db-password)
        QA_DB_PASSWORD="$2"
        shift 2
        ;;
      --app-url)
        QA_APP_URL="$2"
        shift 2
        ;;
      --setup-command)
        setup_commands+=("$2")
        shift 2
        ;;
      --demodata)
        QA_DEMODATA_MODE="$2"
        shift 2
        ;;
      --indexing)
        QA_INDEXING_MODE="$2"
        shift 2
        ;;
      --demodata-command)
        demodata_command="$2"
        shift 2
        ;;
      --index-command)
        index_command="$2"
        shift 2
        ;;
      --after-setup-command)
        after_setup_commands+=("$2")
        shift 2
        ;;
      -h | --help)
        usage
        exit 0
        ;;
      *)
        die "Unknown option for create: $1"
        ;;
    esac
  done

  [ -n "$repo" ] || die "--repo is required."
  [ -n "$ref" ] || die "--ref is required."

  need_cmd git
  need_cmd docker
  git -C "$repo" rev-parse --git-dir >/dev/null 2>&1 || die "Canonical repo does not look like a git repository: $repo"

  if [ "${#setup_commands[@]}" -eq 0 ]; then
    setup_commands=("composer setup")
  fi

  QA_SLUG="$(build_slug "$explicit_slug" "$pr_number" "$ticket" "$ref")"
  QA_REVIEW_BRANCH="$(build_qa_branch "$qa_branch" "$QA_SLUG")"
  QA_QA_BRANCH="$QA_REVIEW_BRANCH"
  QA_DB_NAME="$(build_db_name "$QA_SLUG")"
  QA_APP_URL="${QA_APP_URL:-${DEFAULT_APP_SCHEME}://${DEFAULT_APP_HOST_PREFIX}.${QA_SLUG}.orb.local}"
  QA_ENV_ROOT="$base_dir/$QA_SLUG"
  QA_WORKTREE="$QA_ENV_ROOT/worktree"
  QA_ARTIFACTS_DIR="$QA_ENV_ROOT/artifacts"
  QA_METADATA_DIR="$QA_ENV_ROOT/env"
  QA_COMPOSE_OVERRIDE="$QA_WORKTREE/compose.override.yaml"
  QA_COMPOSE_PROJECT="$QA_SLUG"
  QA_REPO="$repo"
  QA_REF="$ref"
  QA_BRANCH_STATE="pending"
  QA_BASE_REF="$base_ref"
  QA_PR_NUMBER="$pr_number"
  QA_TICKET="$ticket"
  QA_CHANGED_FILES_FILE="$QA_ARTIFACTS_DIR/changed-files.txt"

  [ ! -e "$QA_ENV_ROOT" ] || die "Env root already exists: $QA_ENV_ROOT"

  mkdir -p "$QA_ARTIFACTS_DIR" "$QA_METADATA_DIR"
  RUN_LOG="$QA_ARTIFACTS_DIR/run.log"
  RUN_SUMMARY="$QA_ARTIFACTS_DIR/run.md"
  CURRENT_WORKTREE="$QA_WORKTREE"
  CURRENT_SLUG="$QA_SLUG"

  : >"$RUN_LOG"
  write_state_file "$QA_METADATA_DIR/qa-env.env"
  write_summary_file "$RUN_SUMMARY"

  log "Creating QA env $QA_SLUG"
  if [ "$fetch_first" = "true" ]; then
    run_in_dir_logged "$QA_REPO" git fetch --all --prune
  fi

  if [ "$QA_PROFILE" = "auto" ]; then
    resolve_profile_from_diff
  else
    QA_PROFILE_SOURCE="manual"
    QA_DETECTION_REASON="Profile was set manually."
    : >"$QA_CHANGED_FILES_FILE"
  fi

  resolve_modes_from_profile
  enforce_mode_constraints
  write_state_file "$QA_METADATA_DIR/qa-env.env"
  write_summary_file "$RUN_SUMMARY"

  if git -C "$QA_REPO" rev-parse --verify --quiet "refs/heads/$QA_REVIEW_BRANCH" >/dev/null 2>&1; then
    QA_BRANCH_STATE="reused"
    run_in_dir_logged "$QA_REPO" git worktree add "$QA_WORKTREE" "$QA_REVIEW_BRANCH"
  else
    QA_BRANCH_STATE="created"
    run_in_dir_logged "$QA_REPO" git worktree add -b "$QA_REVIEW_BRANCH" "$QA_WORKTREE" "$QA_REF"
  fi
  write_state_file "$QA_METADATA_DIR/qa-env.env"
  write_summary_file "$RUN_SUMMARY"
  write_compose_override "$QA_COMPOSE_OVERRIDE"
  write_env_local "$QA_WORKTREE/.env.local"

  run_in_dir_logged "$QA_WORKTREE" docker compose -p "$QA_SLUG" up -d --build

  local setup_command
  if [ "${#setup_commands[@]}" -gt 0 ]; then
    for setup_command in "${setup_commands[@]}"; do
      run_in_app_logged "$setup_command"
    done
  fi

  if [ "$QA_DEMODATA_MODE" = "always" ]; then
    run_in_app_logged "$demodata_command"
  fi

  if [ "$QA_INDEXING_MODE" = "always" ]; then
    run_in_app_logged "$index_command"
  fi

  local after_command
  if [ "${#after_setup_commands[@]}" -gt 0 ]; then
    for after_command in "${after_setup_commands[@]}"; do
      run_in_app_logged "$after_command"
    done
  fi

  write_state_file "$QA_METADATA_DIR/qa-env.env"
  write_summary_file "$RUN_SUMMARY"

  log "QA env ready: $QA_APP_URL"
  log "Metadata: $RUN_SUMMARY"
}

cmd_access() {
  local base_dir="$DEFAULT_BASE_DIR"
  local slug=""
  local env_root=""

  while [ "$#" -gt 0 ]; do
    case "$1" in
      --base-dir)
        base_dir="$2"
        shift 2
        ;;
      --slug)
        slug="$2"
        shift 2
        ;;
      --env-root)
        env_root="$2"
        shift 2
        ;;
      -h | --help)
        usage
        exit 0
        ;;
      *)
        die "Unknown option for access: $1"
        ;;
    esac
  done

  load_state_from_args "$base_dir" "$slug" "$env_root"

  cat <<EOF
active_review_root=$QA_WORKTREE
qa_branch=$QA_QA_BRANCH
branch_state=$QA_BRANCH_STATE
source_ref=$QA_REF
app_url=$QA_APP_URL
compose_project=$QA_COMPOSE_PROJECT
database_name=$QA_DB_NAME
state_file=$QA_METADATA_DIR/qa-env.env
run_summary=$QA_ARTIFACTS_DIR/run.md
run_log=$QA_ARTIFACTS_DIR/run.log

next_steps:
- For code changes, open a Codex session rooted at: $QA_WORKTREE
- Continue implementation on local QA branch: $QA_QA_BRANCH
- Source ref is the original PR branch, tag, or commit under review: $QA_REF
- QA branch is the local worktree branch used for follow-up fixes: $QA_QA_BRANCH
- For worktree commands in the current thread: scripts/qa-env.sh run --slug $QA_SLUG -- <command>
- For git commands in the current thread: scripts/qa-env.sh git --slug $QA_SLUG -- <git args>
- For compose commands in the current thread: scripts/qa-env.sh compose --slug $QA_SLUG -- <compose args>
- For app-container commands in the current thread: scripts/qa-env.sh app --slug $QA_SLUG -- <command>
- To inspect local changes: scripts/qa-env.sh git --slug $QA_SLUG -- status --short
- To commit follow-up fixes: scripts/qa-env.sh git --slug $QA_SLUG -- commit -m "<message>"
- To publish the QA branch: scripts/qa-env.sh git --slug $QA_SLUG -- push -u origin $QA_QA_BRANCH
EOF
}

cmd_run() {
  parse_env_selector_args "$@"
  [ "${#REMAINING_ARGS[@]}" -gt 0 ] || die "Provide a command after -- for run."

  load_state_from_args "$PARSED_BASE_DIR" "$PARSED_SLUG" "$PARSED_ENV_ROOT"
  run_in_dir_logged "$QA_WORKTREE" "${REMAINING_ARGS[@]}"
}

cmd_git() {
  parse_env_selector_args "$@"
  [ "${#REMAINING_ARGS[@]}" -gt 0 ] || die "Provide git arguments after -- for git."

  load_state_from_args "$PARSED_BASE_DIR" "$PARSED_SLUG" "$PARSED_ENV_ROOT"
  run_in_dir_logged "$QA_WORKTREE" git -C "$QA_WORKTREE" "${REMAINING_ARGS[@]}"
}

cmd_compose() {
  parse_env_selector_args "$@"
  [ "${#REMAINING_ARGS[@]}" -gt 0 ] || die "Provide compose arguments after -- for compose."

  load_state_from_args "$PARSED_BASE_DIR" "$PARSED_SLUG" "$PARSED_ENV_ROOT"
  run_in_dir_logged "$QA_WORKTREE" docker compose -p "$QA_SLUG" "${REMAINING_ARGS[@]}"
}

cmd_app() {
  local base_dir="$DEFAULT_BASE_DIR"
  local slug=""
  local env_root=""
  local command_args=()
  local app_service_override=""

  while [ "$#" -gt 0 ]; do
    case "$1" in
      --base-dir)
        base_dir="$2"
        shift 2
        ;;
      --slug)
        slug="$2"
        shift 2
        ;;
      --env-root)
        env_root="$2"
        shift 2
        ;;
      --app-service)
        app_service_override="$2"
        shift 2
        ;;
      --)
        shift
        command_args=("$@")
        break
        ;;
      -h | --help)
        usage
        exit 0
        ;;
      *)
        die "Unknown option for app: $1"
        ;;
    esac
  done

  [ "${#command_args[@]}" -gt 0 ] || die "Provide a command after -- for app."
  load_state_from_args "$base_dir" "$slug" "$env_root"
  if [ -n "$app_service_override" ]; then
    QA_APP_SERVICE="$app_service_override"
  fi

  local test_command
  test_command="$(join_for_shell "${command_args[@]}")"
  run_in_app_logged "$test_command"
}

cmd_info() {
  local base_dir="$DEFAULT_BASE_DIR"
  local slug=""
  local env_root=""

  while [ "$#" -gt 0 ]; do
    case "$1" in
      --base-dir)
        base_dir="$2"
        shift 2
        ;;
      --slug)
        slug="$2"
        shift 2
        ;;
      --env-root)
        env_root="$2"
        shift 2
        ;;
      -h | --help)
        usage
        exit 0
        ;;
      *)
        die "Unknown option for info: $1"
        ;;
    esac
  done

  load_state_from_args "$base_dir" "$slug" "$env_root"

  cat <<EOF
slug=$QA_SLUG
profile=$QA_PROFILE
profile_requested=$QA_PROFILE_REQUESTED
profile_source=$QA_PROFILE_SOURCE
repo=$QA_REPO
source_ref=$QA_REF
qa_branch=$QA_QA_BRANCH
branch_state=$QA_BRANCH_STATE
base_ref=$QA_BASE_REF
merge_base=$QA_MERGE_BASE
worktree=$QA_WORKTREE
env_root=$QA_ENV_ROOT
artifacts=$QA_ARTIFACTS_DIR
app_url=$QA_APP_URL
compose_project=$QA_COMPOSE_PROJECT
app_service=$QA_APP_SERVICE
db_service=$QA_DB_SERVICE
db_name=$QA_DB_NAME
demodata=$QA_DEMODATA_MODE
indexing=$QA_INDEXING_MODE
changed_files=$QA_CHANGED_FILES_FILE
detection_reason=$QA_DETECTION_REASON
EOF

  if [ -d "$QA_WORKTREE" ]; then
    run_in_dir_logged "$QA_WORKTREE" docker compose -p "$QA_SLUG" ps || true
  fi
}

cmd_cleanup() {
  local base_dir="$DEFAULT_BASE_DIR"
  local slug=""
  local env_root=""
  local keep_worktree="false"
  local keep_volumes="false"

  while [ "$#" -gt 0 ]; do
    case "$1" in
      --base-dir)
        base_dir="$2"
        shift 2
        ;;
      --slug)
        slug="$2"
        shift 2
        ;;
      --env-root)
        env_root="$2"
        shift 2
        ;;
      --keep-worktree)
        keep_worktree="true"
        shift
        ;;
      --keep-volumes)
        keep_volumes="true"
        shift
        ;;
      -h | --help)
        usage
        exit 0
        ;;
      *)
        die "Unknown option for cleanup: $1"
        ;;
    esac
  done

  load_state_from_args "$base_dir" "$slug" "$env_root"

  if [ -d "$QA_WORKTREE" ]; then
    if [ "$keep_volumes" = "true" ]; then
      run_in_dir_logged "$QA_WORKTREE" docker compose -p "$QA_SLUG" down || true
    else
      run_in_dir_logged "$QA_WORKTREE" docker compose -p "$QA_SLUG" down -v || true
    fi
  fi

  if [ "$keep_worktree" = "false" ] && [ -d "$QA_WORKTREE" ]; then
    run_in_dir_logged "$QA_REPO" git worktree remove --force "$QA_WORKTREE"
  fi

  if [ "$keep_worktree" = "false" ] && [ -d "$QA_ENV_ROOT" ]; then
    rm -rf "$QA_ENV_ROOT"
  fi
}

main() {
  local command="${1:-}"

  case "$command" in
    create | up)
      shift
      cmd_create "$@"
      ;;
    access | handoff)
      shift
      cmd_access "$@"
      ;;
    run | repo)
      shift
      cmd_run "$@"
      ;;
    git)
      shift
      cmd_git "$@"
      ;;
    compose)
      shift
      cmd_compose "$@"
      ;;
    app | test)
      shift
      cmd_app "$@"
      ;;
    info | status)
      shift
      cmd_info "$@"
      ;;
    cleanup | down)
      shift
      cmd_cleanup "$@"
      ;;
    -h | --help | help | "")
      usage
      ;;
    *)
      die "Unknown command: $command"
      ;;
  esac
}

main "$@"
