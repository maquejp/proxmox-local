#!/usr/bin/env bash

set -euo pipefail

VMID="${1:-}"
PROJECT_NAME="${2:-}"
VM_IP="${3:-}"
GITHUB_REPO="${4:-}"
KNOWN_HOSTS="/root/.ssh/known_hosts"

usage() {
    echo "Usage: $0 <vmid> <project-name> <vm-ip> [github-repo]"
    echo "Example: $0 153 mon-projet 192.168.1.153 maquejp/mon-projet"
    exit 1
}

[[ -n "$VMID" && -n "$PROJECT_NAME" && -n "$VM_IP" ]] || usage

if ! [[ "$VMID" =~ ^[0-9]+$ ]]; then
    echo "Error: VMID must be numeric."
    exit 1
fi

if ! [[ "$VM_IP" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
    echo "Error: invalid IPv4 address: $VM_IP"
    exit 1
fi

if qm status "$VMID" &>/dev/null; then
    echo "Stopping VM $VMID..."
    qm stop "$VMID" 2>/dev/null || true

    echo "Destroying VM $VMID..."
    qm destroy "$VMID" --purge 1
else
    echo "VM $VMID does not exist; skipping VM destruction."
fi

if [[ -f "$KNOWN_HOSTS" ]]; then
    echo "Removing SSH host keys for $VM_IP..."
    ssh-keygen -f "$KNOWN_HOSTS" -R "$VM_IP" >/dev/null 2>&1 || true
    rm -f "${KNOWN_HOSTS}.old"
fi

echo
echo "Proxmox cleanup complete:"
echo "  VM: $VMID"
echo "  IP: $VM_IP"
echo
echo "Manual cleanup still required:"
echo "  - On your Mac: ssh-keygen -f ~/.ssh/known_hosts -R $VM_IP"
echo "  - In GitHub: delete the SSH key created for $PROJECT_NAME"

if [[ -n "$GITHUB_REPO" ]]; then
    echo "  - In GitHub: delete $GITHUB_REPO if it was only a test repository"
fi
