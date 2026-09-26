#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/common.sh
source "${SCRIPT_DIR}/common.sh"

VMID="${1:-}"
PROJECT_NAME="${2:-}"
VM_IP="${3:-}"
GITHUB_REPO="${4:-}"

usage() {
    echo "Usage: $0 <vmid> <project-name> <vm-ip> [github-repo]"
    echo "Examples:"
    echo "  $0 153 mon-projet 192.168.1.153"
    echo "  $0 153 mon-projet 192.168.1.153 maquejp/mon-projet"
    exit 1
}

[[ -n "$VMID" && -n "$PROJECT_NAME" && -n "$VM_IP" ]] || usage

validate_vmid "$VMID"
validate_ip "$VM_IP"
ensure_vm_exists "$VMID"
ensure_vm_running "$VMID"
ensure_admin_key_exists

wait_for_ssh "$VM_IP"

echo "Configuring Git identity..."
ssh_vm "$VM_IP" \
    "git config --global user.name 'Jean-Philippe Maquestiaux' && \
     git config --global user.email 'maquejp@gmail.com' && \
     mkdir -p '$PROJECTS_DIR'"

PROJECT_DIR="${PROJECTS_DIR}/${PROJECT_NAME}"

if [[ -z "$GITHUB_REPO" ]]; then
    echo "Creating local Git project..."
    ssh_vm "$VM_IP" "mkdir -p '$PROJECT_DIR' && git -C '$PROJECT_DIR' init --initial-branch=main"

    echo
    echo "Project setup complete:"
    echo "  VM:        $VMID"
    echo "  IP:        $VM_IP"
    echo "  User:      $VM_USER"
    echo "  Project:   $PROJECT_NAME"
    echo "  Directory: $PROJECT_DIR"
    exit 0
fi

echo "Configuring GitHub SSH key..."
ssh_vm "$VM_IP" 'mkdir -p ~/.ssh && chmod 700 ~/.ssh'

GITHUB_KEY_EXISTS="$(ssh_vm "$VM_IP" '[[ -f ~/.ssh/id_ed25519_github ]] && echo yes || echo no')"

if [[ "$GITHUB_KEY_EXISTS" == "no" ]]; then
    ssh_vm "$VM_IP" \
        'ssh-keygen -t ed25519 \
            -C "github@$(hostname)" \
            -f ~/.ssh/id_ed25519_github \
            -N "" >/dev/null'

    echo
    echo "GitHub SSH key created."
    echo
    echo "Add the following public key to your GitHub account:"
    echo

    ssh_vm "$VM_IP" 'cat ~/.ssh/id_ed25519_github.pub'

    echo
    echo "GitHub → Settings → SSH and GPG keys → New SSH key"
    echo
    read -rp "Press Enter after adding the key to GitHub..."
fi

# SSH configuration is deliberately explicit so Git always uses
# the project VM's dedicated GitHub key.
ssh_vm "$VM_IP" \
    'cat > ~/.ssh/config << "EOF"
Host github.com
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_ed25519_github
    IdentitiesOnly yes
EOF
chmod 600 ~/.ssh/config'

# Trust GitHub's host key on a fresh VM.
ssh_vm "$VM_IP" \
    'touch ~/.ssh/known_hosts && \
     ssh-keygen -F github.com -f ~/.ssh/known_hosts >/dev/null || \
     ssh-keyscan -H github.com >> ~/.ssh/known_hosts'

echo "Testing GitHub authentication..."
GITHUB_TEST="$(ssh_vm "$VM_IP" 'ssh -T git@github.com 2>&1 || true')"

if [[ "$GITHUB_TEST" != *"successfully authenticated"* ]]; then
    echo
    echo "Error: GitHub authentication failed." >&2
    echo
    echo "Public key:" >&2
    ssh_vm "$VM_IP" 'cat ~/.ssh/id_ed25519_github.pub' >&2
    echo
    echo "Make sure this key is registered in GitHub." >&2
    exit 1
fi

echo "GitHub authentication OK."

GITHUB_URL="git@github.com:${GITHUB_REPO}.git"

echo "Cloning project..."
ssh_vm "$VM_IP" \
    "if [[ -d '$PROJECT_DIR/.git' ]]; then
         echo 'Project already cloned: $PROJECT_DIR'
     elif [[ -e '$PROJECT_DIR' ]]; then
         echo 'Error: project directory already exists: $PROJECT_DIR'
         exit 1
     else
         git clone '$GITHUB_URL' '$PROJECT_DIR'
     fi"

echo
echo "Project setup complete:"
echo "  VM:          $VMID"
echo "  IP:          $VM_IP"
echo "  User:        $VM_USER"
echo "  Project:     $PROJECT_NAME"
echo "  GitHub repo: $GITHUB_REPO"
echo "  Directory:   $PROJECT_DIR"
