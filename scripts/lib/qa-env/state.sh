write_state_file() {
  local state_file="$1"

  ensure_parent_dir "$state_file"
  {
    printf 'QA_ENV_ROOT=%q\n' "$QA_ENV_ROOT"
    printf 'QA_WORKTREE=%q\n' "$QA_WORKTREE"
    printf 'QA_ARTIFACTS_DIR=%q\n' "$QA_ARTIFACTS_DIR"
    printf 'QA_METADATA_DIR=%q\n' "$QA_METADATA_DIR"
    printf 'QA_COMPOSE_OVERRIDE=%q\n' "$QA_COMPOSE_OVERRIDE"
    printf 'QA_SOURCE_ROOT_QA_DIR=%q\n' "$QA_SOURCE_ROOT_QA_DIR"
    printf 'QA_SLUG=%q\n' "$QA_SLUG"
    printf 'QA_PROFILE_REQUESTED=%q\n' "$QA_PROFILE_REQUESTED"
    printf 'QA_PROFILE_SOURCE=%q\n' "$QA_PROFILE_SOURCE"
    printf 'QA_PROFILE=%q\n' "$QA_PROFILE"
    printf 'QA_SOURCE_ROOT_MODE_REQUESTED=%q\n' "$QA_SOURCE_ROOT_MODE_REQUESTED"
    printf 'QA_SOURCE_ROOT_MODE=%q\n' "$QA_SOURCE_ROOT_MODE"
    printf 'QA_SOURCE_ROOT_KIND=%q\n' "$QA_SOURCE_ROOT_KIND"
    printf 'QA_SOURCE_ROOT_PROVIDER=%q\n' "$QA_SOURCE_ROOT_PROVIDER"
    printf 'QA_SOURCE_ROOT_OWNERSHIP=%q\n' "$QA_SOURCE_ROOT_OWNERSHIP"
    printf 'QA_PRIMARY_COMPOSE_FILE=%q\n' "$QA_PRIMARY_COMPOSE_FILE"
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
    printf 'QA_ADMINER_URL=%q\n' "$QA_ADMINER_URL"
    printf 'QA_MAILER_URL=%q\n' "$QA_MAILER_URL"
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
    printf 'QA_VERIFY_STOREFRONT_MODE=%q\n' "$QA_VERIFY_STOREFRONT_MODE"
    printf 'QA_VERIFY_STOREFRONT_RESULT=%q\n' "$QA_VERIFY_STOREFRONT_RESULT"
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
- source root mode requested: \`$QA_SOURCE_ROOT_MODE_REQUESTED\`
- source root mode resolved: \`$QA_SOURCE_ROOT_MODE\`
- source root kind: \`$QA_SOURCE_ROOT_KIND\`
- source root provider: \`$QA_SOURCE_ROOT_PROVIDER\`
- repo: \`$QA_REPO\`
- source ref: \`$QA_REF\`
- qa branch: \`$QA_QA_BRANCH\`
- branch state: \`$QA_BRANCH_STATE\`
- base ref: \`$QA_BASE_REF\`
- merge base: \`$QA_MERGE_BASE\`
- worktree: \`$QA_WORKTREE\`
- source-root qa dir: \`$QA_SOURCE_ROOT_QA_DIR\`
- compose override: \`$QA_COMPOSE_OVERRIDE\`
- primary compose file: \`$QA_PRIMARY_COMPOSE_FILE\`
- compose project: \`$QA_COMPOSE_PROJECT\`
- app url: [$QA_APP_URL]($QA_APP_URL)
- adminer url: [$QA_ADMINER_URL]($QA_ADMINER_URL)
- mailer url: [$QA_MAILER_URL]($QA_MAILER_URL)
- app service: \`$QA_APP_SERVICE\`
- db service: \`$QA_DB_SERVICE\`
- db name: \`$QA_DB_NAME\`
- db url: \`$(build_db_url)\`
- demo data: \`$QA_DEMODATA_MODE\`
- indexing: \`$QA_INDEXING_MODE\`
- storefront verification: \`$QA_VERIFY_STOREFRONT_MODE\`
- storefront verification result: \`$QA_VERIFY_STOREFRONT_RESULT\`
- setup note: ${QA_MODE_NOTE:-none}
- changed files: \`$QA_CHANGED_FILES_COUNT\` (see [$QA_CHANGED_FILES_FILE]($QA_CHANGED_FILES_FILE))
- detection: $QA_DETECTION_REASON

## Environment Access

- app url: [$QA_APP_URL]($QA_APP_URL)
- adminer url: [$QA_ADMINER_URL]($QA_ADMINER_URL)
- mailer url: [$QA_MAILER_URL]($QA_MAILER_URL)
- worktree path: \`$QA_WORKTREE\`
- runtime root: \`$QA_ENV_ROOT\`
- source-root qa dir: \`$QA_SOURCE_ROOT_QA_DIR\`
- qa branch: \`$QA_QA_BRANCH\`
- compose project: \`$QA_COMPOSE_PROJECT\`
- database name: \`$QA_DB_NAME\`
- database url: \`$(build_db_url)\`
- database credentials: user=\`$QA_DB_USER\` password=\`$QA_DB_PASSWORD\`
- adminer login: server=\`$QA_DB_HOST\` user=\`$QA_DB_USER\` password=\`$QA_DB_PASSWORD\` database=\`$QA_DB_NAME\`
- compose override: [compose.override.yaml]($QA_COMPOSE_OVERRIDE)
- env state: [qa-env.env]($QA_METADATA_DIR/qa-env.env)
- artifacts:
  - [run.md]($QA_ARTIFACTS_DIR/run.md)
  - [run.log]($QA_ARTIFACTS_DIR/run.log)
  - [changed-files.txt]($QA_CHANGED_FILES_FILE)

## Worktree Access

- active QA source tree: \`$QA_WORKTREE\`
- runtime root for metadata and cleanup: \`$QA_ENV_ROOT\`
- active QA branch: \`$QA_QA_BRANCH\`
- source ref stays the original PR branch, tag, or commit being reviewed: \`$QA_REF\`
- QA branch is the local branch attached to the worktree for follow-up fixes: \`$QA_QA_BRANCH\`
- do not continue the review from the original local checkout after setup
- state file: [qa-env.env]($QA_METADATA_DIR/qa-env.env)
- source-root pointer: [current]($QA_SOURCE_ROOT_QA_DIR/current)
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

1. Select the active QA source tree at \`$QA_WORKTREE\` on local QA branch \`$QA_QA_BRANCH\`
2. Write \`$QA_COMPOSE_OVERRIDE\` and a managed \`.env.local\` block for this PR env
3. Run \`docker compose -f $QA_PRIMARY_COMPOSE_FILE -f $QA_COMPOSE_OVERRIDE -p $QA_COMPOSE_PROJECT up -d --build\`
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

remove_env_local_managed_block() {
  local env_file="$1"
  local temp_file="${env_file}.tmp"

  [ -f "$env_file" ] || return 0

  awk -v start="$ENV_MANAGED_BLOCK_START" -v end="$ENV_MANAGED_BLOCK_END" '
    $0 == start { skip = 1; next }
    $0 == end { skip = 0; next }
    !skip { print }
  ' "$env_file" >"$temp_file"

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
  if [ -z "${QA_COMPOSE_OVERRIDE:-}" ]; then
    if [ -f "$QA_METADATA_DIR/compose.override.yaml" ]; then
      QA_COMPOSE_OVERRIDE="$QA_METADATA_DIR/compose.override.yaml"
    elif [ -f "$QA_WORKTREE/compose.override.yaml" ]; then
      QA_COMPOSE_OVERRIDE="$QA_WORKTREE/compose.override.yaml"
    else
      QA_COMPOSE_OVERRIDE="$QA_METADATA_DIR/compose.override.yaml"
    fi
  fi
  : "${QA_SOURCE_ROOT_MODE_REQUESTED:=auto}"
  : "${QA_SOURCE_ROOT_MODE:=managed}"
  : "${QA_SOURCE_ROOT_KIND:=managed-worktree}"
  : "${QA_SOURCE_ROOT_PROVIDER:=qa-env}"
  : "${QA_SOURCE_ROOT_OWNERSHIP:=managed}"
  : "${QA_SOURCE_ROOT_QA_DIR:=$QA_WORKTREE/.qa}"
  : "${QA_PRIMARY_COMPOSE_FILE:=$(detect_compose_file "$QA_WORKTREE")}"
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
  : "${QA_DB_NAME:=$DEFAULT_DB_NAME}"
  : "${QA_DB_PASSWORD:=$DEFAULT_DB_PASSWORD}"
  : "${QA_TRUSTED_PROXIES:=$DEFAULT_TRUSTED_PROXIES}"
  : "${QA_ADMINER_URL:=$(build_service_url "$DEFAULT_ADMINER_HOST_PREFIX" "$QA_SLUG")}"
  : "${QA_MAILER_URL:=$(build_service_url "$DEFAULT_MAILER_HOST_PREFIX" "$QA_SLUG")}"
  : "${QA_VERIFY_STOREFRONT_MODE:=auto}"
  : "${QA_VERIFY_STOREFRONT_RESULT:=not-run}"
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

persist_runtime_metadata() {
  write_state_file "$QA_METADATA_DIR/qa-env.env"
  write_summary_file "$RUN_SUMMARY"
}
