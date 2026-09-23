#!/usr/bin/env bash

set -euo pipefail

VM_USER="sysadmin"
PROJECTS_DIR="/home/${VM_USER}/Projects"
VM_ADMIN_SSH_KEY="/root/.ssh/id_ed25519_vm_admin"

VMID="${1:-}"
PROJECT_NAME="${2:-}"
VM_IP="${3:-}"
GITHUB_REPO="${4:-}"

SSH_TARGET="${VM_USER}@${VM_IP}"

usage() {
    echo "Usage: $0 <vmid> <project-name> <vm-ip> <github-repo>"
    echo "Example: $0 153 mon-projet 192.168.1.153 maquejp/mon-projet"
    exit 1
}

[[ -n "$VMID" && -n "$PROJECT_NAME" && -n "$VM_IP" && -n "$GITHUB_REPO" ]] || usage

if ! [[ "$VMID" =~ ^[0-9]+$ ]]; then
    echo "Error: VMID must be numeric."
    exit 1
fi

if ! qm status "$VMID" &>/dev/null; then
    echo "Error: VMID $VMID does not exist."
    exit 1
fi

VM_STATUS="$(qm status "$VMID" | awk '{print $2}')"

if [[ "$VM_STATUS" != "running" ]]; then
    echo "Error: VM $VMID is not running."
    echo "Start it with: qm start $VMID"
    exit 1
fi

if ! [[ "$VM_IP" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
    echo "Error: invalid IPv4 address: $VM_IP"
    exit 1
fi

if [[ ! -f "$VM_ADMIN_SSH_KEY" ]]; then
    echo "Error: VM admin SSH private key not found: $VM_ADMIN_SSH_KEY"
    exit 1
fi

echo "Waiting for SSH on ${SSH_TARGET}..."

SSH_READY=false

for _ in {1..30}; do
    if ssh \
        -i "$VM_ADMIN_SSH_KEY" \
        -o IdentitiesOnly=yes \
        -o ConnectTimeout=2 \
        -o BatchMode=yes \
        -o StrictHostKeyChecking=no \
        "$SSH_TARGET" true 2>/dev/null; then
        SSH_READY=true
        break
    fi

    sleep 2
done

if [[ "$SSH_READY" != true ]]; then
    echo "Error: SSH is not available on ${SSH_TARGET}."
    exit 1
fi

echo "SSH is available."

echo "Configuring project..."

ssh \
    -i "$VM_ADMIN_SSH_KEY" \
    -o IdentitiesOnly=yes \
    -o BatchMode=yes \
    -o StrictHostKeyChecking=no \
    "$SSH_TARGET" \
    "git config --global user.name 'Jean-Philippe Maquestiaux' && \
     git config --global user.email 'maquejp@gmail.com' && \
     mkdir -p '$PROJECTS_DIR'"

echo "Configuring GitHub SSH key..."

ssh \
    -i "$VM_ADMIN_SSH_KEY" \
    -o IdentitiesOnly=yes \
    -o BatchMode=yes \
    -o StrictHostKeyChecking=no \
    "$SSH_TARGET" \
    'mkdir -p ~/.ssh && chmod 700 ~/.ssh'

GITHUB_KEY_EXISTS="$(
    ssh \
        -i "$VM_ADMIN_SSH_KEY" \
        -o IdentitiesOnly=yes \
        -o BatchMode=yes \
        -o StrictHostKeyChecking=no \
        "$SSH_TARGET" \
        '[[ -f ~/.ssh/id_ed25519_github ]] && echo yes || echo no'
)"

if [[ "$GITHUB_KEY_EXISTS" == "no" ]]; then
    ssh \
        -i "$VM_ADMIN_SSH_KEY" \
        -o IdentitiesOnly=yes \
        -o BatchMode=yes \
        -o StrictHostKeyChecking=no \
        "$SSH_TARGET" \
        'ssh-keygen -t ed25519 \
            -C "github@$(hostname)" \
            -f ~/.ssh/id_ed25519_github \
            -N "" >/dev/null'

    echo
    echo "GitHub SSH key created."
    echo
    echo "Add the following public key to your GitHub account:"
    echo

    ssh \
        -i "$VM_ADMIN_SSH_KEY" \
        -o IdentitiesOnly=yes \
        -o BatchMode=yes \
        -o StrictHostKeyChecking=no \
        "$SSH_TARGET" \
        'cat ~/.ssh/id_ed25519_github.pub'

    echo
    echo "GitHub → Settings → SSH and GPG keys → New SSH key"
    echo
    read -rp "Press Enter after adding the key to GitHub..."
fi

# SSH configuration is deliberately explicit so Git always uses
# the project VM's dedicated GitHub key.
ssh \
    -i "$VM_ADMIN_SSH_KEY" \
    -o IdentitiesOnly=yes \
    -o BatchMode=yes \
    -o StrictHostKeyChecking=no \
    "$SSH_TARGET" \
    'cat > ~/.ssh/config << "EOF"
Host github.com
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_ed25519_github
    IdentitiesOnly yes
EOF
chmod 600 ~/.ssh/config'

# Trust GitHub's host key on a fresh VM.
ssh \
    -i "$VM_ADMIN_SSH_KEY" \
    -o IdentitiesOnly=yes \
    -o BatchMode=yes \
    -o StrictHostKeyChecking=no \
    "$SSH_TARGET" \
    'touch ~/.ssh/known_hosts && \
     ssh-keygen -F github.com -f ~/.ssh/known_hosts >/dev/null || \
     ssh-keyscan -H github.com >> ~/.ssh/known_hosts'

echo "Testing GitHub authentication..."

GITHUB_TEST="$(
    ssh \
        -i "$VM_ADMIN_SSH_KEY" \
        -o IdentitiesOnly=yes \
        -o BatchMode=yes \
        -o StrictHostKeyChecking=no \
        "$SSH_TARGET" \
        'ssh -T git@github.com 2>&1 || true'
)"

if [[ "$GITHUB_TEST" != *"successfully authenticated"* ]]; then
    echo
    echo "Error: GitHub authentication failed."
    echo
    echo "Public key:"
    ssh \
        -i "$VM_ADMIN_SSH_KEY" \
        -o IdentitiesOnly=yes \
        -o BatchMode=yes \
        -o StrictHostKeyChecking=no \
        "$SSH_TARGET" \
        'cat ~/.ssh/id_ed25519_github.pub'
    echo
    echo "Make sure this key is registered in GitHub."
    exit 1
fi

echo "GitHub authentication OK."

PROJECT_DIR="${PROJECTS_DIR}/${PROJECT_NAME}"
GITHUB_URL="git@github.com:${GITHUB_REPO}.git"

echo "Cloning project..."

ssh \
    -i "$VM_ADMIN_SSH_KEY" \
    -o IdentitiesOnly=yes \
    -o BatchMode=yes \
    -o StrictHostKeyChecking=no \
    "$SSH_TARGET" \
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