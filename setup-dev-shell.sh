#!/usr/bin/env bash

set -euo pipefail

LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd)"
source "${LIB_DIR}/config.sh"
source "${LIB_DIR}/common.sh"
source "${LIB_DIR}/vm.sh"
source "${LIB_DIR}/shell.sh"

DEV_USER="${DEV_USER}"
SSH_PRIVATE_KEY="${SSH_PRIVATE_KEY_ADMIN}"
SSH_PUBLIC_KEY="${SSH_PUBLIC_KEY_ADMIN}"
EZA_VERSION="${EZA_VERSION}"

VMID=""

usage() {
  cat <<EOF
Usage:

  $0                        Interactive VM selection
  $0 --vm VMID              Specify target Proxmox VM ID

Options:
  --vm VMID                 Proxmox VM ID
  -h, --help                Show this help

Examples:
  $0
  $0 --vm 203
EOF
}

select_vm() {
  local vmid
  echo "Available VMs:" >&2
  echo >&2
  printf "  %-6s %-30s %-10s\n" "ID" "NAME" "STATUS" >&2
  printf "  %-6s %-30s %-10s\n" "------" "------------------------------" "----------" >&2
  while read -r vmid name status; do
    printf "  %-6s %-30s %-10s\n" "$vmid" "$name" "$status" >&2
  done < <(
    qm list | awk 'NR > 1 {
      vmid=$1; status=$3
      name=""; for (i=4; i<=NF; i++) { name = name (name ? " " : "") $i }
      print vmid, name, status
    }'
  )
  echo >&2
  read -r -p "Enter VMID to configure [q to quit]: " vmid
  if [[ "$vmid" == "q" || "$vmid" == "Q" ]]; then
    echo "Cancelled." >&2
    exit 0
  fi
  printf '%s\n' "$vmid"
}

# Argument parsing
while [[ $# -gt 0 ]]; do
  case "$1" in
    --vm)
      [[ $# -ge 2 ]] || error "--vm requires a value"
      VMID="$2"; shift 2 ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      if [[ -z "$VMID" && "$1" =~ ^[0-9]+$ ]]; then
        VMID="$1"; shift
      else
        echo "Error: unknown option: $1" >&2; usage >&2; exit 1
      fi ;;
  esac
done

if [[ -z "$VMID" ]]; then
  if [[ -t 0 ]]; then
    VMID="$(select_vm)"
  else
    error "--vm is required in non-interactive mode"
  fi
fi

setup_dev_shell
