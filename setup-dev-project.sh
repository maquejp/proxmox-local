#!/usr/bin/env bash

set -euo pipefail

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

prompt_choice() {

    local prompt="$1"
    local max="$2"
    local choice

    while true; do

        read -r -p "$prompt" choice

        if [[ "$choice" =~ ^[1-9][0-9]*$ ]] &&
           (( choice <= max )); then

            printf '%s\n' "$choice"
            return
        fi

        echo "Invalid choice. Please enter a number between 1 and $max." >&2
    done
}

# ==============================================================================
# VM validation
# ==============================================================================

validate_vmid() {

    if [[ ! "$VMID" =~ ^[0-9]+$ ]]; then
        error "VMID must be numeric: $VMID"
    fi

    if ! qm status "$VMID" &>/dev/null; then
        error "VMID $VMID does not exist"
    fi
}

validate_vm_running() {

    local status

    status=$(qm status "$VMID" | awk '{print $2}')

    if [[ "$status" != "running" ]]; then
        error "VM $VMID is not running"
    fi
}

get_vm_ip() {

    local ip

    ip=$(
        qm config "$VMID" |
        awk -F'ip=' '/^ipconfig0:/ {
            split($2, a, ",")
            print a[1]
        }' |
        cut -d/ -f1
    )

    if [[ -z "$ip" ]]; then
        error "No static IP configured for VM $VMID"
    fi

    echo "$ip"
}

validate_ssh() {

    echo "Checking SSH connectivity..."

    if ! ssh \
        -i "$SSH_PRIVATE_KEY" \
        -o BatchMode=yes \
        -o StrictHostKeyChecking=accept-new \
        -o ConnectTimeout=5 \
        "${DEV_USER}@${VM_IP}" \
        true; then

        error "SSH connection failed: ${DEV_USER}@${VM_IP}"
    fi

    echo "SSH connectivity OK."
}

# ==============================================================================
# Remote commands
# ==============================================================================

run_remote() {

    ssh \
        -i "$SSH_PRIVATE_KEY" \
        -o BatchMode=yes \
        -o StrictHostKeyChecking=accept-new \
        -o ConnectTimeout=5 \
        "${DEV_USER}@${VM_IP}" \
        "$@"
}

# ==============================================================================
# Project prompts
# ==============================================================================

prompt_project_name() {

    read -r -p "Project name: " PROJECT_NAME

    if [[ -z "$PROJECT_NAME" ]]; then
        error "Project name cannot be empty"
    fi
}

prompt_project_source() {

    echo
    echo "Project source:"
    echo "  1) New project"
    echo "  2) Existing repository"

    local choice
    choice=$(prompt_choice "Choice: " 2)

    case "$choice" in

        1)
            PROJECT_SOURCE="new"
            ;;

        2)
            PROJECT_SOURCE="existing"
            ;;

    esac
}

prompt_repository_url() {

    echo

    read -r -p "Repository URL: " REPOSITORY_URL

    if [[ -z "$REPOSITORY_URL" ]]; then
        error "Repository URL cannot be empty"
    fi
}

prompt_project_type() {

    echo
    echo "Project type:"
    echo "  1) Frontend"
    echo "  2) Backend / API"
    echo "  3) Full-stack"
    echo "  4) Other"

    local choice
    choice=$(prompt_choice "Choice: " 4)

    case "$choice" in

        1)
            PROJECT_TYPE="frontend"
            ;;

        2)
            PROJECT_TYPE="backend"
            ;;

        3)
            PROJECT_TYPE="fullstack"
            ;;

        4)
            PROJECT_TYPE="other"
            ;;

    esac
}

prompt_frontend() {

    echo
    echo "Frontend:"
    echo "  1) Vite + React"
    echo "  2) Angular"

    local choice
    choice=$(prompt_choice "Choice: " 2)

    case "$choice" in

        1)
            FRONTEND="vite-react"
            ;;

        2)
            FRONTEND="angular"
            ;;

    esac
}

prompt_backend() {

    echo
    echo "Backend:"
    echo "  1) Express"
    echo "  2) Laravel"
    echo "  3) Spring Boot"

    local choice
    choice=$(prompt_choice "Choice: " 3)

    case "$choice" in

        1)
            BACKEND="express"
            ;;

        2)
            BACKEND="laravel"
            ;;

        3)
            BACKEND="spring-boot"
            ;;

    esac
}

prompt_database() {

    echo
    echo "Database:"
    echo "  1) None"
    echo "  2) Create database on this VM"
    echo "  3) Use an existing database VM"

    local choice
    choice=$(prompt_choice "Choice: " 3)

    case "$choice" in

        1)
            DATABASE_STRATEGY="none"
            ;;

        2)
            DATABASE_STRATEGY="local"
            ;;

        3)
            DATABASE_STRATEGY="existing-vm"
            ;;

    esac

    if [[ "$DATABASE_STRATEGY" == "local" ]]; then
        prompt_database_engine
    fi
}

prompt_database_engine() {

    echo
    echo "Database engine:"
    echo "  1) PostgreSQL"
    echo "  2) MariaDB"
    echo "  3) MongoDB"

    local choice
    choice=$(prompt_choice "Choice: " 3)

    case "$choice" in

        1)
            DATABASE_ENGINE="postgresql"
            ;;

        2)
            DATABASE_ENGINE="mariadb"
            ;;

        3)
            DATABASE_ENGINE="mongodb"
            ;;

    esac
}

