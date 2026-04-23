initialize_create_source_root_context() {
  local source_root_mode_requested="$1"
  local requested_qa_branch="$2"

  mkdir -p "$QA_ARTIFACTS_DIR" "$QA_METADATA_DIR"
  resolve_source_root_mode "$source_root_mode_requested" "$QA_REPO"
  if [ "$QA_SOURCE_ROOT_OWNERSHIP" = "managed" ]; then
    QA_WORKTREE="$QA_ENV_ROOT/worktree"
  fi
  QA_SOURCE_ROOT_QA_DIR="$QA_WORKTREE/.qa"
  QA_QA_BRANCH="$(resolve_qa_branch_name "$requested_qa_branch" "$QA_SLUG" "$QA_CURRENT_SOURCE_BRANCH")"
  QA_REVIEW_BRANCH="$QA_QA_BRANCH"
  RUN_LOG="$QA_ARTIFACTS_DIR/run.log"
  RUN_SUMMARY="$QA_ARTIFACTS_DIR/run.md"
  CURRENT_WORKTREE="$QA_WORKTREE"
  CURRENT_SLUG="$QA_SLUG"
}

attach_create_qa_branch() {
  if [ "$QA_SOURCE_ROOT_OWNERSHIP" = "managed" ]; then
    if git -C "$QA_REPO" rev-parse --verify --quiet "refs/heads/$QA_QA_BRANCH" >/dev/null 2>&1; then
      QA_BRANCH_STATE="reused"
      run_in_dir_logged "$QA_REPO" git worktree add "$QA_WORKTREE" "$QA_QA_BRANCH"
    else
      QA_BRANCH_STATE="created"
      run_in_dir_logged "$QA_REPO" git worktree add -b "$QA_QA_BRANCH" "$QA_WORKTREE" "$QA_REF"
    fi
    return 0
  fi

  if [ "$QA_CURRENT_SOURCE_BRANCH" = "$QA_QA_BRANCH" ]; then
    QA_BRANCH_STATE="current"
  elif git -C "$QA_REPO" rev-parse --verify --quiet "refs/heads/$QA_QA_BRANCH" >/dev/null 2>&1; then
    QA_BRANCH_STATE="switched"
    run_in_dir_logged "$QA_WORKTREE" git switch "$QA_QA_BRANCH"
  elif [ "$QA_CURRENT_SOURCE_BRANCH" = "HEAD" ]; then
    QA_BRANCH_STATE="created"
    run_in_dir_logged "$QA_WORKTREE" git switch -c "$QA_QA_BRANCH" "$QA_REF"
  else
    QA_BRANCH_STATE="created"
    run_in_dir_logged "$QA_WORKTREE" git switch -c "$QA_QA_BRANCH"
  fi
}

prepare_create_runtime_files() {
  QA_PRIMARY_COMPOSE_FILE="$(detect_compose_file "$QA_WORKTREE")"
  persist_runtime_metadata
  write_compose_override "$QA_COMPOSE_OVERRIDE"
  write_env_local "$QA_WORKTREE/.env.local"
  write_source_root_pointer
}

