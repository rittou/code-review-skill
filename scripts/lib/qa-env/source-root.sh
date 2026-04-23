detect_host_system() {
  if [ -n "${CODEX_THREAD_ID:-}" ] || [ -d "$CODEX_WORKTREES_ROOT" ]; then
    printf 'codex'
    return 0
  fi

  printf 'unknown'
}

git_root() {
  local path="$1"

  git -C "$path" rev-parse --show-toplevel 2>/dev/null || true
}

git_common_dir() {
  local path="$1"

  git -C "$path" rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true
}

git_branch_name() {
  local path="$1"

  git -C "$path" rev-parse --abbrev-ref HEAD 2>/dev/null || true
}

git_path() {
  local path="$1"
  local subpath="$2"

  git -C "$path" rev-parse --path-format=absolute --git-path "$subpath" 2>/dev/null || true
}

paths_equal() {
  local first="$1"
  local second="$2"
  local first_resolved=""
  local second_resolved=""

  first_resolved="$(resolve_dir "$first" 2>/dev/null || true)"
  second_resolved="$(resolve_dir "$second" 2>/dev/null || true)"
  [ -n "$first_resolved" ] && [ "$first_resolved" = "$second_resolved" ]
}

same_git_repository() {
  local first="$1"
  local second="$2"
  local first_common=""
  local second_common=""

  first_common="$(git_common_dir "$first")"
  second_common="$(git_common_dir "$second")"
  [ -n "$first_common" ] && [ "$first_common" = "$second_common" ]
}

path_is_within() {
  local path="$1"
  local root="$2"
  local resolved_path=""
  local resolved_root=""

  resolved_path="$(resolve_dir "$path" 2>/dev/null || true)"
  resolved_root="$(resolve_dir "$root" 2>/dev/null || true)"

  [ -n "$resolved_path" ] || return 1
  [ -n "$resolved_root" ] || return 1

  case "$resolved_path/" in
    "$resolved_root/"*)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

detect_current_source_context() {
  local repo="$1"
  local session_root=""
  local host_system=""

  QA_CURRENT_SOURCE_ROOT=""
  QA_CURRENT_SOURCE_KIND="unavailable"
  QA_CURRENT_SOURCE_PROVIDER="unknown"
  QA_CURRENT_SOURCE_BRANCH=""

  session_root="$(git_root "$PWD")"
  [ -n "$session_root" ] || return 0
  same_git_repository "$session_root" "$repo" || return 0

  host_system="$(detect_host_system)"
  QA_CURRENT_SOURCE_ROOT="$session_root"
  QA_CURRENT_SOURCE_BRANCH="$(git_branch_name "$session_root")"

  if path_is_within "$session_root" "$CODEX_WORKTREES_ROOT"; then
    QA_CURRENT_SOURCE_KIND="system-worktree"
    QA_CURRENT_SOURCE_PROVIDER="$host_system"
    return 0
  fi

  if ! paths_equal "$session_root" "$repo"; then
    QA_CURRENT_SOURCE_KIND="current-worktree"
    QA_CURRENT_SOURCE_PROVIDER="current-session"
    return 0
  fi

  QA_CURRENT_SOURCE_KIND="current-checkout"
  QA_CURRENT_SOURCE_PROVIDER="current-session"
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
  local _slug="$1"
  printf '%s' "$DEFAULT_DB_NAME"
}

