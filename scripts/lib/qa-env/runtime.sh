run_compose_logged() {
  run_in_dir_logged "$QA_WORKTREE" docker compose -f "$QA_PRIMARY_COMPOSE_FILE" -f "$QA_COMPOSE_OVERRIDE" -p "$QA_SLUG" "$@"
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

  run_compose_logged exec -T "$QA_APP_SERVICE" sh -lc "$command_text"
}

run_db_query() {
  local query="$1"

  run_compose_logged exec -T "$QA_DB_SERVICE" mariadb -u"$QA_DB_USER" -p"$QA_DB_PASSWORD" "$QA_DB_NAME" -Nse "$query"
}

run_db_scalar() {
  local query="$1"
  local value=""

  value="$(run_db_query "$query" | tr -d '\r' | tail -n 1)"
  printf '%s' "$value"
}

fetch_url_to_file_logged() {
  local url="$1"
  local output_file="$2"

  {
    printf '\n[cwd] %s\n' "$QA_WORKTREE"
    printf '$ curl -k --max-time 20 -L -o %q %q\n' "$output_file" "$url"
  } >>"$RUN_LOG"

  curl -k --max-time 20 -L -o "$output_file" "$url" >/dev/null
}

verify_storefront_readiness() {
  local requested_mode="$1"
  local verify_mode="$requested_mode"
  local temp_dir=""
  local category_path=""
  local product_path=""
  local category_url=""
  local product_url=""
  local active_product_count=""
  local visibility_count=""

  if [ "$verify_mode" = "auto" ]; then
    if [ "$QA_DEMODATA_MODE" = "always" ]; then
      verify_mode="always"
    else
      verify_mode="never"
    fi
  fi

  QA_VERIFY_STOREFRONT_MODE="$verify_mode"
  QA_VERIFY_STOREFRONT_RESULT="not-run"

  if [ "$verify_mode" = "never" ]; then
    return 0
  fi

  need_cmd curl

  active_product_count="$(run_db_scalar "SELECT COUNT(*) FROM product WHERE active = 1;")"
  visibility_count="$(run_db_scalar "SELECT COUNT(*) FROM product_visibility;")"

  [ "${active_product_count:-0}" -gt 0 ] || die "Storefront verification failed: no active products were found after setup."
  [ "${visibility_count:-0}" -gt 0 ] || die "Storefront verification failed: no product visibility rows were found after setup."

  category_path="$(run_db_scalar "SELECT DISTINCT seo.seo_path_info FROM seo_url seo INNER JOIN category c ON c.id = seo.foreign_key INNER JOIN product_category pc ON pc.category_id = c.id WHERE seo.route_name = 'frontend.navigation.page' AND seo.is_canonical = 1 AND seo.is_deleted = 0 AND seo.seo_path_info <> '' LIMIT 1;")"
  product_path="$(run_db_scalar "SELECT seo_path_info FROM seo_url WHERE route_name = 'frontend.detail.page' AND is_canonical = 1 AND is_deleted = 0 AND seo_path_info <> '' LIMIT 1;")"

  [ -n "$category_path" ] || die "Storefront verification failed: could not find a canonical category URL with assigned products."
  [ -n "$product_path" ] || die "Storefront verification failed: could not find a canonical product-detail URL."

  category_url="${QA_APP_URL%/}/$category_path"
  product_url="${QA_APP_URL%/}/$product_path"
  temp_dir="$(mktemp -d)"

  fetch_url_to_file_logged "$category_url" "$temp_dir/category.html"
  fetch_url_to_file_logged "$product_url" "$temp_dir/product.html"

  if ! rg -q 'product-box' "$temp_dir/category.html"; then
    rm -rf "$temp_dir"
    die "Storefront verification failed: category page did not render any product-box elements."
  fi

  if ! rg -q 'buy-widget|product-detail-buy' "$temp_dir/product.html"; then
    rm -rf "$temp_dir"
    die "Storefront verification failed: product-detail page did not render buy-widget markup."
  fi

  rm -rf "$temp_dir"
  QA_VERIFY_STOREFRONT_RESULT="passed"
}

