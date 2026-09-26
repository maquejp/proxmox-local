#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/common.sh
source "${SCRIPT_DIR}/common.sh"

TEMPLATE_ID=198
GATEWAY="192.168.1.1"

VMID="${1:-}"
VM_NAME="${2:-}"
VM_IP="${3:-}"

usage() {
    echo "Usage: $0 <vmid> <name> <ip>"
    echo "Example: $0 150 atlantis 192.168.1.150"
    exit 1
}

[[ -n "$VMID" && -n "$VM_NAME" && -n "$VM_IP" ]] || usage

validate_vmid "$VMID"
validate_ip "$VM_IP"
ensure_vm_not_exists "$VMID"

if ! qm status "$TEMPLATE_ID" &>/dev/null; then
    echo "Error: template $TEMPLATE_ID does not exist." >&2
    exit 1
fi

if [[ ! -f "$MAC_SSH_KEY" ]]; then
    echo "Error: SSH public key not found: $MAC_SSH_KEY" >&2
    exit 1
fi

if [[ ! -f "$VM_ADMIN_PUB_KEY" ]]; then
    echo "Error: SSH public key not found: $VM_ADMIN_PUB_KEY" >&2
    exit 1
fi

echo "Creating VM $VMID ($VM_NAME) with IP $VM_IP..."

SSH_KEYS_FILE="$(mktemp)"
cat "$MAC_SSH_KEY" "$VM_ADMIN_PUB_KEY" > "$SSH_KEYS_FILE"
trap 'rm -f "$SSH_KEYS_FILE"' EXIT

qm clone "$TEMPLATE_ID" "$VMID" \
    --name "$VM_NAME" \
    --full 1

qm set "$VMID" \
    --ciuser "$VM_USER" \
    --sshkeys "$SSH_KEYS_FILE" \
    --ipconfig0 "ip=${VM_IP}/24,gw=${GATEWAY}"

qm start "$VMID"

echo
echo "VM created:"
echo "  ID:       $VMID"
echo "  Name:     $VM_NAME"
echo "  IP:       $VM_IP"
echo "  SSH:      ssh ${VM_USER}@$VM_IP"
