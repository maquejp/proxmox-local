#!/usr/bin/env bash

# ==============================================================================
# Shared configuration for Proxmox development VM scripts
# ==============================================================================

# VM lifecycle
DEV_USER="dev"
DEFAULT_PROTECTED_VMIDS=(100)

# SSH configuration
SSH_PRIVATE_KEY_ADMIN="/root/.ssh/id_ed25519_vm_admin"
SSH_PUBLIC_KEY_ADMIN="/root/.ssh/id_ed25519_vm_admin.pub"
SSH_GITHUB_PRIVATE_KEY_TEMPLATE="/home/${DEV_USER}/.ssh/id_ed25519_github"
SSH_GITHUB_PUBLIC_KEY_TEMPLATE="/home/${DEV_USER}/.ssh/id_ed25519_github.pub"
SSH_TIMEOUT=60
SSH_CONNECT_TIMEOUT=5

# Rocky Linux image
ROCKY_IMAGE_DEFAULT="/var/lib/vz/template/qcow2/Rocky-10-GenericCloud-Base-10.2-20260525.0.x86_64.qcow2"

# Shell setup
EZA_VERSION="0.23.5"
STARSHIP_INSTALL_DIR="${HOME:-}/.local/bin"

# Proxmox defaults
PROXMOX_STORAGE="local-lvm"
PROXMOX_BRIDGE="vmbr0"
PROXMOX_GATEWAY="192.168.1.1"
PROXMOX_MACHINE="q35"
PROXMOX_BIOS="seabios"
PROXMOX_CPU="host"
PROXMOX_OS_TYPE="l26"
