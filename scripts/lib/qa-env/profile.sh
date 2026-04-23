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
  local -a changed_files=()
  local file=""

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