cmd_create() {
  local base_dir="$DEFAULT_BASE_DIR"
  local repo=""
  local ref=""
  local qa_branch=""
  local source_root_mode_requested="$DEFAULT_SOURCE_ROOT_MODE"
  local verify_storefront_mode="auto"
  local explicit_slug=""
  local pr_number=""
  local ticket=""
  local fetch_first="false"
  local -a setup_commands=()
  local -a main_process_commands=()
  local -a after_setup_commands=()
  local demodata_command="bin/console framework:demodata"
  local index_command="bin/console dal:refresh:index"
  local base_ref=""
  local copy_system_config_from_container=""
  local -a copy_system_config_keys=()
  local -a runtime_package_roots=()
  local -a runtime_package_dirs=()
  local include_test_package_dirs="false"

  QA_PROFILE="auto"
  QA_PROFILE_REQUESTED="auto"
  QA_PROFILE_SOURCE="manual"
  QA_SOURCE_ROOT_MODE_REQUESTED="$DEFAULT_SOURCE_ROOT_MODE"
  QA_SOURCE_ROOT_MODE="managed"
  QA_SOURCE_ROOT_KIND="managed-worktree"
  QA_SOURCE_ROOT_PROVIDER="qa-env"
  QA_SOURCE_ROOT_OWNERSHIP="managed"
  QA_APP_SERVICE="$DEFAULT_APP_SERVICE"
  QA_DB_SERVICE="$DEFAULT_DB_SERVICE"
  QA_DB_HOST="$DEFAULT_DB_HOST"
  QA_DB_PORT="$DEFAULT_DB_PORT"
  QA_DB_USER="$DEFAULT_DB_USER"
  QA_DB_PASSWORD="$DEFAULT_DB_PASSWORD"
  QA_DB_NAME="$DEFAULT_DB_NAME"
  QA_TRUSTED_PROXIES="$DEFAULT_TRUSTED_PROXIES"
  QA_APP_URL=""
  QA_DEMODATA_MODE="auto"
  QA_INDEXING_MODE="auto"
  QA_VERIFY_STOREFRONT_MODE="auto"
  QA_VERIFY_STOREFRONT_RESULT="not-run"
  QA_MODE_NOTE=""
  QA_BASE_REF=""
  QA_MERGE_BASE="not-determined"
  QA_DETECTION_REASON="Profile was set manually."
  QA_CHANGED_FILES_COUNT="0"
  QA_PRIMARY_COMPOSE_FILE=""

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
      --source-root-mode)
        source_root_mode_requested="$2"
        QA_SOURCE_ROOT_MODE_REQUESTED="$2"
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
      --db-name)
        QA_DB_NAME="$2"
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
      --main-process-command)
        main_process_commands+=("$2")
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
      --verify-storefront)
        verify_storefront_mode="$2"
        QA_VERIFY_STOREFRONT_MODE="$2"
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
      --copy-system-config-from-container)
        copy_system_config_from_container="$2"
        shift 2
        ;;
      --copy-system-config-key)
        copy_system_config_keys+=("$2")
        shift 2
        ;;
      --runtime-package-root)
        runtime_package_roots+=("$2")
        shift 2
        ;;
      --runtime-package-dir)
        runtime_package_dirs+=("$2")
        shift 2
        ;;
      --include-test-package-dirs)
        include_test_package_dirs="true"
        shift
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
  repo="$(resolve_dir "$repo")"

  if [ "${#setup_commands[@]}" -eq 0 ]; then
    setup_commands=("composer setup")
  fi

  QA_SLUG="$(build_slug "$explicit_slug" "$pr_number" "$ticket" "$ref")"
  QA_DB_NAME="${QA_DB_NAME:-$(build_db_name "$QA_SLUG")}"
  QA_APP_URL="${QA_APP_URL:-${DEFAULT_APP_SCHEME}://${DEFAULT_APP_HOST_PREFIX}.${QA_SLUG}.orb.local}"
  QA_ADMINER_URL="$(build_service_url "$DEFAULT_ADMINER_HOST_PREFIX" "$QA_SLUG")"
  QA_MAILER_URL="$(build_service_url "$DEFAULT_MAILER_HOST_PREFIX" "$QA_SLUG")"
  QA_ENV_ROOT="$base_dir/$QA_SLUG"
  QA_ARTIFACTS_DIR="$QA_ENV_ROOT/artifacts"
  QA_METADATA_DIR="$QA_ENV_ROOT/env"
  QA_COMPOSE_OVERRIDE="$QA_METADATA_DIR/compose.override.yaml"
  QA_COMPOSE_PROJECT="$QA_SLUG"
  QA_REPO="$repo"
  QA_REF="$ref"
  QA_BRANCH_STATE="pending"
  QA_BASE_REF="$base_ref"
  QA_PR_NUMBER="$pr_number"
  QA_TICKET="$ticket"
  QA_CHANGED_FILES_FILE="$QA_ARTIFACTS_DIR/changed-files.txt"

  [ ! -e "$QA_ENV_ROOT" ] || die "Env root already exists: $QA_ENV_ROOT"

  initialize_create_source_root_context "$source_root_mode_requested" "$qa_branch"

  : >"$RUN_LOG"
  persist_runtime_metadata

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
  persist_runtime_metadata

  attach_create_qa_branch
  prepare_create_runtime_files

  run_compose_logged up -d --build

  if [ "${#setup_commands[@]}" -gt 0 ]; then
    run_app_commands "${setup_commands[@]}"
  fi
  run_mode_enabled_app_command "$QA_DEMODATA_MODE" "$demodata_command"
  run_mode_enabled_app_command "$QA_INDEXING_MODE" "$index_command"
  if [ -n "$copy_system_config_from_container" ] || [ "${#copy_system_config_keys[@]}" -gt 0 ]; then
    if [ "${#copy_system_config_keys[@]}" -gt 0 ]; then
      run_create_system_config_phase "$copy_system_config_from_container" "${copy_system_config_keys[@]}"
    else
      run_create_system_config_phase "$copy_system_config_from_container"
    fi
  fi
  if [ "${#main_process_commands[@]}" -gt 0 ]; then
    run_app_commands "${main_process_commands[@]}"
  fi
  if [ "${#runtime_package_roots[@]}" -gt 0 ] || [ "${#runtime_package_dirs[@]}" -gt 0 ]; then
    run_create_runtime_package_phase \
      "$include_test_package_dirs" \
      "${runtime_package_roots[@]}" \
      -- \
      "${runtime_package_dirs[@]}"
  fi
  if [ "${#after_setup_commands[@]}" -gt 0 ]; then
    run_app_commands "${after_setup_commands[@]}"
  fi

  verify_storefront_readiness "$verify_storefront_mode"

  persist_runtime_metadata

  log "QA env ready: $QA_APP_URL"
  log "Metadata: $RUN_SUMMARY"
}
