#!/usr/bin/env bash

set -euo pipefail

TEMPLATE_ID=198
GATEWAY="192.168.1.1"
MAC_SSH_KEY="/root/id_ed25519.pub"
VM_ADMIN_SSH_KEY="/root/.ssh/id_ed25519_vm_admin.pub"

VMID="${1:-}"
VM_NAME="${2:-}"
VM_IP="${3:-}"

usage() {
    echo "Usage: $0 <vmid> <name> <ip>"
    echo "Example: $0 150 atlantis 192.168.1.150"
    exit 1
}

[[ -n "$VMID" && -n "$VM_NAME" && -n "$VM_IP" ]] || usage

if ! [[ "$VMID" =~ ^[0-9]+$ ]]; then
    echo "Error: VMID must be numeric."
    exit 1
fi

if qm status "$VMID" &>/dev/null; then
    echo "Error: VMID $VMID already exists."
    exit 1
fi

if ! qm status "$TEMPLATE_ID" &>/dev/null; then
    echo "Error: template $TEMPLATE_ID does not exist."
    exit 1
fi

if [[ ! -f "$MAC_SSH_KEY" ]]; then
    echo "Error: SSH public key not found: $MAC_SSH_KEY"
    exit 1
fi

if [[ ! -f "$VM_ADMIN_SSH_KEY" ]]; then
    echo "Error: SSH public key not found: $VM_ADMIN_SSH_KEY"
    exit 1
fi

if ! [[ "$VM_IP" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
    echo "Error: invalid IPv4 address: $VM_IP"
    exit 1
fi

echo "Creating VM $VMID ($VM_NAME) with IP $VM_IP..."

SSH_KEYS_FILE="$(mktemp)"

cat "$MAC_SSH_KEY" "$VM_ADMIN_SSH_KEY" > "$SSH_KEYS_FILE"

trap 'rm -f "$SSH_KEYS_FILE"' EXIT

qm clone "$TEMPLATE_ID" "$VMID" \
    --name "$VM_NAME" \
    --full 1

qm set "$VMID" \
    --ciuser sysadmin \
    --sshkeys "$SSH_KEYS_FILE" \
    --ipconfig0 "ip=${VM_IP}/24,gw=${GATEWAY}"

qm start "$VMID"

echo
echo "VM created:"
echo "  ID:       $VMID"
echo "  Name:     $VM_NAME"
echo "  IP:       $VM_IP"
echo "  SSH:      ssh sysadmin@$VM_IP"