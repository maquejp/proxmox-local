#!/usr/bin/env bash

set -euo pipefail

LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd)"
source "${LIB_DIR}/config.sh"
source "${LIB_DIR}/common.sh"
source "${LIB_DIR}/vm.sh"

DEV_USER="${DEV_USER}"
SSH_PRIVATE_KEY="${SSH_PRIVATE_KEY_ADMIN}"
SSH_PUBLIC_KEY="${SSH_PUBLIC_KEY_ADMIN}"
EZA_VERSION="${EZA_VERSION}"

VMID=""

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
  run_remote bash -s -- "$EZA_VERSION" <<'REMOTE'
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

configure_aliases() {
  log_info "Configuring Bash aliases..."
  run_remote bash -s <<'REMOTE'
set -euo pipefail
CONFIG_DIR="$HOME/.config/bash"
ALIASES_FILE="$CONFIG_DIR/aliases"
BASHRC="$HOME/.bashrc"
mkdir -p "$CONFIG_DIR"
cat > "$ALIASES_FILE" <<'EOF'
# Directory listing
alias l='eza -lh --icons'
alias ls='eza --icons'
alias ll='eza -lh --icons --git'
alias la='eza -lah --icons --git'
alias tree='eza --tree --icons'

# Git
alias g='git'
alias ga='git add'
alias gaa='git add .'
alias gau='git add -u'
alias gb='git branch'
alias gbd='git branch -d'
alias gbD='git branch -D'
alias gc='git commit'
alias gcm='git commit -m'
alias gca='git commit --amend'
alias gcan='git commit --amend --no-edit'
alias gco='git checkout'
alias gcob='git checkout -b'
alias gd='git diff'
alias gdm='git diff main'
alias gds='git diff --staged'
alias gf='git fetch'
alias gfp='git fetch && git pull'
alias gl='git log --oneline -10'
alias glg='git log --all --graph --oneline --decorate'
alias gm='git merge'
alias gmm='git merge main'
alias gp='git pull'
alias gps='git push'
alias gpsu='git push -u origin HEAD'
alias grb='git rebase'
alias grbm='git rebase main'
alias gr='git restore'
alias grs='git restore --staged'
alias gs='git status'
alias gst='git stash'
alias gstp='git stash pop'
alias gstl='git stash list'

# Navigation
alias ..='cd ..'
alias ...='cd ../../'
alias ....='cd ../../..'
alias cd-='cd -'

# Common utilities
alias c='clear'
alias du='du -sh'
alias df='df -h'
alias path='echo $PATH | tr ":" "\n"'
alias hist='history | grep'
alias serve='python3 -m http.server'
alias venv='python3 -m venv venv && source venv/bin/activate'
alias py='python3'
alias bcat='bat'

# Networking
alias myip='curl ifconfig.me'
alias ports='ss -tulpn'
alias pingg='ping google.com'

# Node / npm
alias npm-global='npm list -g --depth=0'
alias ni='npm install'
alias nid='npm install --save-dev'
alias nis='npm install --save'
alias nun='npm uninstall'
alias nci='npm ci'
alias npub='npm publish'
alias nls='npm list --depth=0'
alias nr='npm run'
alias nrb='npm run build'
alias nrs='npm run start'
alias ns='npm start'
alias nt='npm test'
alias nv='node -v && npm -v'
alias initnode='npm init -y'
alias cleannode='rm -rf node_modules package-lock.json'
alias upnode='npm update'
alias servejs='npx serve'
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

# Argument parsing
while [[ $# -gt 0 ]]; do
  case "$1" in
    --vm)
      [[ $# -ge 2 ]] || error "--vm requires a value"
      VMID="$2"; shift 2 ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      echo "Error: unknown option: $1" >&2; usage >&2; exit 1 ;;
  esac
done

# Validation
[[ -n "$VMID" ]] || error "--vm is required"
validate_vmid
validate_ssh_key

VM_IP=$(get_vm_ip)
validate_vm_running
validate_ssh

# Setup
echo
log_info "Developer shell setup target:"
echo "  VM ID   : $VMID"
echo "  VM IP   : $VM_IP"
echo "  User    : $DEV_USER"
echo "  SSH key : $SSH_PRIVATE_KEY"
echo

install_system_packages
install_eza
install_starship
configure_path
configure_aliases
configure_starship

# Summary
echo
log_success "Developer shell setup complete:"
echo "  VM ID   : $VMID"
echo "  VM IP   : $VM_IP"
echo "  User    : $DEV_USER"
echo "  eza     : v${EZA_VERSION}"
echo "  bat     : installed"
echo "  rg      : installed"
echo "  Starship: installed"
echo
log_info "Reconnect to the VM to load the new shell configuration."
