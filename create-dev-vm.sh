#!/usr/bin/env bash

set -euo pipefail

LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd)"
source "${LIB_DIR}/config.sh"
source "${LIB_DIR}/common.sh"
source "${LIB_DIR}/vm.sh"

# Defaults
CORES=6
MEMORY="16G"
DISK="20G"

# Proxmox configuration
STORAGE="${PROXMOX_STORAGE}"
BRIDGE="${PROXMOX_BRIDGE}"
GATEWAY="${PROXMOX_GATEWAY}"
MACHINE="${PROXMOX_MACHINE}"
BIOS="${PROXMOX_BIOS}"
CPU="${PROXMOX_CPU}"
OS_TYPE="${PROXMOX_OS_TYPE}"

# SSH configuration
DEV_USER="${DEV_USER}"
SSH_PRIVATE_KEY="${SSH_PRIVATE_KEY_ADMIN}"
SSH_PUBLIC_KEY="${SSH_PUBLIC_KEY_ADMIN}"
DEVELOPER_SSH_PUBLIC_KEY="${DEVELOPER_SSH_PUBLIC_KEY_DEFAULT}"
SSH_KEYS_FILE=""
SSH_TIMEOUT="${SSH_TIMEOUT}"

# Rocky Linux image
ROCKY_IMAGE="${ROCKY_IMAGE_DEFAULT}"

# Arguments
NAME=""
VMID=""
IP=""

usage() {
  cat <<EOF
Usage:

  $0 --name NAME --id VMID --ip IP [OPTIONS]

Required:
  --name NAME           VM name
  --id VMID             Proxmox VM ID
  --ip IP               Static IPv4 address

Optional:
  --ssh-public-key PATH Developer SSH public key (default: ${DEVELOPER_SSH_PUBLIC_KEY})
  --cores N             CPU cores (default: ${CORES})
  --memory SIZE         RAM (default: ${MEMORY})
  --disk SIZE           Disk size (default: ${DISK})
  --rocky-image PATH    Rocky Linux image (default: ${ROCKY_IMAGE_DEFAULT})
  -h, --help            Show this help

Example:
  $0 --name taskmanager --id 201 --ip 192.168.1.201 \\
      --ssh-public-key /root/id_ed25519.pub
EOF
}

