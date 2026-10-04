#!/usr/bin/env bash

# ==============================================================================
# Laravel
# ==============================================================================

create_laravel_project() {

    echo
    echo "Creating Laravel project..."
    echo

    run_remote bash -s -- "$PROJECT_NAME" "$DEV_USER" <<'REMOTE'

set -euo pipefail

PROJECT_NAME="$1"
DEV_USER="$2"

cd "/home/${DEV_USER}"

composer create-project laravel/laravel "$PROJECT_NAME"

REMOTE
}
