#!/usr/bin/env bash

set -euo pipefail

# ==============================================================================
# Project modules
# ==============================================================================


LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd)"

source "${LIB_DIR}/vm.sh"
source "${LIB_DIR}/project/prompts.sh"
source "${LIB_DIR}/project/github-ssh.sh"
source "${LIB_DIR}/project/existing-repository.sh"
source "${LIB_DIR}/project/summary.sh"
source "${LIB_DIR}/project/new-project.sh"

# ==============================================================================
# Proxmox Development VM - Project Setup
# ==============================================================================

DEV_USER="dev"

VMID=""
VM_IP=""

SSH_PRIVATE_KEY="/root/.ssh/id_ed25519_vm_admin"

PROJECT_NAME=""
PROJECT_SOURCE=""
PROJECT_TYPE=""
REPOSITORY_URL=""
GIT_USER_NAME=""
GIT_USER_EMAIL=""

FRONTEND=""
BACKEND=""

DATABASE_STRATEGY=""
DATABASE_ENGINE=""

GITHUB_SSH_PRIVATE_KEY="/home/${DEV_USER}/.ssh/id_ed25519_github"
GITHUB_SSH_PUBLIC_KEY="/home/${DEV_USER}/.ssh/id_ed25519_github.pub"

# ==============================================================================
# General functions
# ==============================================================================

error() {

    echo "Error: $*" >&2
    exit 1
}

# ==============================================================================
# Arguments
# ==============================================================================

while [[ $# -gt 0 ]]; do

    case "$1" in

        --vm)

            if [[ $# -lt 2 ]]; then
                error "--vm requires a VM ID"
            fi

            VMID="$2"

            shift 2
            ;;

        -h|--help)

            echo "Usage:"
            echo
            echo "  $0 --vm VMID"
            echo

            exit 0
            ;;

        *)

            error "Unknown option: $1"
            ;;

    esac

done

if [[ -z "$VMID" ]]; then
    prompt_vmid
fi

# ==============================================================================
# VM validation
# ==============================================================================

validate_vmid
validate_vm_running

VM_IP=$(get_vm_ip)

validate_ssh

# ==============================================================================
# Project configuration
# ==============================================================================

echo "=== Project Setup ==="
echo

prompt_project_name
prompt_project_source

if [[ "$PROJECT_SOURCE" == "existing" ]]; then

    prompt_repository_url

else

    configure_new_project

fi

# ==============================================================================
# Summary
# ==============================================================================

show_project_summary

# ==============================================================================
# Setup
# ==============================================================================

if [[ "$PROJECT_SOURCE" == "existing" ]]; then

    setup_existing_repository

else

    setup_new_project

fi
