#!/usr/bin/env bash

set -euo pipefail

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

# SSH key used by the Proxmox host to access development VMs.
SSH_PUBLIC_KEY="/root/.ssh/id_ed25519_vm_admin.pub"

# Reusable Rocky Linux Cloud-Init source image.
# This file is imported into local-lvm for each new development VM.
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

# ------------------------------------------------------------------------------
# Display command usage
# ------------------------------------------------------------------------------

usage() {
    cat <<EOF
Usage:
  $0 --name NAME --id VMID --ip IP [OPTIONS]

Required:
  --name NAME       VM name
  --id VMID         Proxmox VM ID
  --ip IP           Static IPv4 address

Optional:
  --cores N         CPU cores (default: ${CORES})
  --memory SIZE     RAM (default: ${MEMORY})
  --disk SIZE       Disk size (default: ${DISK})
  -h, --help        Show this help

Example:
  $0 --name taskmanager --id 201 --ip 192.168.1.201

  $0 --name big-project --id 202 --ip 192.168.1.202 \
     --cores 8 --memory 24G --disk 100G
EOF
}

# ------------------------------------------------------------------------------
# Validate Proxmox VM ID
# ------------------------------------------------------------------------------

validate_vmid() {
    if [[ ! "$VMID" =~ ^[0-9]+$ ]]; then
        echo "Error: VMID must be numeric: $VMID" >&2
        exit 1
    fi

    if (( VMID < 100 || VMID > 999999999 )); then
        echo "Error: invalid VMID: $VMID" >&2
        exit 1
    fi

    if qm status "$VMID" &>/dev/null; then
        echo "Error: VMID $VMID is already in use" >&2
        exit 1
    fi
}

# ------------------------------------------------------------------------------
# Validate IPv4 address
# ------------------------------------------------------------------------------

validate_ip() {
    local ip="$1"
    local IFS=.

    read -r o1 o2 o3 o4 <<< "$ip"

    if [[ -z "$o1" || -z "$o2" || -z "$o3" || -z "$o4" ]] ||
       ! [[ "$o1" =~ ^[0-9]+$ &&
            "$o2" =~ ^[0-9]+$ &&
            "$o3" =~ ^[0-9]+$ &&
            "$o4" =~ ^[0-9]+$ ]] ||
       (( o1 > 255 || o2 > 255 || o3 > 255 || o4 > 255 )); then
        echo "Error: invalid IPv4 address: $ip" >&2
        exit 1
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
            echo "Error: IP $ip is already configured for VM $vmid" >&2
            exit 1
        fi
    done < <(qm list | awk 'NR > 1 {print $1}')
}

# ------------------------------------------------------------------------------
# Validate Rocky Linux source image
# ------------------------------------------------------------------------------

validate_rocky_image() {
    if [[ ! -f "$ROCKY_IMAGE" ]]; then
        echo "Error: Rocky Linux image not found: $ROCKY_IMAGE" >&2
        exit 1
    fi
}

# ------------------------------------------------------------------------------
# Validate CPU core count
# ------------------------------------------------------------------------------

validate_cores() {
    if [[ ! "$CORES" =~ ^[1-9][0-9]*$ ]]; then
        echo "Error: invalid CPU core count: $CORES" >&2
        exit 1
    fi
}

# ------------------------------------------------------------------------------
# Validate disk size
# ------------------------------------------------------------------------------

validate_disk() {
    if [[ ! "$DISK" =~ ^[1-9][0-9]*G$ ]]; then
        echo "Error: invalid disk size: $DISK" >&2
        exit 1
    fi
}

# ------------------------------------------------------------------------------
# Validate SSH public key
# ------------------------------------------------------------------------------

validate_ssh_key() {
    if [[ ! -f "$SSH_PUBLIC_KEY" ]]; then
        echo "Error: SSH public key not found: $SSH_PUBLIC_KEY" >&2
        exit 1
    fi

    if [[ ! -r "$SSH_PUBLIC_KEY" ]]; then
        echo "Error: SSH public key is not readable: $SSH_PUBLIC_KEY" >&2
        exit 1
    fi
}

# ------------------------------------------------------------------------------
# Convert memory value to MiB for qm
#
# Examples:
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

    echo "Error: invalid memory size: $value" >&2
    exit 1
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

    qm resize "$VMID" scsi0 "$DISK"

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
        --ciuser dev \
        --sshkeys "$SSH_PUBLIC_KEY" \
        --ipconfig0 "ip=${IP}/24,gw=${GATEWAY}"

    qm cloudinit update "$VMID"

    echo "Cloud-Init configured."
}

# ==============================================================================
# Parse command-line arguments
# ==============================================================================

while [[ $# -gt 0 ]]; do
    case "$1" in
        --name)
            [[ $# -ge 2 ]] || {
                echo "Error: --name requires a value" >&2
                exit 1
            }
            NAME="$2"
            shift 2
            ;;
        --id)
            [[ $# -ge 2 ]] || {
                echo "Error: --id requires a value" >&2
                exit 1
            }
            VMID="$2"
            shift 2
            ;;
        --ip)
            [[ $# -ge 2 ]] || {
                echo "Error: --ip requires a value" >&2
                exit 1
            }
            IP="$2"
            shift 2
            ;;
        --cores)
            [[ $# -ge 2 ]] || {
                echo "Error: --cores requires a value" >&2
                exit 1
            }
            CORES="$2"
            shift 2
            ;;
        --memory)
            [[ $# -ge 2 ]] || {
                echo "Error: --memory requires a value" >&2
                exit 1
            }
            MEMORY="$2"
            shift 2
            ;;
        --disk)
            [[ $# -ge 2 ]] || {
                echo "Error: --disk requires a value" >&2
                exit 1
            }
            DISK="$2"
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

if [[ -z "$NAME" ]]; then
    echo "Error: --name is required" >&2
    exit 1
fi

if [[ -z "$VMID" ]]; then
    echo "Error: --id is required" >&2
    exit 1
fi

if [[ -z "$IP" ]]; then
    echo "Error: --ip is required" >&2
    exit 1
fi

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

MEMORY_MIB=$(memory_to_mib "$MEMORY")

# ==============================================================================
# Display configuration
# ==============================================================================

echo "VM name : $NAME"
echo "VM ID   : $VMID"
echo "IP      : $IP"
echo "Cores   : $CORES"
echo "Memory  : $MEMORY ($MEMORY_MIB MiB)"
echo "Disk    : $DISK"

# ==============================================================================
# Provision VM
# ==============================================================================

create_vm
configure_disk
configure_cloud_init

echo "Starting VM..."
qm start "$VMID"

echo "VM $VMID started."