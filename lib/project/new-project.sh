#!/usr/bin/env bash

# ==============================================================================
# New project setup
# ==============================================================================

NODE_MAJOR_VERSION="24"

install_node() {

    if run_remote command -v node >/dev/null 2>&1; then
        echo "Node.js already installed:"
        run_remote node --version
        return
    fi

    echo "Installing Node.js ${NODE_MAJOR_VERSION}..."

    run_remote bash -s -- "$NODE_MAJOR_VERSION" <<'REMOTE'

set -euo pipefail

NODE_MAJOR_VERSION="$1"

curl -fsSL \
    "https://rpm.nodesource.com/setup_${NODE_MAJOR_VERSION}.x" \
    -o /tmp/nodesource_setup.sh

sudo bash /tmp/nodesource_setup.sh

rm -f /tmp/nodesource_setup.sh

sudo dnf install -y nodejs

REMOTE

    echo "Node.js installed:"
    run_remote node --version
    run_remote npm --version
}

create_vite_react_project() {

    echo
    echo "Creating Vite + React project..."
    echo

    run_remote bash -s -- "$PROJECT_NAME" "$DEV_USER" <<'REMOTE'

set -euo pipefail

PROJECT_NAME="$1"
DEV_USER="$2"
PROJECT_DIR="/home/${DEV_USER}/${PROJECT_NAME}"

cd "/home/${DEV_USER}"

npm create vite@latest \
    "$PROJECT_NAME" \
    -- \
    --template react-ts

REMOTE
}

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

setup_new_project() {

    if [[ "$PROJECT_TYPE" != "frontend" ]]; then
        error "New project type '$PROJECT_TYPE' is not implemented yet"
    fi

    if [[ "$FRONTEND" != "vite-react" ]]; then
        error "Frontend '$FRONTEND' is not implemented yet"
    fi

    local project_dir="/home/${DEV_USER}/${PROJECT_NAME}"

    if run_remote test -e "$project_dir"; then
        error "Project directory already exists: $project_dir"
    fi

    install_node
    create_vite_react_project
    initialize_git

    echo
    echo "Project created successfully."
}