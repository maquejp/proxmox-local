#!/usr/bin/env bash

set -euo pipefail

# Defaults
CORES=6
MEMORY="16G"
DISK="60G"

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

  $0 --name big-project --id 202 --ip 192.168.1.202 \\
     --cores 8 --memory 24G --disk 100G
EOF
}

NAME=""
VMID=""
IP=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --name)
            NAME="$2"
            shift 2
            ;;
        --id)
            VMID="$2"
            shift 2
            ;;
        --ip)
            IP="$2"
            shift 2
            ;;
        --cores)
            CORES="$2"
            shift 2
            ;;
        --memory)
            MEMORY="$2"
            shift 2
            ;;
        --disk)
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

# Required arguments
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

echo "VM name : $NAME"
echo "VM ID   : $VMID"
echo "IP      : $IP"
echo "Cores   : $CORES"
echo "Memory  : $MEMORY"
echo "Disk    : $DISK"