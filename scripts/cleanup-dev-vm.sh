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
    echo "Example: $0 153 mon-projet 192.168.1.153 maquejp/mon-projet"
    exit 1
}

[[ -n "$VMID" && -n "$PROJECT_NAME" && -n "$VM_IP" ]] || usage

validate_vmid "$VMID"
validate_ip "$VM_IP"

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
