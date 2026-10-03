#!/usr/bin/env bash

set -euo pipefail

trap '[[ -n "${SSH_KEYS_FILE:-}" ]] && rm -f "$SSH_KEYS_FILE"' EXIT

# ==============================================================================
# Proxmox Development VM
# ==============================================================================

# ------------------------------------------------------------------------------
# Defaults
# ------------------------------------------------------------------------------

CORES=6
MEMORY="16G"
DISK="60G"

# ------------------------------------------------------------------------------
# Proxmox configuration
# ------------------------------------------------------------------------------

STORAGE="local-lvm"
BRIDGE="vmbr0"
GATEWAY="192.168.1.1"
MACHINE="q35"
BIOS="seabios"
CPU="host"
OS_TYPE="l26"

# ------------------------------------------------------------------------------
# SSH configuration
# ------------------------------------------------------------------------------

DEV_USER="dev"
SSH_PRIVATE_KEY="/root/.ssh/id_ed25519_vm_admin"
SSH_PUBLIC_KEY="/root/.ssh/id_ed25519_vm_admin.pub"
DEVELOPER_SSH_PUBLIC_KEY=""
SSH_KEYS_FILE=""
SSH_TIMEOUT=60

# ------------------------------------------------------------------------------
# Rocky Linux image
# ------------------------------------------------------------------------------

ROCKY_IMAGE="/var/lib/vz/template/qcow2/Rocky-10-GenericCloud-Base-10.2-20260525.0.x86_64.qcow2"

# ------------------------------------------------------------------------------
# Arguments
# ------------------------------------------------------------------------------

NAME=""
VMID=""
IP=""

# ==============================================================================
# Functions
# ==============================================================================

usage() {

    cat <<EOF

Usage:

$0 --name NAME --id VMID --ip IP [OPTIONS]

Required:

  --name NAME       VM name

  --id VMID         Proxmox VM ID

  --ip IP           Static IPv4 address

  --ssh-public-key PATH
                    Developer SSH public key

Optional:

  --cores N         CPU cores (default: ${CORES})

  --memory SIZE     RAM (default: ${MEMORY})

  --disk SIZE       Disk size (default: ${DISK})

  -h, --help        Show this help

Example:

$0 --name taskmanager --id 201 --ip 192.168.1.201 \
    --ssh-public-key /root/id_ed25519.pub

$0 --name big-project --id 202 --ip 192.168.1.202 \
    --cores 8 --memory 24G --disk 100G \
    --ssh-public-key /root/id_ed25519.pub

EOF
}

error() {

    echo "Error: $*" >&2
    exit 1
}

# ------------------------------------------------------------------------------
# Validate Proxmox VM ID
# ------------------------------------------------------------------------------

validate_vmid() {

    if [[ ! "$VMID" =~ ^[0-9]+$ ]]; then
        error "VMID must be numeric: $VMID"
    fi

    if (( VMID < 100 || VMID > 999999999 )); then
        error "Invalid VMID: $VMID"
    fi

    if qm status "$VMID" &>/dev/null; then
        error "VMID $VMID is already in use"
    fi
}

# ------------------------------------------------------------------------------
# Validate IPv4 address
# ------------------------------------------------------------------------------

validate_ip() {

    local ip="$1"
    local IFS=.

    read -r o1 o2 o3 o4 <<< "$ip"

    if [[ -z "$o1" ||
          -z "$o2" ||
          -z "$o3" ||
          -z "$o4" ]] ||
       ! [[ "$o1" =~ ^[0-9]+$ &&
            "$o2" =~ ^[0-9]+$ &&
            "$o3" =~ ^[0-9]+$ &&
            "$o4" =~ ^[0-9]+$ ]] ||
       (( o1 > 255 ||
           o2 > 255 ||
           o3 > 255 ||
           o4 > 255 )); then

        error "Invalid IPv4 address: $ip"
    fi
}

# ------------------------------------------------------------------------------
# Check that the requested IP isn't already configured on another VM
# ------------------------------------------------------------------------------

validate_ip_not_configured() {

    local ip="$1"

    while read -r vmid; do

        [[ -z "$vmid" ]] && continue

        if qm config "$vmid" |
            grep -qE "^ipconfig[0-9]+:.*ip=${ip}(/|,|$)"; then

            error "IP $ip is already configured for VM $vmid"
        fi

    done < <(qm list | awk 'NR > 1 {print $1}')
}

# ------------------------------------------------------------------------------
# Validate Rocky Linux source image
# ------------------------------------------------------------------------------

