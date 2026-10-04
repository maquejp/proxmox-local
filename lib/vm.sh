#!/usr/bin/env bash

# ==============================================================================
# VM validation and remote access
# ==============================================================================

LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${LIB_DIR}/config.sh"
source "${LIB_DIR}/common.sh"

validate_vmid() {
  if [[ ! "$VMID" =~ ^[0-9]+$ ]]; then
    error "VMID must be numeric: $VMID"
  fi

  if ! qm status "$VMID" &>/dev/null; then
    error "VMID $VMID does not exist"
  fi
}

validate_vm_running() {
  local status
  status=$(qm status "$VMID" | awk '{print $2}')

  if [[ "$status" != "running" ]]; then
    error "VM $VMID is not running"
  fi
}

get_vm_ip() {
  local ip

  ip=$(
    qm config "$VMID" |
    awk -F'ip=' '/^ipconfig0:/ {
      split($2, a, ",")
      print a[1]
    }' |
    cut -d/ -f1
  )

  if [[ -z "$ip" ]]; then
    error "No static IP configured for VM $VMID"
  fi

  echo "$ip"
}

validate_ssh() {
  log_info "Checking SSH connectivity..."

  if ! ssh \
    -i "${SSH_PRIVATE_KEY:-${SSH_PRIVATE_KEY_ADMIN}}" \
    -o BatchMode=yes \
    -o IdentitiesOnly=yes \
    -o StrictHostKeyChecking=accept-new \
    -o ConnectTimeout="${SSH_CONNECT_TIMEOUT:-5}" \
    "${DEV_USER}@${VM_IP}" \
    true; then

    error "SSH connection failed: ${DEV_USER}@${VM_IP}"
  fi

  log_success "SSH connectivity OK."
}

run_remote() {
  ssh \
    -i "${SSH_PRIVATE_KEY:-${SSH_PRIVATE_KEY_ADMIN}}" \
    -o BatchMode=yes \
    -o IdentitiesOnly=yes \
    -o StrictHostKeyChecking=accept-new \
    -o ConnectTimeout="${SSH_CONNECT_TIMEOUT:-5}" \
    "${DEV_USER}@${VM_IP}" \
    "$@"
}
