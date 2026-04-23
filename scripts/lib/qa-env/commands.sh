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
runtime_root=$QA_ENV_ROOT
source_root_qa_dir=$QA_SOURCE_ROOT_QA_DIR
source_root_mode=$QA_SOURCE_ROOT_MODE
source_root_kind=$QA_SOURCE_ROOT_KIND
source_root_provider=$QA_SOURCE_ROOT_PROVIDER
qa_branch=$QA_QA_BRANCH
branch_state=$QA_BRANCH_STATE
source_ref=$QA_REF
app_url=$QA_APP_URL
adminer_url=$QA_ADMINER_URL
mailer_url=$QA_MAILER_URL
compose_project=$QA_COMPOSE_PROJECT
database_name=$QA_DB_NAME
database_url=$(build_db_url)
database_user=$QA_DB_USER
database_password=$QA_DB_PASSWORD
adminer_login_server=$QA_DB_HOST
adminer_login_user=$QA_DB_USER
adminer_login_password=$QA_DB_PASSWORD
adminer_login_database=$QA_DB_NAME
verify_storefront=$QA_VERIFY_STOREFRONT_MODE
verify_storefront_result=$QA_VERIFY_STOREFRONT_RESULT
state_file=$QA_METADATA_DIR/qa-env.env
run_summary=$QA_ARTIFACTS_DIR/run.md
run_log=$QA_ARTIFACTS_DIR/run.log

next_steps:
- For code changes, open a Codex session rooted at: $QA_WORKTREE
- QA runtime metadata stays under: $QA_ENV_ROOT
- Source-root QA pointer lives under: $QA_SOURCE_ROOT_QA_DIR
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
  run_compose_logged "${REMAINING_ARGS[@]}"
}

cmd_app() {
  local base_dir="$DEFAULT_BASE_DIR"
  local slug=""
  local env_root=""
  local -a command_args=()
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
source_root_mode=$QA_SOURCE_ROOT_MODE
source_root_kind=$QA_SOURCE_ROOT_KIND
source_root_provider=$QA_SOURCE_ROOT_PROVIDER
qa_branch=$QA_QA_BRANCH
branch_state=$QA_BRANCH_STATE
base_ref=$QA_BASE_REF
merge_base=$QA_MERGE_BASE
worktree=$QA_WORKTREE
source_root_qa_dir=$QA_SOURCE_ROOT_QA_DIR
env_root=$QA_ENV_ROOT
artifacts=$QA_ARTIFACTS_DIR
primary_compose_file=$QA_PRIMARY_COMPOSE_FILE
app_url=$QA_APP_URL
adminer_url=$QA_ADMINER_URL
mailer_url=$QA_MAILER_URL
compose_project=$QA_COMPOSE_PROJECT
app_service=$QA_APP_SERVICE
db_service=$QA_DB_SERVICE
db_name=$QA_DB_NAME
db_url=$(build_db_url)
db_user=$QA_DB_USER
db_password=$QA_DB_PASSWORD
adminer_login_server=$QA_DB_HOST
adminer_login_user=$QA_DB_USER
adminer_login_password=$QA_DB_PASSWORD
adminer_login_database=$QA_DB_NAME
demodata=$QA_DEMODATA_MODE
indexing=$QA_INDEXING_MODE
verify_storefront=$QA_VERIFY_STOREFRONT_MODE
verify_storefront_result=$QA_VERIFY_STOREFRONT_RESULT
changed_files=$QA_CHANGED_FILES_FILE
detection_reason=$QA_DETECTION_REASON
EOF

  if [ -d "$QA_WORKTREE" ]; then
    run_compose_logged ps || true
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
      run_compose_logged down || true
    else
      run_compose_logged down -v || true
    fi
  fi

  if [ -d "$QA_WORKTREE" ]; then
    remove_env_local_managed_block "$QA_WORKTREE/.env.local"
    remove_source_root_pointer
  fi

  if [ -f "$QA_COMPOSE_OVERRIDE" ]; then
    rm -f "$QA_COMPOSE_OVERRIDE"
  fi

  if [ -f "$QA_WORKTREE/compose.override.yaml" ] && [ "$QA_WORKTREE/compose.override.yaml" != "$QA_COMPOSE_OVERRIDE" ]; then
    rm -f "$QA_WORKTREE/compose.override.yaml"
  fi

  if [ "$keep_worktree" = "false" ] && [ "$QA_SOURCE_ROOT_OWNERSHIP" = "managed" ] && [ -d "$QA_WORKTREE" ]; then
    run_in_dir_logged "$QA_REPO" git worktree remove --force "$QA_WORKTREE"
  fi

  if [ -d "$QA_ENV_ROOT" ] && ! { [ "$QA_SOURCE_ROOT_OWNERSHIP" = "managed" ] && [ "$keep_worktree" = "true" ]; }; then
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
    compose | docker)
      shift
      cmd_compose "$@"
      ;;
    app | exec)
      shift
      cmd_app "$@"
      ;;
    info | status)
      shift
      cmd_info "$@"
      ;;
    cleanup | down | destroy)
      shift
      cmd_cleanup "$@"
      ;;
    "" | -h | --help | help)
      usage
      ;;
    *)
      usage
      die "Unknown command: $command"
      ;;
  esac
}
