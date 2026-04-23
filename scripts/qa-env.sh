#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

# shellcheck source=lib/qa-env/config.sh
source "$SCRIPT_DIR/lib/qa-env/config.sh"
# shellcheck source=lib/qa-env/core.sh
source "$SCRIPT_DIR/lib/qa-env/core.sh"
# shellcheck source=lib/qa-env/source-root.sh
source "$SCRIPT_DIR/lib/qa-env/source-root.sh"
# shellcheck source=lib/qa-env/runtime.sh
source "$SCRIPT_DIR/lib/qa-env/runtime.sh"
# shellcheck source=lib/qa-env/profile.sh
source "$SCRIPT_DIR/lib/qa-env/profile.sh"
# shellcheck source=lib/qa-env/state.sh
source "$SCRIPT_DIR/lib/qa-env/state.sh"
# shellcheck source=lib/qa-env/create.sh
source "$SCRIPT_DIR/lib/qa-env/create.sh"
# shellcheck source=lib/qa-env/commands.sh
source "$SCRIPT_DIR/lib/qa-env/commands.sh"

main "$@"
