#!/usr/bin/env bash

set -euo pipefail

TEMPLATE_ID=198
GATEWAY="192.168.1.1"
SSH_KEY="/root/id_ed25519.pub"

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

if [[ ! -f "$SSH_KEY" ]]; then
    echo "Error: SSH public key not found: $SSH_KEY"
    exit 1
fi

if ! [[ "$VM_IP" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
    echo "Error: invalid IPv4 address: $VM_IP"
    exit 1
fi

echo "Creating VM $VMID ($VM_NAME) with IP $VM_IP..."

qm clone "$TEMPLATE_ID" "$VMID" \
    --name "$VM_NAME" \
    --full 1

qm set "$VMID" \
    --ciuser sysadmin \
    --sshkeys "$SSH_KEY" \
    --ipconfig0 "ip=${VM_IP}/24,gw=${GATEWAY}"

qm start "$VMID"

echo
echo "VM created:"
echo "  ID:       $VMID"
echo "  Name:     $VM_NAME"
echo "  IP:       $VM_IP"
echo "  SSH:      ssh sysadmin@$VM_IP"