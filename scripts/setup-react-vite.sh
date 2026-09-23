#!/usr/bin/env bash

set -euo pipefail

VM_USER="sysadmin"
PROJECTS_DIR="/home/${VM_USER}/Projects"
VM_ADMIN_SSH_KEY="/root/.ssh/id_ed25519_vm_admin"

VMID="${1:-}"
PROJECT_NAME="${2:-}"
VM_IP="${3:-}"

SSH_TARGET="${VM_USER}@${VM_IP}"
PROJECT_DIR="${PROJECTS_DIR}/${PROJECT_NAME}"

usage() {
    echo "Usage: $0 <vmid> <project-name> <vm-ip>"
    echo "Example: $0 153 mon-projet 192.168.1.153"
    exit 1
}

ssh_vm() {
    ssh \
        -i "$VM_ADMIN_SSH_KEY" \
        -o IdentitiesOnly=yes \
        -o BatchMode=yes \
        -o StrictHostKeyChecking=no \
        "$SSH_TARGET" \
        "$@"
}

[[ -n "$VMID" && -n "$PROJECT_NAME" && -n "$VM_IP" ]] || usage

if ! [[ "$VMID" =~ ^[0-9]+$ ]]; then
    echo "Error: VMID must be numeric."
    exit 1
fi

if ! qm status "$VMID" &>/dev/null; then
    echo "Error: VMID $VMID does not exist."
    exit 1
fi

if [[ "$(qm status "$VMID" | awk '{print $2}')" != "running" ]]; then
    echo "Error: VM $VMID is not running."
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

echo "Checking React/Vite project..."

ssh_vm "cd '$PROJECT_DIR' && \
    test -f package.json && \
    command -v node >/dev/null && \
    command -v npm >/dev/null && \
    node -e '
        const packageJson = require("./package.json");
        const packages = { ...packageJson.dependencies, ...packageJson.devDependencies };
        const required = ["react", "react-dom", "vite", "typescript"];
        const missing = required.filter((name) => !packages[name]);
        if (missing.length > 0) {
            console.error(`Error: missing required packages: ${missing.join(", ")}`);
            process.exit(1);
        }
    '"

VITE_CONFIG="$(
    ssh_vm "find '$PROJECT_DIR' -maxdepth 1 -type f \
        \\( -name 'vite.config.ts' -o -name 'vite.config.js' -o -name 'vite.config.mts' -o -name 'vite.config.mjs' \\) \
        -print -quit"
)"

if [[ -z "$VITE_CONFIG" ]]; then
    echo "Error: Vite configuration file not found in $PROJECT_DIR."
    exit 1
fi

if ! ssh_vm "grep -Eq \"host:[[:space:]]*['\\\"]0\\.0\\.0\\.0['\\\"]\" '$VITE_CONFIG'"; then
    echo "Error: Vite must be configured with server.host set to 0.0.0.0."
    echo "Update $VITE_CONFIG, then run this script again."
    exit 1
fi

echo "Installing locked dependencies..."
ssh_vm "cd '$PROJECT_DIR' && npm ci"

echo "Building project..."
ssh_vm "cd '$PROJECT_DIR' && npm run build"

echo "Opening Vite port..."
ssh_vm 'sudo -n firewall-cmd --permanent --add-port=5173/tcp && \
    sudo -n firewall-cmd --reload && \
    sudo -n firewall-cmd --query-port=5173/tcp >/dev/null'

echo
echo "React/Vite setup complete:"
echo "  VM:        $VMID"
echo "  IP:        $VM_IP"
echo "  Project:   $PROJECT_NAME"
echo "  Directory: $PROJECT_DIR"
echo "  Vite URL:  http://${VM_IP}:5173"
