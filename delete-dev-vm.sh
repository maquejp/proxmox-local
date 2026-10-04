#!/usr/bin/env bash

set -euo pipefail

LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd)"
source "${LIB_DIR}/config.sh"
source "${LIB_DIR}/common.sh"

# VMIDs that must never be deleted by this script.
PROTECTED_VMIDS=("${DEFAULT_PROTECTED_VMIDS[@]}")

# Allow overriding via env var if needed
if [[ -n "${PROTECTED_VMIDS_OVERRIDE:-}" ]]; then
  read -r -a PROTECTED_VMIDS <<< "$PROTECTED_VMIDS_OVERRIDE"
fi

FORCE=false
DRY_RUN=false
SHUTDOWN_TIMEOUT=60

error_exit() {
  log_error "$*"
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
  $0                        Interactive VM selection
  $0 <vmid>                Delete the specified VM
  $0 [--force] [--yes]     Non-interactive flags
  $0 --dry-run [vmid]      Preview actions without executing

Options:
  -f, --force              Force stop if graceful shutdown times out
  -y, --yes                Skip confirmation prompt
  --dry-run                Show what would be done
  --shutdown-timeout N     Graceful shutdown timeout in seconds (default: ${SHUTDOWN_TIMEOUT})
  -h, --help               Show this help

Examples:
  $0
  $0 201
  $0 201 --yes
  $0 --dry-run 201
EOF
  exit 1
}

select_vm() {
  local vmid
  echo "Available VMs:" >&2
  echo >&2
  printf "  %-6s %-30s %-10s %s\n" "ID" "NAME" "STATUS" "PROTECTION" >&2
  printf "  %-6s %-30s %-10s %s\n" "------" "------------------------------" "----------" "----------" >&2
  while read -r vmid name status; do
    if is_protected "$vmid"; then
      printf "  %-6s %-30s %-10s %s\n" "$vmid" "$name" "$status" "protected" >&2
    else
      printf "  %-6s %-30s %-10s\n" "$vmid" "$name" "$status" >&2
    fi
  done < <(
    qm list | awk 'NR > 1 {
      vmid=$1; status=$3
      name=""; for (i=4; i<=NF; i++) { name = name (name ? " " : "") $i }
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

# Argument parsing
VMID=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -f|--force)
      FORCE=true; shift ;;
    -y|--yes)
      NON_INTERACTIVE=true; shift ;;
    --dry-run)
      DRY_RUN=true; shift ;;
    --shutdown-timeout)
      [[ $# -ge 2 ]] || error_exit "--shutdown-timeout requires a value"
      SHUTDOWN_TIMEOUT="$2"; shift 2 ;;
    -h|--help)
      usage ;;
    *)
      if [[ -z "$VMID" && "$1" =~ ^[0-9]+$ ]]; then
        VMID="$1"; shift
      else
        error_exit "Unknown option: $1"
      fi ;;
  esac
done

if [[ -z "$VMID" ]]; then
  VMID="$(select_vm)"
fi

# Validate
[[ "$VMID" =~ ^[0-9]+$ ]] || error_exit "VMID must be a number."
(( VMID >= 100 )) || error_exit "VMID must be >= 100."
is_protected "$VMID" && error_exit "VMID $VMID is protected and cannot be deleted."

if ! qm status "$VMID" >/dev/null 2>&1; then
  error_exit "VM $VMID does not exist."
fi

VM_NAME="$(qm config "$VMID" | awk '/^name:/ {print $2}')"
VM_NAME="${VM_NAME:-unknown}"
VM_STATUS="$(qm status "$VMID" | awk '{print $2}')"

# Display
echo
echo "VM selected:"
echo
echo "  ID:      $VMID"
echo "  Name:    $VM_NAME"
echo "  Status:  $VM_STATUS"
echo
log_warn "This will permanently delete the VM and its disks."
echo

if [[ "$DRY_RUN" == true ]]; then
  log_info "Dry run - would delete VM $VMID ($VM_NAME)"
  exit 0
fi

if ! is_non_interactive && ! confirm "Delete VM $VMID ($VM_NAME)?" "n"; then
  echo "Cancelled."
  exit 0
fi

# Stop if running
if [[ "$VM_STATUS" == "running" ]]; then
  echo
  log_info "Stopping VM $VMID..."
  if qm shutdown "$VMID" >/dev/null 2>&1; then
    log_info "Waiting for VM $VMID to stop..."
    for ((i = 1; i <= SHUTDOWN_TIMEOUT; i++)); do
      if [[ "$(qm status "$VMID" | awk '{print $2}')" == "stopped" ]]; then
        break
      fi
      sleep 1
    done
    if [[ "$(qm status "$VMID" | awk '{print $2}')" != "stopped" ]]; then
      if [[ "$FORCE" == true ]]; then
        log_warn "Graceful shutdown timed out, forcing stop..."
        qm stop "$VMID" >/dev/null 2>&1 || true
      else
        error_exit "VM $VMID did not stop within ${SHUTDOWN_TIMEOUT} seconds. Use --force to stop it."
      fi
    fi
  else
    if [[ "$FORCE" == true ]]; then
      qm stop "$VMID" >/dev/null 2>&1 || true
    else
      error_exit "Failed to shutdown VM $VMID"
    fi
  fi
fi

# Destroy
log_info "Destroying VM $VMID..."
qm destroy "$VMID" --purge >/dev/null 2>&1 || qm destroy "$VMID" --purge

# Verify
if qm status "$VMID" >/dev/null 2>&1; then
  error_exit "VM $VMID still exists after deletion."
fi

echo
log_success "VM $VMID ($VM_NAME) has been completely deleted."