normalize_relative_path() {
  local path="$1"

  if [ -n "${QA_WORKTREE:-}" ] && [ "${path#/}" != "$path" ]; then
    case "$path" in
      "$QA_WORKTREE")
        path="."
        ;;
      "$QA_WORKTREE"/*)
        path="${path#"$QA_WORKTREE"/}"
        ;;
      *)
        die "Path must stay within the QA worktree: $path"
        ;;
    esac
  fi

  path="${path#./}"
  while [ -n "$path" ] && [ "${path%/}" != "$path" ]; do
    path="${path%/}"
  done

  if [ -z "$path" ]; then
    path="."
  fi

  printf '%s' "$path"
}

resolve_worktree_path() {
  local path="$1"
  local normalized_path=""

  normalized_path="$(normalize_relative_path "$path")"
  if [ "$normalized_path" = "." ]; then
    printf '%s' "$QA_WORKTREE"
  else
    printf '%s' "$QA_WORKTREE/$normalized_path"
  fi
}

append_mode_note() {
  local note="$1"

  [ -n "$note" ] || return 0

  if [ -n "$QA_MODE_NOTE" ]; then
    QA_MODE_NOTE="$QA_MODE_NOTE $note"
  else
    QA_MODE_NOTE="$note"
  fi
}

should_skip_runtime_test_package_dir() {
  local include_test_dirs="$1"
  local package_dir="$2"

  [ "$include_test_dirs" != "true" ] || return 1

  case "$package_dir" in
    tests/* | */tests/* | test/* | */test/* | __tests__/* | */__tests__/*)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

emit_runtime_package_dirs_for_root() {
  local root="$1"
  local include_test_dirs="$2"
  local normalized_root=""
  local absolute_root=""
  local package_file=""
  local package_dir=""
  local emitted="false"

  normalized_root="$(normalize_relative_path "$root")"
  absolute_root="$(resolve_worktree_path "$normalized_root")"

  [ -d "$absolute_root" ] || die "Runtime package root not found: $root"

  if [ -f "$absolute_root/package.json" ]; then
    printf '%s\n' "$normalized_root"
    emitted="true"
  fi

  while IFS= read -r package_file; do
    package_dir="$(dirname "${package_file#"$QA_WORKTREE"/}")"
    [ "$package_dir" = "$normalized_root" ] && continue
    should_skip_runtime_test_package_dir "$include_test_dirs" "$package_dir" && continue
    printf '%s\n' "$package_dir"
    emitted="true"
  done < <(
    find "$absolute_root" -type f -name package.json \
      ! -path '*/node_modules/*' \
      ! -path '*/vendor/*' \
      | sort
  )

  if [ "$emitted" != "true" ]; then
    die "No runtime package.json files found under root: $root"
  fi
}

collect_runtime_package_install_dirs() {
  local include_test_dirs="$1"
  shift
  local phase="roots"
  local value=""

  for value in "$@"; do
    if [ "$value" = "--" ]; then
      phase="dirs"
      continue
    fi

    if [ "$phase" = "roots" ]; then
      emit_runtime_package_dirs_for_root "$value" "$include_test_dirs"
    else
      normalize_relative_path "$value"
      printf '\n'
    fi
  done | awk 'NF && !seen[$0]++'
}

run_in_app_with_stdin_logged() {
  local rendered="$1"
  local stdin_payload="$2"
  local command_text="$3"

  {
    printf '\n[cwd] %s\n' "$QA_WORKTREE"
    printf '$ %s\n' "$rendered"
  } >>"$RUN_LOG"

  printf '%s' "$stdin_payload" | (
    cd "$QA_WORKTREE"
    docker compose -f "$QA_PRIMARY_COMPOSE_FILE" -f "$QA_COMPOSE_OVERRIDE" -p "$QA_SLUG" exec -T "$QA_APP_SERVICE" sh -lc "$command_text"
  ) 2>&1 | tee -a "$RUN_LOG"
}

normalize_system_config_value() {
  local key="$1"
  local raw_value="$2"
  local prefix="${key} => "
  local raw_value_no_indent=""

  raw_value="$(printf '%s' "$raw_value" | tr -d '\r')"
  raw_value_no_indent="$(printf '%s' "$raw_value" | sed -E 's/^[[:space:]]*//')"
  if [ "${raw_value#"$prefix"}" != "$raw_value" ]; then
    raw_value="${raw_value#"$prefix"}"
  elif [ "${raw_value_no_indent#"$prefix"}" != "$raw_value_no_indent" ]; then
    raw_value="${raw_value_no_indent#"$prefix"}"
  fi

  printf '%s' "$raw_value"
}

