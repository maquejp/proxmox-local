#!/usr/bin/env bash

# ==============================================================================
# Vite + React
# ==============================================================================

create_vite_react_project() {

    echo
    echo "Creating Vite + React project..."
    echo

    run_remote bash -s -- "$PROJECT_NAME" "$DEV_USER" <<'REMOTE'

set -euo pipefail

PROJECT_NAME="$1"
DEV_USER="$2"

cd "/home/${DEV_USER}"

npm create vite@latest \
    "$PROJECT_NAME" \
    -- \
    --template react-ts

REMOTE
}