validate_rocky_image() {

    if [[ ! -f "$ROCKY_IMAGE" ]]; then
        error "Rocky Linux image not found: $ROCKY_IMAGE"
    fi
}

# ------------------------------------------------------------------------------
# Validate CPU core count
# ------------------------------------------------------------------------------

validate_cores() {

    if [[ ! "$CORES" =~ ^[1-9][0-9]*$ ]]; then
        error "Invalid CPU core count: $CORES"
    fi
}

# ------------------------------------------------------------------------------
# Validate disk size
# ------------------------------------------------------------------------------

validate_disk() {

    if [[ ! "$DISK" =~ ^[1-9][0-9]*G$ ]]; then
        error "Invalid disk size: $DISK"
    fi
}

# ------------------------------------------------------------------------------
# Validate Proxmox SSH keys
# ------------------------------------------------------------------------------

validate_ssh_key() {

    if [[ ! -f "$SSH_PRIVATE_KEY" ]]; then
        error "SSH private key not found: $SSH_PRIVATE_KEY"
    fi

    if [[ ! -r "$SSH_PRIVATE_KEY" ]]; then
        error "SSH private key is not readable: $SSH_PRIVATE_KEY"
    fi

    if [[ ! -f "$SSH_PUBLIC_KEY" ]]; then
        error "SSH public key not found: $SSH_PUBLIC_KEY"
    fi

    if [[ ! -r "$SSH_PUBLIC_KEY" ]]; then
        error "SSH public key is not readable: $SSH_PUBLIC_KEY"
    fi
}

# ------------------------------------------------------------------------------
# Validate developer SSH public key
# ------------------------------------------------------------------------------

validate_developer_ssh_key() {

    if [[ -z "$DEVELOPER_SSH_PUBLIC_KEY" ]]; then
        error "Developer SSH public key is required: use --ssh-public-key"
    fi

    if [[ ! -f "$DEVELOPER_SSH_PUBLIC_KEY" ]]; then
        error "Developer SSH public key not found: $DEVELOPER_SSH_PUBLIC_KEY"
    fi

    if [[ ! -r "$DEVELOPER_SSH_PUBLIC_KEY" ]]; then
        error "Developer SSH public key is not readable: $DEVELOPER_SSH_PUBLIC_KEY"
    fi
}

# ------------------------------------------------------------------------------
# Prepare SSH public keys for Cloud-Init
# ------------------------------------------------------------------------------

prepare_ssh_keys() {

    SSH_KEYS_FILE=$(mktemp)

    cat \
        "$SSH_PUBLIC_KEY" \
        "$DEVELOPER_SSH_PUBLIC_KEY" \
        > "$SSH_KEYS_FILE"
}

# ------------------------------------------------------------------------------
# Convert memory value to MiB
#
# Examples:
#
#   16G  -> 16384
#   24G  -> 24576
#   8192 -> 8192
# ------------------------------------------------------------------------------

memory_to_mib() {

    local value="$1"

    if [[ "$value" =~ ^([0-9]+)G$ ]]; then
        echo $((BASH_REMATCH[1] * 1024))
        return
    fi

    if [[ "$value" =~ ^[0-9]+$ ]]; then
        echo "$value"
        return
    fi

    error "Invalid memory size: $value"
}

# ------------------------------------------------------------------------------
# Create the basic Proxmox VM
# ------------------------------------------------------------------------------

create_vm() {

    echo "Creating VM $VMID ($NAME)..."

    qm create "$VMID" \
        --name "$NAME" \
        --machine "$MACHINE" \
        --bios "$BIOS" \
        --memory "$MEMORY_MIB" \
        --cores "$CORES" \
        --cpu "$CPU" \
        --net0 "virtio,bridge=$BRIDGE,firewall=1" \
        --ostype "$OS_TYPE" \
        --agent enabled=1

    echo "VM $VMID created."
}

# ------------------------------------------------------------------------------
# Disk provisioning
# ------------------------------------------------------------------------------

configure_disk() {

    echo "Importing Rocky Linux image..."

    qm importdisk \
        "$VMID" \
        "$ROCKY_IMAGE" \
        "$STORAGE"

    echo "Configuring VM disk..."

    qm set "$VMID" \
        --scsihw virtio-scsi-single

    qm set "$VMID" \
        --scsi0 "${STORAGE}:vm-${VMID}-disk-0,iothread=1"

    qm resize \
        "$VMID" \
        scsi0 \
        "$DISK"

    qm set "$VMID" \
        --boot "order=scsi0"

    echo "Disk configured."
}

# ------------------------------------------------------------------------------
# Cloud-Init configuration
# ------------------------------------------------------------------------------