read_system_config_value_from_container() {
  local container_name="$1"
  local key="$2"
  local raw_value=""

  if ! raw_value="$(docker exec "$container_name" php bin/console system:config:get "$key" 2>/dev/null)"; then
    die "Could not read system config key $key from container $container_name"
  fi

  normalize_system_config_value "$key" "$raw_value"
}

write_system_config_value_to_app() {
  local key="$1"
  local value="$2"
  local key_quoted=""

  key_quoted="$(printf '%q' "$key")"
  run_in_app_with_stdin_logged \
    "bin/console system:config:set $key <stdin>" \
    "$value" \
    "value=\$(cat); bin/console system:config:set $key_quoted \"\$value\""
}

copy_system_config_keys_from_container() {
  local container_name="$1"
  shift
  local key=""
  local value=""

  [ -n "$container_name" ] || return 0
  [ "$#" -gt 0 ] || return 0

  for key in "$@"; do
    log "Copying system config key $key from container $container_name"
    value="$(read_system_config_value_from_container "$container_name" "$key")"
    write_system_config_value_to_app "$key" "$value"
  done

  append_mode_note "Copied selected system config keys from live container \`$container_name\` into the QA env."
}

resolve_runtime_package_install_command() {
  local package_dir="$1"

  if [ -f "$package_dir/package-lock.json" ]; then
    printf '%s' "npm ci --no-audit --prefer-offline"
  else
    printf '%s' "npm install --no-audit --prefer-offline"
  fi
}

install_runtime_package_dirs() {
  local package_dir=""
  local normalized_dir=""
  local absolute_dir=""
  local install_command=""
  local package_count="$#"

  [ "$package_count" -gt 0 ] || return 0

  for package_dir in "$@"; do
    normalized_dir="$(normalize_relative_path "$package_dir")"
    absolute_dir="$(resolve_worktree_path "$normalized_dir")"
    [ -f "$absolute_dir/package.json" ] || die "Runtime package directory is missing package.json: $package_dir"

    install_command="$(resolve_runtime_package_install_command "$absolute_dir")"
    run_in_app_logged "cd $(printf '%q' "$normalized_dir") && $install_command"
  done

  if [ "$package_count" -eq 1 ]; then
    append_mode_note "Installed runtime JavaScript dependencies for 1 package directory before after-setup hooks."
  else
    append_mode_note "Installed runtime JavaScript dependencies for $package_count package directories before after-setup hooks."
  fi
}

run_app_commands() {
  local command_text=""

  for command_text in "$@"; do
    run_in_app_logged "$command_text"
  done
}

run_mode_enabled_app_command() {
  local mode="$1"
  local command_text="$2"

  [ "$mode" = "always" ] || return 0
  run_in_app_logged "$command_text"
}

run_create_system_config_phase() {
  local container_name="$1"
  shift

  if [ -n "$container_name" ] && [ "$#" -gt 0 ]; then
    copy_system_config_keys_from_container "$container_name" "$@"
  elif [ -n "$container_name" ]; then
    append_mode_note "A live container was provided for system config copy, but no --copy-system-config-key values were requested."
  elif [ "$#" -gt 0 ]; then
    die "--copy-system-config-key requires --copy-system-config-from-container."
  fi
}

run_create_runtime_package_phase() {
  local include_test_package_dirs="$1"
  shift
  local -a runtime_package_install_dirs=()
  local runtime_dir=""

  while IFS= read -r runtime_dir; do
    [ -n "$runtime_dir" ] || continue
    runtime_package_install_dirs+=("$runtime_dir")
  done < <(
    collect_runtime_package_install_dirs \
      "$include_test_package_dirs" \
      "$@"
  )

  if [ "${#runtime_package_install_dirs[@]}" -gt 0 ]; then
    install_runtime_package_dirs "${runtime_package_install_dirs[@]}"
    if [ "$include_test_package_dirs" != "true" ]; then
      append_mode_note "Runtime package discovery skipped test package directories by default for faster manual QA setup."
    fi
  fi
}
