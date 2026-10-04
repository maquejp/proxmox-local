#!/usr/bin/env bash

# ==============================================================================
# Git
# ==============================================================================

initialize_git() {

    echo
    echo "Initializing Git..."

    run_remote bash -s -- \
        "$PROJECT_NAME" \
        "$DEV_USER" \
        "$GIT_USER_NAME" \
        "$GIT_USER_EMAIL" <<'REMOTE'

set -euo pipefail

PROJECT_NAME="$1"
DEV_USER="$2"
GIT_USER_NAME="$3"
GIT_USER_EMAIL="$4"

PROJECT_DIR="/home/${DEV_USER}/${PROJECT_NAME}"

cd "$PROJECT_DIR"

git init -b main

git config user.name "$GIT_USER_NAME"
git config user.email "$GIT_USER_EMAIL"

git add .
git commit -m "chore: initialize project"

git branch --show-current
git status --short

REMOTE
}