build_db_url() {
  printf 'mysql://%s:%s@%s:%s/%s' \
    "$QA_DB_USER" \
    "$QA_DB_PASSWORD" \
    "$QA_DB_HOST" \
    "$QA_DB_PORT" \
    "$QA_DB_NAME"
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

resolve_source_root_mode() {
  local requested_mode="$1"
  local repo="$2"

  detect_current_source_context "$repo"

  case "$requested_mode" in
    auto)
      case "$QA_CURRENT_SOURCE_KIND" in
        system-worktree | current-worktree)
          QA_SOURCE_ROOT_MODE="reused"
          QA_SOURCE_ROOT_KIND="$QA_CURRENT_SOURCE_KIND"
          QA_SOURCE_ROOT_PROVIDER="$QA_CURRENT_SOURCE_PROVIDER"
          QA_SOURCE_ROOT_OWNERSHIP="reused"
          QA_WORKTREE="$QA_CURRENT_SOURCE_ROOT"
          ;;
        *)
          QA_SOURCE_ROOT_MODE="managed"
          QA_SOURCE_ROOT_KIND="managed-worktree"
          QA_SOURCE_ROOT_PROVIDER="qa-env"
          QA_SOURCE_ROOT_OWNERSHIP="managed"
          ;;
      esac
      ;;
    managed)
      QA_SOURCE_ROOT_MODE="managed"
      QA_SOURCE_ROOT_KIND="managed-worktree"
      QA_SOURCE_ROOT_PROVIDER="qa-env"
      QA_SOURCE_ROOT_OWNERSHIP="managed"
      ;;
    system)
      [ "$QA_CURRENT_SOURCE_KIND" = "system-worktree" ] || die "Current session is not rooted at a supported system-managed worktree for $repo."
      QA_SOURCE_ROOT_MODE="reused"
      QA_SOURCE_ROOT_KIND="$QA_CURRENT_SOURCE_KIND"
      QA_SOURCE_ROOT_PROVIDER="$QA_CURRENT_SOURCE_PROVIDER"
      QA_SOURCE_ROOT_OWNERSHIP="reused"
      QA_WORKTREE="$QA_CURRENT_SOURCE_ROOT"
      ;;
    current)
      [ "$QA_CURRENT_SOURCE_KIND" != "unavailable" ] || die "Current session is not rooted at a git checkout for $repo."
      QA_SOURCE_ROOT_MODE="reused"
      QA_SOURCE_ROOT_KIND="$QA_CURRENT_SOURCE_KIND"
      QA_SOURCE_ROOT_PROVIDER="$QA_CURRENT_SOURCE_PROVIDER"
      QA_SOURCE_ROOT_OWNERSHIP="reused"
      QA_WORKTREE="$QA_CURRENT_SOURCE_ROOT"
      ;;
    *)
      die "Unsupported --source-root-mode: $requested_mode"
      ;;
  esac
}

resolve_qa_branch_name() {
  local explicit_branch="$1"
  local slug="$2"
  local current_branch="$3"

  if [ -n "$explicit_branch" ]; then
    build_qa_branch "$explicit_branch" "$slug"
    return 0
  fi

  if [ -n "$current_branch" ] && [ "$current_branch" != "HEAD" ]; then
    printf '%s' "$current_branch"
    return 0
  fi

  build_qa_branch "" "$slug"
}

detect_compose_file() {
  local root="$1"
  local candidate=""

  for candidate in compose.yaml compose.yml docker-compose.yml docker-compose.yaml; do
    if [ -f "$root/$candidate" ]; then
      printf '%s' "$root/$candidate"
      return 0
    fi
  done

  die "Could not find a Compose file in $root"
}

ensure_worktree_exclude_rule() {
  local worktree="$1"
  local rule="$2"
  local exclude_file=""

  exclude_file="$(git_path "$worktree" "info/exclude")"
  [ -n "$exclude_file" ] || return 0

  ensure_parent_dir "$exclude_file"
  touch "$exclude_file"

  if ! grep -Fqx "$rule" "$exclude_file"; then
    printf '%s\n' "$rule" >>"$exclude_file"
  fi
}

write_source_root_pointer() {
  local qa_dir="$QA_WORKTREE/.qa"

  ensure_worktree_exclude_rule "$QA_WORKTREE" ".qa/"
  mkdir -p "$qa_dir"
  ln -sfn "$QA_ENV_ROOT" "$qa_dir/current"
  ln -sfn "$QA_ENV_ROOT" "$qa_dir/$QA_SLUG"
}

remove_source_root_pointer() {
  local qa_dir="$QA_WORKTREE/.qa"

  [ -d "$qa_dir" ] || return 0

  rm -f "$qa_dir/current" "$qa_dir/$QA_SLUG"

  if [ -z "$(find "$qa_dir" -mindepth 1 -maxdepth 1 2>/dev/null)" ]; then
    rmdir "$qa_dir" 2>/dev/null || true
  fi
}
