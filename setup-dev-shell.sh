#!/usr/bin/env bash

set -euo pipefail

# ==============================================================================
# Proxmox Development VM - Developer Shell Setup
# ==============================================================================

# ------------------------------------------------------------------------------
# Defaults
# ------------------------------------------------------------------------------

DEV_USER="dev"
SSH_PRIVATE_KEY="/root/.ssh/id_ed25519_vm_admin"

# ------------------------------------------------------------------------------
# Arguments
# ------------------------------------------------------------------------------

VMID=""

# ==============================================================================
# Functions
# ==============================================================================

usage() {
    cat <<EOF
Usage:
  $0 --vm VMID

Required:
  --vm VMID         Proxmox VM ID

Options:
  -h, --help        Show this help

Example:
  $0 --vm 203
EOF
}

error() {
    echo "Error: $*" >&2
    exit 1
}

validate_vmid() {
    if [[ ! "$VMID" =~ ^[0-9]+$ ]]; then
        error "VMID must be numeric: $VMID"
    fi

    if ! qm status "$VMID" &>/dev/null; then
        error "VMID $VMID does not exist"
    fi
}

validate_ssh_key() {
    if [[ ! -f "$SSH_PRIVATE_KEY" ]]; then
        error "SSH private key not found: $SSH_PRIVATE_KEY"
    fi

    if [[ ! -r "$SSH_PRIVATE_KEY" ]]; then
        error "SSH private key is not readable: $SSH_PRIVATE_KEY"
    fi
}

get_vm_ip() {
    local ip

    ip=$(qm config "$VMID" |
        awk -F'ip=' '/^ipconfig0:/ {
            split($2, a, ",")
            print a[1]
        }' |
        cut -d/ -f1)

    if [[ -z "$ip" ]]; then
        error "No static IP configured for VM $VMID"
    fi

    echo "$ip"
}

validate_vm_running() {
    local status

    status=$(qm status "$VMID" | awk '{print $2}')

    if [[ "$status" != "running" ]]; then
        error "VM $VMID is not running"
    fi
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
# Argument parsing
# ==============================================================================

while [[ $# -gt 0 ]]; do
    case "$1" in
        --vm)
            [[ $# -ge 2 ]] || error "--vm requires a value"
            VMID="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Error: unknown option: $1" >&2
            usage >&2
            exit 1
            ;;
    esac
done

# ==============================================================================
# Validation
# ==============================================================================

if [[ -z "$VMID" ]]; then
    error "--vm is required"
fi

validate_vmid
validate_ssh_key

VM_IP=$(get_vm_ip)

validate_vm_running
validate_ssh

# ==============================================================================
# Summary
# ==============================================================================

echo
echo "Developer shell setup target:"
echo "  VM ID   : $VMID"
echo "  VM IP   : $VM_IP"
echo "  User    : $DEV_USER"
echo "  SSH key : $SSH_PRIVATE_KEY"
echo
echo "Connection verified."