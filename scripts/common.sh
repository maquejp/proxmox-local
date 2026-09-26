#!/usr/bin/env bash

set -euo pipefail

VM_USER="sysadmin"
PROJECTS_DIR="/home/${VM_USER}/Projects"
VM_ADMIN_SSH_KEY="/root/.ssh/id_ed25519_vm_admin"
VM_ADMIN_PUB_KEY="/root/.ssh/id_ed25519_vm_admin.pub"
MAC_SSH_KEY="/root/id_ed25519.pub"
KNOWN_HOSTS="/root/.ssh/known_hosts"

validate_vmid() {
    local vmid="${1:-}"
    if ! [[ "$vmid" =~ ^[0-9]+$ ]]; then
        echo "Error: VMID must be numeric: '$vmid'" >&2
        exit 1
    fi
}

validate_ip() {
    local ip="${1:-}"
    if ! [[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        echo "Error: invalid IPv4 address: '$ip'" >&2
        exit 1
    fi
}

ensure_vm_exists() {
    local vmid="$1"
    if ! qm status "$vmid" &>/dev/null; then
        echo "Error: VMID $vmid does not exist." >&2
        exit 1
    fi
}

ensure_vm_not_exists() {
    local vmid="$1"
    if qm status "$vmid" &>/dev/null; then
        echo "Error: VMID $vmid already exists." >&2
        exit 1
    fi
}

ensure_vm_running() {
    local vmid="$1"
    local status
    status="$(qm status "$vmid" 2>/dev/null | awk '{print $2}')"
    if [[ "$status" != "running" ]]; then
        echo "Error: VM $vmid is not running (current status: ${status:-unknown})." >&2
        echo "Start it with: qm start $vmid" >&2
        exit 1
    fi
}

ensure_admin_key_exists() {
    if [[ ! -f "$VM_ADMIN_SSH_KEY" ]]; then
        echo "Error: VM admin SSH private key not found: $VM_ADMIN_SSH_KEY" >&2
        exit 1
    fi
}

ssh_vm() {
    local vm_ip="$1"
    shift
    ssh \
        -i "$VM_ADMIN_SSH_KEY" \
        -o IdentitiesOnly=yes \
        -o BatchMode=yes \
        -o StrictHostKeyChecking=no \
        "${VM_USER}@${vm_ip}" \
        "$@"
}

wait_for_ssh() {
    local vm_ip="$1"
    local max_attempts="${2:-30}"
    local target="${VM_USER}@${vm_ip}"

    echo "Waiting for SSH on ${target}..."
    for _ in $(seq 1 "$max_attempts"); do
        if ssh \
            -i "$VM_ADMIN_SSH_KEY" \
            -o IdentitiesOnly=yes \
            -o ConnectTimeout=2 \
            -o BatchMode=yes \
            -o StrictHostKeyChecking=no \
            "$target" true 2>/dev/null; then
            echo "SSH is available."
            return 0
        fi
        sleep 2
    done

    echo "Error: SSH is not available on ${target} after $((max_attempts * 2)) seconds." >&2
    exit 1
}

open_vm_port() {
    local vm_ip="$1"
    local port="$2"
    local proto="${3:-tcp}"

    echo "Opening port ${port}/${proto} in VM firewall..."
    ssh_vm "$vm_ip" "sudo -n firewall-cmd --permanent --add-port=${port}/${proto} && \
        sudo -n firewall-cmd --reload && \
        sudo -n firewall-cmd --query-port=${port}/${proto} >/dev/null"
}