configure_cloud_init() {

    echo "Configuring Cloud-Init..."

    qm set "$VMID" \
        --ide2 "$STORAGE:cloudinit" \
        --ciuser "$DEV_USER" \
        --sshkeys "$SSH_KEYS_FILE" \
        --ipconfig0 "ip=${IP}/24,gw=${GATEWAY}"

    qm cloudinit update "$VMID"

    echo "Cloud-Init configured."
}

# ------------------------------------------------------------------------------
# Remove stale SSH host key
#
# Development VMs are disposable and may reuse an IP address.
# When a VM is recreated, its SSH host key changes.
# ------------------------------------------------------------------------------

remove_stale_ssh_host_key() {

    echo "Removing any previous SSH host key for $IP..."

    ssh-keygen \
        -f "$HOME/.ssh/known_hosts" \
        -R "$IP" \
        >/dev/null 2>&1 || true
}

# ------------------------------------------------------------------------------
# Wait until SSH is available
# ------------------------------------------------------------------------------

wait_for_ssh() {

    echo "Waiting for SSH..."

    local attempts=$((SSH_TIMEOUT / 2))

    for ((i = 1; i <= attempts; i++)); do

        if ssh \
            -i "$SSH_PRIVATE_KEY" \
            -o BatchMode=yes \
            -o StrictHostKeyChecking=accept-new \
            -o ConnectTimeout=3 \
            "${DEV_USER}@${IP}" \
            true 2>/dev/null; then

            echo "SSH is available."
            return 0
        fi

        sleep 2
    done

    error "SSH did not become available within ${SSH_TIMEOUT} seconds."
}

# ==============================================================================
# Argument parsing
# ==============================================================================

while [[ $# -gt 0 ]]; do

    case "$1" in

        --name)

            [[ $# -ge 2 ]] || error "--name requires a value"

            NAME="$2"

            shift 2

            ;;

        --id)

            [[ $# -ge 2 ]] || error "--id requires a value"

            VMID="$2"

            shift 2

            ;;

        --ip)

            [[ $# -ge 2 ]] || error "--ip requires a value"

            IP="$2"

            shift 2

            ;;

        --cores)

            [[ $# -ge 2 ]] || error "--cores requires a value"

            CORES="$2"

            shift 2

            ;;

        --memory)

            [[ $# -ge 2 ]] || error "--memory requires a value"

            MEMORY="$2"

            shift 2

            ;;

        --disk)

            [[ $# -ge 2 ]] || error "--disk requires a value"

            DISK="$2"

            shift 2

            ;;

        --ssh-public-key)

            [[ $# -ge 2 ]] || error "--ssh-public-key requires a value"

            DEVELOPER_SSH_PUBLIC_KEY="$2"

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
# Required arguments
# ==============================================================================

[[ -n "$NAME" ]] || error "--name is required"
[[ -n "$VMID" ]] || error "--id is required"
[[ -n "$IP" ]] || error "--ip is required"

# ==============================================================================
# Validation
# ==============================================================================

validate_vmid
validate_ip "$IP"
validate_ip_not_configured "$IP"
validate_rocky_image
validate_cores
validate_disk
validate_ssh_key
validate_developer_ssh_key
prepare_ssh_keys

MEMORY_MIB=$(memory_to_mib "$MEMORY")

# ==============================================================================
# Display configuration
# ==============================================================================

echo

echo "Development VM configuration:"

echo "  Name                : $NAME"
echo "  VM ID               : $VMID"
echo "  IP                  : $IP"
echo "  Cores               : $CORES"
echo "  Memory              : $MEMORY"
echo "  Disk                : $DISK"
echo "  Storage             : $STORAGE"
echo "  Bridge              : $BRIDGE"
echo "  SSH automation key  : $SSH_PUBLIC_KEY"
echo "  SSH developer key   : $DEVELOPER_SSH_PUBLIC_KEY"

echo

# ==============================================================================
# Provision VM
# ==============================================================================

create_vm
configure_disk
configure_cloud_init

# A recreated disposable VM may reuse an IP previously associated with
# another VM. Remove that stale host key before accepting the new one.

remove_stale_ssh_host_key

echo "Starting VM..."

qm start "$VMID"

echo "VM $VMID started."

wait_for_ssh

# ==============================================================================
# Summary
# ==============================================================================

echo

echo "Development VM ready:"

echo "  VM ID : $VMID"
echo "  Name  : $NAME"
echo "  IP    : $IP"
echo "  SSH   : ${DEV_USER}@${IP}"

echo