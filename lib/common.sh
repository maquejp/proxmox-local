#!/usr/bin/env bash

# ==============================================================================
# Common utilities and logging
# ==============================================================================

# Color codes (if terminal supports)
if [[ -t 1 ]]; then
  COLOR_RESET="\033[0m"
  COLOR_RED="\033[0;31m"
  COLOR_YELLOW="\033[0;33m"
  COLOR_GREEN="\033[0;32m"
  COLOR_CYAN="\033[0;36m"
else
  COLOR_RESET=""
  COLOR_RED=""
  COLOR_YELLOW=""
  COLOR_GREEN=""
  COLOR_CYAN=""
fi

log_info() {
  echo -e "${COLOR_CYAN}ℹ ${COLOR_RESET}$*"
}

log_success() {
  echo -e "${COLOR_GREEN}✓ ${COLOR_RESET}$*"
}

log_warn() {
  echo -e "${COLOR_YELLOW}⚠ ${COLOR_RESET}$*"
}

log_error() {
  echo -e "${COLOR_RED}✗ ${COLOR_RESET}$*" >&2
}

error() {
  log_error "$*"
  exit 1
}

# Prompt for confirmation (returns 0 if yes)
confirm() {
  local prompt="$1"
  local default="${2:-n}"
  local response

  if [[ ! -t 0 ]]; then
    if [[ "$default" =~ ^[Yy]$ ]]; then
      return 0
    fi
    return 1
  fi

  while true; do
    read -r -p "${prompt} [${default^^}/${default,,}]: " response
    response="${response:-$default}"

    case "$response" in
      [Yy]*) return 0 ;;
      [Nn]*) return 1 ;;
      *) echo "Please answer yes/no." >&2 ;;
    esac
  done
}

# Check if running in non-interactive environment
is_non_interactive() {
  [[ ! -t 0 ]] || [[ -n "${NON_INTERACTIVE:-}" ]]
}

# Cleanup trap helper
cleanup_traps=()
add_cleanup() {
  cleanup_traps+=("$1")
}

run_cleanups() {
  for ((i = ${#cleanup_traps[@]} - 1; i >= 0; i--)); do
    eval "${cleanup_traps[i]}" || true
  done
  cleanup_traps=()
}

trap 'run_cleanups' EXIT INT TERM