# ==============================================================================
# New project configuration
# ==============================================================================

configure_new_project() {

    prompt_project_type

    case "$PROJECT_TYPE" in

        frontend)
            prompt_frontend
            ;;

        backend)
            prompt_backend
            ;;

        fullstack)
            prompt_frontend
            prompt_backend
            ;;

        other)
            ;;

    esac

    if [[ -n "$BACKEND" ]]; then
        prompt_database
    fi
}

# ==============================================================================
# GitHub SSH
# ==============================================================================

is_github_ssh_url() {

    [[ "$REPOSITORY_URL" == git@github.com:* ]]
}

configure_github_ssh() {

    run_remote mkdir -p "/home/${DEV_USER}/.ssh"
    run_remote chmod 700 "/home/${DEV_USER}/.ssh"

    local ssh_config

    ssh_config=$(cat <<EOF
Host github.com
    HostName github.com
    User git
    IdentityFile ${GITHUB_SSH_PRIVATE_KEY}
    IdentitiesOnly yes
EOF
)

    run_remote \
        "printf '%s\n' '$ssh_config' > /home/${DEV_USER}/.ssh/config"

    run_remote chmod 600 "/home/${DEV_USER}/.ssh/config"
}

add_github_host_key() {

    echo "Adding GitHub host key..."

    local github_host_key

    github_host_key=$(ssh-keyscan github.com 2>/dev/null)

    if [[ -z "$github_host_key" ]]; then
        error "Failed to retrieve GitHub host key"
    fi

    run_remote \
        "printf '%s\n' '$github_host_key' >> /home/${DEV_USER}/.ssh/known_hosts"

    run_remote chmod 644 "/home/${DEV_USER}/.ssh/known_hosts"
}

setup_github_ssh() {

    echo
    echo "Checking GitHub SSH authentication..."

    run_remote mkdir -p "/home/${DEV_USER}/.ssh"
    run_remote chmod 700 "/home/${DEV_USER}/.ssh"

    if ! run_remote test -f "$GITHUB_SSH_PRIVATE_KEY" ||
       ! run_remote test -f "$GITHUB_SSH_PUBLIC_KEY"; then

        echo
        echo "No GitHub SSH key found on the VM."
        echo "Generating a dedicated GitHub SSH key..."

        run_remote ssh-keygen \
            -t ed25519 \
            -C "dev@${VMID}" \
            -f "$GITHUB_SSH_PRIVATE_KEY" \
            -N '""'

        run_remote chmod 600 "$GITHUB_SSH_PRIVATE_KEY"
        run_remote chmod 644 "$GITHUB_SSH_PUBLIC_KEY"
    fi

    run_remote touch "/home/${DEV_USER}/.ssh/known_hosts"

    if ! run_remote grep -q "github.com" "/home/${DEV_USER}/.ssh/known_hosts"; then
        add_github_host_key
    fi

    configure_github_ssh

    local public_key

    public_key=$(run_remote cat "$GITHUB_SSH_PUBLIC_KEY")

    echo
    echo "GitHub SSH public key:"
    echo
    echo "$public_key"
    echo
    echo "Add this key to your GitHub account:"
    echo "GitHub → Settings → SSH and GPG keys"
    echo

    read -r -p "Press Enter once the key has been added to GitHub..."

    echo
    echo "Testing GitHub SSH authentication..."

    local github_result

    github_result=$(
        run_remote ssh \
            -i "$GITHUB_SSH_PRIVATE_KEY" \
            -o BatchMode=yes \
            -o IdentitiesOnly=yes \
            -o StrictHostKeyChecking=yes \
            -o ConnectTimeout=5 \
            -T git@github.com 2>&1 || true
    )

    if [[ "$github_result" != *"successfully authenticated"* ]]; then

        echo "$github_result" >&2

        error "GitHub SSH authentication failed"
    fi

    echo "GitHub SSH authentication OK."
}

# ==============================================================================
# Project setup
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

setup_new_project() {

    echo "New project setup is not implemented yet."
}

# ==============================================================================
# Summary
# ==============================================================================

show_project_summary() {

    echo
    echo "Project target:"
    echo
    printf '  VM ID    : %s\n' "$VMID"
    printf '  VM IP    : %s\n' "$VM_IP"
    printf '  User     : %s\n' "$DEV_USER"

    echo
    echo "Project configuration:"
    echo
    printf '  Name     : %s\n' "$PROJECT_NAME"
    printf '  Source   : %s\n' "$PROJECT_SOURCE"

    if [[ -n "$PROJECT_TYPE" ]]; then
        printf '  Type     : %s\n' "$PROJECT_TYPE"
    fi

    if [[ -n "$REPOSITORY_URL" ]]; then
        printf '  Repo     : %s\n' "$REPOSITORY_URL"
    fi

    if [[ -n "$FRONTEND" ]]; then
        printf '  Frontend : %s\n' "$FRONTEND"
    fi

    if [[ -n "$BACKEND" ]]; then
        printf '  Backend  : %s\n' "$BACKEND"
    fi

    if [[ -n "$DATABASE_STRATEGY" ]]; then
        printf '  Database : %s\n' "$DATABASE_STRATEGY"
    fi

    if [[ -n "$DATABASE_ENGINE" ]]; then
        printf '  Engine   : %s\n' "$DATABASE_ENGINE"
    fi
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
    error "--vm is required"
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