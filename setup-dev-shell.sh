#!/usr/bin/env bash

set -euo pipefail

# ==============================================================================
# Proxmox Development VM - Developer Shell Setup
# ==============================================================================

# ------------------------------------------------------------------------------
# Defaults
# ------------------------------------------------------------------------------

DEV_USER="dev"
SSH_PRIVATE_KEY="/root/.ssh/id_ed25519_vm_admin"

EZA_VERSION="0.23.5"

# ------------------------------------------------------------------------------
# Arguments
# ------------------------------------------------------------------------------

VMID=""

# ==============================================================================
# Functions
# ==============================================================================

usage() {
    cat <<EOF
Usage:
  $0 --vm VMID

Required:
  --vm VMID         Proxmox VM ID

Options:
  -h, --help        Show this help

Example:
  $0 --vm 203
EOF
}

error() {
    echo "Error: $*" >&2
    exit 1
}

validate_vmid() {
    if [[ ! "$VMID" =~ ^[0-9]+$ ]]; then
        error "VMID must be numeric: $VMID"
    fi

    if ! qm status "$VMID" &>/dev/null; then
        error "VMID $VMID does not exist"
    fi
}

validate_ssh_key() {
    if [[ ! -f "$SSH_PRIVATE_KEY" ]]; then
        error "SSH private key not found: $SSH_PRIVATE_KEY"
    fi

    if [[ ! -r "$SSH_PRIVATE_KEY" ]]; then
        error "SSH private key is not readable: $SSH_PRIVATE_KEY"
    fi
}

get_vm_ip() {
    local ip

    ip=$(qm config "$VMID" |
        awk -F'ip=' '/^ipconfig0:/ {
            split($2, a, ",")
            print a[1]
        }' |
        cut -d/ -f1)

    if [[ -z "$ip" ]]; then
        error "No static IP configured for VM $VMID"
    fi

    echo "$ip"
}

validate_vm_running() {
    local status

    status=$(qm status "$VMID" | awk '{print $2}')

    if [[ "$status" != "running" ]]; then
        error "VM $VMID is not running"
    fi
}

validate_ssh() {
    echo "Checking SSH connectivity..."

    if ! ssh \
        -i "$SSH_PRIVATE_KEY" \
        -o BatchMode=yes \
        -o StrictHostKeyChecking=accept-new \
        -o ConnectTimeout=5 \
        "${DEV_USER}@${VM_IP}" \
        true; then
        error "SSH connection failed: ${DEV_USER}@${VM_IP}"
    fi

    echo "SSH connectivity OK."
}

run_remote() {
    ssh \
        -i "$SSH_PRIVATE_KEY" \
        -o BatchMode=yes \
        -o StrictHostKeyChecking=accept-new \
        -o ConnectTimeout=5 \
        "${DEV_USER}@${VM_IP}" \
        "$@"
}

install_eza() {
    echo "Installing eza..."

    run_remote bash -s -- "$EZA_VERSION" <<'REMOTE'
set -euo pipefail

EZA_VERSION="$1"
BIN_DIR="$HOME/.local/bin"

mkdir -p "$BIN_DIR"

if [[ -x "$BIN_DIR/eza" ]] &&
   "$BIN_DIR/eza" --version | grep -q "v${EZA_VERSION}"; then
    echo "eza v${EZA_VERSION} already installed."
    exit 0
fi

tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

curl -fsSL \
    "https://github.com/eza-community/eza/releases/download/v${EZA_VERSION}/eza_x86_64-unknown-linux-gnu.tar.gz" \
    -o "$tmp_dir/eza.tar.gz"

tar -xzf "$tmp_dir/eza.tar.gz" -C "$tmp_dir"

install -m 0755 \
    "$tmp_dir/eza_x86_64-unknown-linux-gnu" \
    "$BIN_DIR/eza"

echo "eza v${EZA_VERSION} installed."
REMOTE
}

install_starship() {
    echo "Installing Starship..."

    run_remote bash -s <<'REMOTE'
set -euo pipefail

BIN_DIR="$HOME/.local/bin"

mkdir -p "$BIN_DIR"

if [[ -x "$BIN_DIR/starship" ]]; then
    echo "Starship already installed."
    exit 0
fi

curl -sS https://starship.rs/install.sh |
    sh -s -- -y -b "$BIN_DIR"

echo "Starship installed."
REMOTE
}

configure_path() {
    echo "Configuring PATH..."

    run_remote bash -s <<'REMOTE'
set -euo pipefail

BASHRC="$HOME/.bashrc"
PATH_BLOCK='
# Local user binaries
if [[ -d "$HOME/.local/bin" ]]; then
    export PATH="$HOME/.local/bin:$PATH"
fi
'

if ! grep -Fq '# Local user binaries' "$BASHRC"; then
    printf '%s\n' "$PATH_BLOCK" >> "$BASHRC"
fi
REMOTE
}

configure_aliases() {
    echo "Configuring Bash aliases..."

    run_remote bash -s <<'REMOTE'
set -euo pipefail

CONFIG_DIR="$HOME/.config/bash"
ALIASES_FILE="$CONFIG_DIR/aliases"
BASHRC="$HOME/.bashrc"

mkdir -p "$CONFIG_DIR"

cat > "$ALIASES_FILE" <<'EOF'
# Directory listing
alias l='eza -l  --icons'
alias la='eza -a  --icons'
alias ll='eza -lah  --icons'
EOF

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
    echo "Configuring Starship..."

    run_remote bash -s <<'REMOTE'
set -euo pipefail

CONFIG_DIR="$HOME/.config"
STARSHIP_CONFIG="$CONFIG_DIR/starship.toml"
BASHRC="$HOME/.bashrc"

mkdir -p "$CONFIG_DIR"

if [[ ! -f "$STARSHIP_CONFIG" ]]; then
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
fi

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

# ==============================================================================
# Argument parsing
# ==============================================================================

while [[ $# -gt 0 ]]; do
    case "$1" in
        --vm)
            [[ $# -ge 2 ]] || error "--vm requires a value"
            VMID="$2"
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
# Validation
# ==============================================================================

if [[ -z "$VMID" ]]; then
    error "--vm is required"
fi

validate_vmid
validate_ssh_key

VM_IP=$(get_vm_ip)

validate_vm_running
validate_ssh

# ==============================================================================
# Shell setup
# ==============================================================================

echo
echo "Setting up developer shell..."
echo

install_eza
install_starship
configure_path
configure_aliases
configure_starship

# ==============================================================================
# Summary
# ==============================================================================

echo
echo "Developer shell setup complete:"
echo "  VM ID   : $VMID"
echo "  VM IP   : $VM_IP"
echo "  User    : $DEV_USER"
echo "  eza     : v${EZA_VERSION}"
echo "  Starship: installed"
echo
echo "Reconnect to the VM to load the new shell configuration."