validate_vmid_available() {
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

validate_ip() {
  local ip="$1"
  local IFS=.
  local o1 o2 o3 o4
  read -r o1 o2 o3 o4 <<< "$ip"
  if [[ -z "$o1" || -z "$o2" || -z "$o3" || -z "$o4" ]] ||
     ! [[ "$o1" =~ ^[0-9]+$ && "$o2" =~ ^[0-9]+$ && "$o3" =~ ^[0-9]+$ && "$o4" =~ ^[0-9]+$ ]] ||
     (( o1 > 255 || o2 > 255 || o3 > 255 || o4 > 255 )); then
    error "Invalid IPv4 address: $ip"
  fi
}

validate_ip_not_configured() {
  local ip="$1"
  while read -r vmid; do
    [[ -z "$vmid" ]] && continue
    if qm config "$vmid" | grep -qE "^ipconfig[0-9]+:.*ip=${ip}(/|,|$)"; then
      error "IP $ip is already configured for VM $vmid"
    fi
  done < <(qm list | awk 'NR > 1 {print $1}')
}

validate_rocky_image() {
  if [[ ! -f "$ROCKY_IMAGE" ]]; then
    error "Rocky Linux image not found: $ROCKY_IMAGE"
  fi
}

validate_cores() {
  if [[ ! "$CORES" =~ ^[1-9][0-9]*$ ]]; then
    error "Invalid CPU core count: $CORES"
  fi
}

validate_disk() {
  if [[ ! "$DISK" =~ ^[1-9][0-9]*[GTg]$ ]]; then
    error "Invalid disk size: $DISK (expected e.g., 60G, 100G)"
  fi
}

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

prepare_ssh_keys() {
  SSH_KEYS_FILE=$(mktemp)
  add_cleanup "[[ -n \"$SSH_KEYS_FILE\" ]] && rm -f \"$SSH_KEYS_FILE\""
  cat "$SSH_PUBLIC_KEY" "$DEVELOPER_SSH_PUBLIC_KEY" > "$SSH_KEYS_FILE"
}

memory_to_mib() {
  local value="$1"
  if [[ "$value" =~ ^([0-9]+)[Gg]$ ]]; then
    echo $((BASH_REMATCH[1] * 1024)); return
  fi
  if [[ "$value" =~ ^([0-9]+)G[iI][bB]$ ]]; then
    echo $((BASH_REMATCH[1] * 1024)); return
  fi
  if [[ "$value" =~ ^[0-9]+$ ]]; then
    echo "$value"; return
  fi
  if [[ "$value" =~ ^([0-9]+)[Mm][iI]?[bB]?$ ]]; then
    echo "$BASH_REMATCH[1]"; return
  fi
  error "Invalid memory size: $value"
}

prompt_if_empty() {
  local var_name="$1"
  local prompt="$2"
  local default="${3:-}"
  local value="${!var_name}"

  if [[ -n "$value" ]]; then
    return
  fi

  if ! [[ -t 0 ]]; then
    if [[ -n "$default" ]]; then
      eval "$var_name=\"$default\""
      return
    fi
    error "$var_name is required"
  fi

  local response=""
  if [[ -n "$default" ]]; then
    read -r -p "$prompt [$default]: " response
    response="${response:-$default}"
  else
    read -r -p "$prompt: " response
    if [[ -z "$response" ]]; then
      error "$prompt cannot be empty"
    fi
  fi
  eval "$var_name=\"$response\""
}

prompt_ssh_key_if_empty() {
  if [[ -n "$DEVELOPER_SSH_PUBLIC_KEY" ]]; then
    return
  fi
  if ! [[ -t 0 ]]; then
    error "--ssh-public-key is required"
  fi
  local response=""
  while [[ -z "$response" ]]; do
    read -r -p "Developer SSH public key path: " response
  done
  DEVELOPER_SSH_PUBLIC_KEY="$response"
}


create_vm() {
  log_info "Creating VM $VMID ($NAME)..."
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
  log_success "VM $VMID created."
}

configure_disk() {
  log_info "Importing Rocky Linux image..."
  qm importdisk "$VMID" "$ROCKY_IMAGE" "$STORAGE"
  log_info "Configuring VM disk..."
  qm set "$VMID" --scsihw virtio-scsi-single
  qm set "$VMID" --scsi0 "${STORAGE}:vm-${VMID}-disk-0,iothread=1"
  qm resize "$VMID" scsi0 "$DISK"
  qm set "$VMID" --boot "order=scsi0"
  log_success "Disk configured."
}

configure_cloud_init() {
  log_info "Configuring Cloud-Init..."
  qm set "$VMID" \
    --ide2 "$STORAGE:cloudinit" \
    --ciuser "$DEV_USER" \
    --sshkeys "$SSH_KEYS_FILE" \
    --ipconfig0 "ip=${IP}/24,gw=${GATEWAY}"
  qm cloudinit update "$VMID"
  log_success "Cloud-Init configured."
}

remove_stale_ssh_host_key() {
  log_info "Removing any previous SSH host key for $IP..."
  ssh-keygen -f "${HOME}/.ssh/known_hosts" -R "$IP" >/dev/null 2>&1 || true
}

wait_for_ssh() {
  log_info "Waiting for SSH..."
  local attempts=$((SSH_TIMEOUT / 2))
  for ((i = 1; i <= attempts; i++)); do
    if ssh \
      -i "$SSH_PRIVATE_KEY" \
      -o BatchMode=yes \
      -o IdentitiesOnly=yes \
      -o StrictHostKeyChecking=accept-new \
      -o ConnectTimeout=3 \
      "${DEV_USER}@${IP}" \
      true 2>/dev/null; then
      log_success "SSH is available."
      return 0
    fi
    sleep 2
  done
  error "SSH did not become available within ${SSH_TIMEOUT} seconds."
}

# Argument parsing
while [[ $# -gt 0 ]]; do
  case "$1" in
    --name)
      [[ $# -ge 2 ]] || error "--name requires a value"
      NAME="$2"; shift 2 ;;
    --id)
      [[ $# -ge 2 ]] || error "--id requires a value"
      VMID="$2"; shift 2 ;;
    --ip)
      [[ $# -ge 2 ]] || error "--ip requires a value"
      IP="$2"; shift 2 ;;
    --cores)
      [[ $# -ge 2 ]] || error "--cores requires a value"
      CORES="$2"; shift 2 ;;
    --memory)
      [[ $# -ge 2 ]] || error "--memory requires a value"
      MEMORY="$2"; shift 2 ;;
    --disk)
      [[ $# -ge 2 ]] || error "--disk requires a value"
      DISK="$2"; shift 2 ;;
    --ssh-public-key)
      [[ $# -ge 2 ]] || error "--ssh-public-key requires a value"
      DEVELOPER_SSH_PUBLIC_KEY="$2"; shift 2 ;;
    --rocky-image)
      [[ $# -ge 2 ]] || error "--rocky-image requires a value"
      ROCKY_IMAGE="$2"; shift 2 ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      echo "Error: unknown option: $1" >&2; usage >&2; exit 1 ;;
  esac
done

# Interactive prompts if not provided
if [[ $# -eq 0 ]]; then
  log_info "No arguments provided, running in interactive mode..."
  echo
fi

prompt_if_empty "NAME" "VM name"
prompt_if_empty "VMID" "VM ID"
prompt_if_empty "IP" "VM static IP"
prompt_ssh_key_if_empty

# Allow interactive override of optional values
if [[ $# -eq 0 ]] && [[ -t 0 ]]; then
  read -r -p "CPU cores [$CORES]: " cores_resp; cores_resp="${cores_resp:-$CORES}"; CORES="$cores_resp"
  read -r -p "Memory [$MEMORY]: " memory_resp; memory_resp="${memory_resp:-$MEMORY}"; MEMORY="$memory_resp"
  read -r -p "Disk [$DISK]: " disk_resp; disk_resp="${disk_resp:-$DISK}"; DISK="$disk_resp"
  read -r -p "Rocky image path [$ROCKY_IMAGE]: " rocky_resp; rocky_resp="${rocky_resp:-$ROCKY_IMAGE}"; ROCKY_IMAGE="$rocky_resp"
fi

# Validation
validate_vmid_available
validate_ip "$IP"
validate_ip_not_configured "$IP"
validate_rocky_image
validate_cores
validate_disk
validate_ssh_key
validate_developer_ssh_key

prepare_ssh_keys
MEMORY_MIB=$(memory_to_mib "$MEMORY")

# Config display
echo
log_info "Development VM configuration:"
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

# Provision
create_vm
configure_disk
configure_cloud_init
remove_stale_ssh_host_key
log_info "Starting VM..."
qm start "$VMID"
log_success "VM $VMID started."
wait_for_ssh

# Summary
echo
log_success "Development VM ready:"
echo "  VM ID : $VMID"
echo "  Name  : $NAME"
echo "  IP    : $IP"
echo "  SSH   : ${DEV_USER}@${IP}"
echo
