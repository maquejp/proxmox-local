#!/usr/bin/env bash

# ==============================================================================
# Angular
# ==============================================================================

create_angular_project() {

    echo
    echo "Creating Angular project..."
    echo

    run_remote bash -s -- "$PROJECT_NAME" "$DEV_USER" <<'REMOTE'

set -euo pipefail

PROJECT_NAME="$1"
DEV_USER="$2"

cd "/home/${DEV_USER}"

npx @angular/cli@latest new \
    "$PROJECT_NAME" \
    --routing \
    --style css \
    --skip-git \
    --skip-install \
    --defaults

REMOTE
}
