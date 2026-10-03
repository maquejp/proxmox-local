#!/usr/bin/env bash

# ==============================================================================
# Existing repository setup
# ==============================================================================

setup_existing_repository() {

    local project_dir="/home/${DEV_USER}/${PROJECT_NAME}"

    echo
    echo "Setting up existing repository..."
    echo "  Target: $project_dir"

    if run_remote test -e "$project_dir"; then
        error "Project directory already exists: $project_dir"
    fi

    if is_github_ssh_url; then
        setup_github_ssh
    fi

    run_remote git clone \
        "$REPOSITORY_URL" \
        "$project_dir"

    if ! run_remote test -d "$project_dir/.git"; then
        error "Repository clone failed: $project_dir"
    fi

    echo
    echo "Repository cloned successfully."
    echo "  Path: $project_dir"
}