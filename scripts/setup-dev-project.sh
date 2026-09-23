#!/usr/bin/env bash

set -euo pipefail

VM_USER="sysadmin"
PROJECTS_DIR="/home/${VM_USER}/Projects"

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

if [[ -z "$VM_IP" ]]; then
    echo "Error: could not determine VM IPv4 address."
    exit 1
fi

echo "Waiting for SSH on ${SSH_TARGET}..."

SSH_READY=false

for _ in {1..30}; do
    if ssh \
        -o ConnectTimeout=2 \
        -o BatchMode=yes \
        -o StrictHostKeyChecking=no \
        "${SSH_TARGET}" true 2>/dev/null; then
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

echo "Project setup:"
echo "  VM:          $VMID"
echo "  IP:          $VM_IP"
echo "  User:        $VM_USER"
echo "  Project:     $PROJECT_NAME"
echo "  GitHub repo: $GITHUB_REPO"