#!/usr/bin/env bash

set -euo pipefail

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------

# VMIDs that must never be deleted by this script.
PROTECTED_VMIDS=(100)

# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------

error() {
    echo "Error: $*" >&2
    exit 1
}

is_protected() {
    local vmid="$1"

    for protected_vmid in "${PROTECTED_VMIDS[@]}"; do
        if [[ "$vmid" == "$protected_vmid" ]]; then
            return 0
        fi
    done

    return 1
}

usage() {
    cat <<EOF
Usage:
  $0              Interactive VM selection
  $0 <vmid>       Delete the specified VM

Examples:
  $0
  $0 201
EOF
    exit 1
}

# -----------------------------------------------------------------------------
# VM selection
# -----------------------------------------------------------------------------

select_vm() {
    local vmid

    echo "Available VMs:" >&2
    echo >&2

    printf "  %-6s %-30s %-10s %s\n" "ID" "NAME" "STATUS" "PROTECTION" >&2
    printf "  %-6s %-30s %-10s %s\n" "------" "------------------------------" "----------" "----------" >&2

    while read -r vmid name status; do
        if is_protected "$vmid"; then
            printf "  %-6s %-30s %-10s 🔒 protected\n" \
                "$vmid" "$name" "$status" >&2
        else
            printf "  %-6s %-30s %-10s\n" \
                "$vmid" "$name" "$status" >&2
        fi
    done < <(
        qm list | awk 'NR > 1 {
            vmid=$1
            status=$3

            name=""
            for (i=4; i<=NF; i++) {
                name = name (name ? " " : "") $i
            }

            print vmid, name, status
        }'
    )

    echo >&2
    read -r -p "Enter VMID to delete [q to quit]: " vmid

    if [[ "$vmid" == "q" || "$vmid" == "Q" ]]; then
        echo "Cancelled." >&2
        exit 0
    fi

    printf '%s\n' "$vmid"
}

# -----------------------------------------------------------------------------
# Arguments
# -----------------------------------------------------------------------------

if [[ $# -gt 1 ]]; then
    usage
fi

if [[ $# -eq 1 ]]; then
    VMID="$1"
else
    VMID="$(select_vm)"
fi

# -----------------------------------------------------------------------------
# Validate VMID
# -----------------------------------------------------------------------------

[[ "$VMID" =~ ^[0-9]+$ ]] || error "VMID must be a number."

(( VMID >= 100 )) || error "VMID must be >= 100."

if is_protected "$VMID"; then
    error "VMID $VMID is protected and cannot be deleted."
fi

# -----------------------------------------------------------------------------
# Check VM exists
# -----------------------------------------------------------------------------

if ! qm status "$VMID" >/dev/null 2>&1; then
    error "VM $VMID does not exist."
fi

VM_NAME="$(qm config "$VMID" | awk '/^name:/ {print $2}')"
VM_NAME="${VM_NAME:-unknown}"

VM_STATUS="$(qm status "$VMID" | awk '{print $2}')"

# -----------------------------------------------------------------------------
# Confirmation
# -----------------------------------------------------------------------------

echo
echo "VM selected:"
echo
echo "  ID:      $VMID"
echo "  Name:    $VM_NAME"
echo "  Status:  $VM_STATUS"
echo
echo "⚠️  This will permanently delete the VM and its disks."
echo

read -r -p "Delete VM $VMID ($VM_NAME)? [y/N] " CONFIRM

if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    exit 0
fi

# -----------------------------------------------------------------------------
# Stop VM if running
# -----------------------------------------------------------------------------

if [[ "$VM_STATUS" == "running" ]]; then
    echo
    echo "Stopping VM $VMID..."

    qm shutdown "$VMID"

    echo "Waiting for VM $VMID to stop..."

    for _ in {1..60}; do
        if [[ "$(qm status "$VMID" | awk '{print $2}')" == "stopped" ]]; then
            break
        fi

        sleep 1
    done

    if [[ "$(qm status "$VMID" | awk '{print $2}')" != "stopped" ]]; then
        error "VM $VMID did not stop within 60 seconds."
    fi
fi

# -----------------------------------------------------------------------------
# Destroy VM
# -----------------------------------------------------------------------------

echo "Destroying VM $VMID..."

qm destroy "$VMID" --purge

# -----------------------------------------------------------------------------
# Verification
# -----------------------------------------------------------------------------

if qm status "$VMID" >/dev/null 2>&1; then
    error "VM $VMID still exists after deletion."
fi

echo
echo "✓ VM $VMID ($VM_NAME) has been completely deleted."