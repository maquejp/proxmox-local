#!/usr/bin/env bash

# ==============================================================================
# Developer shell environment setup functions
# ==============================================================================

LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${LIB_DIR}/config.sh"
source "${LIB_DIR}/common.sh"
source "${LIB_DIR}/vm.sh"

install_system_packages() {
  log_info "Updating Rocky Linux packages..."

  run_remote bash -s <<'REMOTE'
set -euo pipefail
if command -v dnf >/dev/null 2>&1; then
  sudo dnf upgrade -y
else
  echo "Error: dnf not found." >&2
  exit 1
fi
REMOTE

  log_info "Configuring Rocky Linux repositories..."
  run_remote bash -s <<'REMOTE'
set -euo pipefail
sudo dnf config-manager --enable crb
if ! rpm -q epel-release >/dev/null 2>&1; then
  sudo dnf install -y epel-release
fi
REMOTE

  log_info "Installing shell packages..."
  run_remote bash -s <<'REMOTE'
set -euo pipefail
packages=()
command -v git >/dev/null 2>&1 || packages+=(git)
command -v bat >/dev/null 2>&1 || packages+=(bat)
command -v rg >/dev/null 2>&1 || packages+=(ripgrep)
if [[ ${#packages[@]} -gt 0 ]]; then
  sudo dnf install -y "${packages[@]}"
else
  echo "git, bat and ripgrep already installed."
fi
REMOTE
}

install_eza() {
  log_info "Installing eza..."
  run_remote bash -s -- "${EZA_VERSION}" <<'REMOTE'
set -euo pipefail
EZA_VERSION="$1"
BIN_DIR="$HOME/.local/bin"
mkdir -p "$BIN_DIR"
if [[ -x "$BIN_DIR/eza" ]] && "$BIN_DIR/eza" --version | grep -q "v${EZA_VERSION}"; then
  echo "eza v${EZA_VERSION} already installed."
  exit 0
fi
tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT
curl -fsSL --retry 3 --retry-delay 2 \
  "https://github.com/eza-community/eza/releases/download/v${EZA_VERSION}/eza_x86_64-unknown-linux-gnu.tar.gz" \
  -o "$tmp_dir/eza.tar.gz"
tar -xzf "$tmp_dir/eza.tar.gz" -C "$tmp_dir"
install -m 0755 "$tmp_dir/eza" "$BIN_DIR/eza"
"$BIN_DIR/eza" --version | head -1
REMOTE
}

install_starship() {
  log_info "Installing Starship..."
  run_remote bash -s <<'REMOTE'
set -euo pipefail
BIN_DIR="$HOME/.local/bin"
mkdir -p "$BIN_DIR"
if [[ -x "$BIN_DIR/starship" ]]; then
  "$BIN_DIR/starship" --version | head -1
  exit 0
fi
curl -fsSL --retry 3 --retry-delay 2 https://starship.rs/install.sh | sh -s -- -y -b "$BIN_DIR"
"$BIN_DIR/starship" --version | head -1
REMOTE
}

configure_path() {
  log_info "Configuring PATH..."
  run_remote bash -s <<'REMOTE'
set -euo pipefail
BASHRC="$HOME/.bashrc"
python3 - "$BASHRC" <<'PY'
from pathlib import Path
import sys

bashrc = Path(sys.argv[1])
content = bashrc.read_text()
marker = "# Local user binaries"
block = """# Local user binaries

if [[ -d "$HOME/.local/bin" ]]; then
    case ":$PATH:" in
        *":$HOME/.local/bin:"*) ;;
        *) export PATH="$HOME/.local/bin:$PATH" ;;
    esac
fi
"""
aliases_marker = "# Load development aliases"
if marker in content:
    before, rest = content.split(marker, 1)
    if aliases_marker in rest:
        suffix = rest[rest.index(aliases_marker):]
        bashrc.write_text(before + block + "\n" + suffix)
    else:
        bashrc.write_text(before + block + "\n")
else:
    bashrc.write_text(content.rstrip() + "\n\n" + block)
PY
REMOTE
}

configure_term() {
  log_info "Configuring TERM environment variable..."
  run_remote bash -s <<'REMOTE'
set -euo pipefail
BASHRC="$HOME/.bashrc"
if ! grep -Fq 'export TERM=xterm-256color' "$BASHRC"; then
  cat >> "$BASHRC" <<'EOF'

# Set terminal type for compatibility
export TERM=xterm-256color
EOF
fi
REMOTE
}

configure_aliases() {
  log_info "Configuring Bash aliases..."
  local alias_template="${LIB_DIR}/../templates/aliases"

  if [[ ! -f "$alias_template" ]]; then
    error "Alias template file not found: $alias_template"
  fi

  cat "$alias_template" | run_remote bash -s <<'REMOTE'
set -euo pipefail
CONFIG_DIR="$HOME/.config/bash"
ALIASES_FILE="$CONFIG_DIR/aliases"
BASHRC="$HOME/.bashrc"
mkdir -p "$CONFIG_DIR"
cat > "$ALIASES_FILE"
if ! grep -Fq '# Load development aliases' "$BASHRC"; then
  cat >> "$BASHRC" <<'EOF'

# Load development aliases
if [[ -f "$HOME/.config/bash/aliases" ]]; then
  source "$HOME/.config/bash/aliases"
fi
EOF
fi
REMOTE
}

configure_starship() {
  log_info "Configuring Starship..."
  run_remote bash -s <<'REMOTE'
set -euo pipefail
CONFIG_DIR="$HOME/.config"
STARSHIP_CONFIG="$CONFIG_DIR/starship.toml"
BASHRC="$HOME/.bashrc"
mkdir -p "$CONFIG_DIR"
cat > "$STARSHIP_CONFIG" <<'EOF'
"$schema" = 'https://starship.rs/config-schema.json'
add_newline = false
[username]
show_always = true
[hostname]
ssh_only = true
[directory]
truncation_length = 3
[git_branch]
symbol = 'git:'
EOF
if ! grep -Fq '# Initialize Starship' "$BASHRC"; then
  cat >> "$BASHRC" <<'EOF'

# Initialize Starship
if command -v starship >/dev/null 2>&1; then
  eval "$(starship init bash)"
fi
EOF
fi
REMOTE
}

setup_dev_shell() {
  validate_vmid
  validate_ssh_key

  if [[ -z "${VM_IP:-}" ]]; then
    VM_IP=$(get_vm_ip)
  fi
  validate_vm_running
  validate_ssh

  echo
  log_info "Developer shell setup target:"
  echo "  VM ID   : $VMID"
  echo "  VM IP   : $VM_IP"
  echo "  User    : ${DEV_USER}"
  echo "  SSH key : ${SSH_PRIVATE_KEY:-$SSH_PRIVATE_KEY_ADMIN}"
  echo

  install_system_packages
  install_eza
  install_starship
  configure_path
  configure_term
  configure_aliases
  configure_starship

  echo
  log_success "Developer shell setup complete:"
  echo "  VM ID   : $VMID"
  echo "  VM IP   : $VM_IP"
  echo "  User    : ${DEV_USER}"
  echo "  eza     : v${EZA_VERSION}"
  echo "  bat     : installed"
  echo "  rg      : installed"
  echo "  Starship: installed"
  echo "  TERM    : xterm-256color"
  echo
  log_info "Reconnect to the VM to load the new shell configuration."
}
