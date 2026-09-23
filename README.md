# Proxmox Development VM Runbook

> Reproducible setup for isolated development VMs on the Minisforum UM890 Pro.

## Table of Contents

- [1. Purpose](#1-purpose)
- [2. Infrastructure](#2-infrastructure)
  - [2.1 Hardware](#21-hardware)
  - [2.2 Proxmox](#22-proxmox)
- [3. Network](#3-network)
  - [3.1 Address Convention](#31-address-convention)
- [4. Proxmox Networking](#4-proxmox-networking)
- [5. Standard VM Operating System](#5-standard-vm-operating-system)
  - [5.1 Template](#51-template)
- [6. Template Preparation](#6-template-preparation)
- [7. VM Creation](#7-vm-creation)
  - [7.1 Current Creation Script](#71-current-creation-script)
  - [7.2 Usage](#72-usage)
- [8. SSH Architecture](#8-ssh-architecture)
  - [8.1 Mac → VM](#81-mac--vm)
  - [8.2 Proxmox → VM](#82-proxmox--vm)
  - [8.3 VM → GitHub](#83-vm--github)
- [9. Project Setup](#9-project-setup)
  - [9.1 Setup Script](#91-setup-script)
  - [9.2 Cleanup Script](#92-cleanup-script)
- [10. Git Configuration](#10-git-configuration)
- [11. Vite Development Server](#11-vite-development-server)
- [12. Firewall](#12-firewall)
- [13. VS Code Remote SSH](#13-vs-code-remote-ssh)
- [14. Current Development VMs](#14-current-development-vms)
  - [14.1 atlantis](#141-atlantis)
  - [14.2 lebistro](#142-lebistro)
  - [14.3 jean-philippe](#143-jean-philippe)
- [15. New Project Checklist](#15-new-project-checklist)
- [16. Troubleshooting](#16-troubleshooting)
  - [16.1 Vite works inside the VM but not from the Mac](#161-vite-works-inside-the-vm-but-not-from-the-mac)
  - [16.2 GitHub reports Permission denied](#162-github-reports-permission-denied)
  - [16.3 SSH warning after recreating a VM](#163-ssh-warning-after-recreating-a-vm)
  - [16.4 xterm-ghostty terminal error](#164-xterm-ghostty-terminal-error)
- [17. Operating Principles](#17-operating-principles)
- [18. Quick Reference](#18-quick-reference)

---

## 1. Purpose

This runbook documents the standard setup used to create and maintain isolated development VMs on the Minisforum UM890 Pro running Proxmox VE.

The goal is to provide a simple, reproducible development environment while keeping each project isolated.

### Core principle

> **1 VM = 1 project**

Each development VM contains the tools and dependencies required by one project.

Project source code remains managed through Git/GitHub.

Proxmox is used as the infrastructure layer for:

- VM lifecycle
- CPU and RAM allocation
- storage
- networking
- templates
- snapshots
- backups

Application deployment remains independent of Proxmox.

---

## 2. Infrastructure

### 2.1 Hardware

**Minisforum UM890 Pro**

- AMD Ryzen 9 PRO 8945HS
- 8 cores / 16 threads
- 64 GB RAM
- ~1 TB NVMe
- AMD Radeon 780M

### 2.2 Proxmox

- Proxmox VE 9.2.x
- Standalone installation
- No cluster
- No Ceph
- No HA

Management address:

```text
192.168.1.128
```

Web interface:

```text
https://192.168.1.128:8006
```

SSH:

```bash
ssh root@192.168.1.128
```

---

## 3. Network

```text
Network: 192.168.1.0/24
Gateway: 192.168.1.1
```

Router DHCP range:

```text
192.168.1.2 – 192.168.1.63
```

TV range:

```text
192.168.1.64 – 192.168.1.127
```

Static infrastructure addresses use the range starting at `192.168.1.128`.

### 3.1 Address Convention

| Address          | Purpose          |
| ---------------- | ---------------- |
| `192.168.1.1`    | Router / gateway |
| `192.168.1.128`  | Proxmox          |
| `192.168.1.129`  | Database VM      |
| `192.168.1.150`  | `atlantis`       |
| `192.168.1.151`  | `lebistro`       |
| `192.168.1.152`  | `jean-philippe`  |
| `192.168.1.153+` | Future projects  |

Static VM addresses are outside the router DHCP pool.

---

## 4. Proxmox Networking

The Proxmox management network uses `nic1` connected to `vmbr0`.

```text
nic1
  │
  ▼
vmbr0
  │
  ├── Proxmox
  └── Development VMs
```

Relevant configuration:

```text
auto lo
iface lo inet loopback

iface nic1 inet manual

auto vmbr0
iface vmbr0 inet static
        address 192.168.1.128/24
        gateway 192.168.1.1
        bridge-ports nic1
        bridge-stp off
        bridge-fd 0

iface nic0 inet manual
iface nic2 inet manual

source /etc/network/interfaces.d/*
```

---

## 5. Standard VM Operating System

All development VMs use:

```text
Rocky Linux 10.2 Minimal
```

### 5.1 Template

Current template:

```text
VM ID: 198
Name:  rocky-dev-template-v2
```

The template contains:

- Rocky Linux 10.2 Minimal
- Cloud-Init
- QEMU Guest Agent
- Git
- Node.js 24
- npm 11
- Python 3
- GCC / G++
- make
- curl
- tar
- gzip
- unzip
- nano
- bash-completion
- eza
- bat
- ripgrep
- Starship

The template is intentionally generic.

Project-specific dependencies are installed after the VM is created.

---

## 6. Template Preparation

Before converting the system into a template:

- machine ID is cleared
- SSH host keys are removed
- shell history is cleared
- NetworkManager is configured for DHCP
- Cloud-Init state is cleaned
- QEMU Guest Agent is enabled

This ensures cloned VMs receive their own identity and network configuration.

The template does not contain project-specific configuration.

---

## 7. VM Creation

The repository contains:

```text
scripts/create-dev-vm.sh
```

The script uses template `198` and creates a full VM clone.

### 7.1 Current Creation Script

```bash
#!/usr/bin/env bash

set -euo pipefail

TEMPLATE_ID=198
GATEWAY="192.168.1.1"
MAC_SSH_KEY="/root/id_ed25519.pub"
VM_ADMIN_SSH_KEY="/root/.ssh/id_ed25519_vm_admin.pub"

VMID="${1:-}"
VM_NAME="${2:-}"
VM_IP="${3:-}"

usage() {
    echo "Usage: $0 <vmid> <name> <ip>"
    echo "Example: $0 150 atlantis 192.168.1.150"
    exit 1
}

[[ -n "$VMID" && -n "$VM_NAME" && -n "$VM_IP" ]] || usage

if ! [[ "$VMID" =~ ^[0-9]+$ ]]; then
    echo "Error: VMID must be numeric."
    exit 1
fi

if qm status "$VMID" &>/dev/null; then
    echo "Error: VMID $VMID already exists."
    exit 1
fi

if ! qm status "$TEMPLATE_ID" &>/dev/null; then
    echo "Error: template $TEMPLATE_ID does not exist."
    exit 1
fi

if [[ ! -f "$MAC_SSH_KEY" ]]; then
    echo "Error: SSH public key not found: $MAC_SSH_KEY"
    exit 1
fi

if [[ ! -f "$VM_ADMIN_SSH_KEY" ]]; then
    echo "Error: SSH public key not found: $VM_ADMIN_SSH_KEY"
    exit 1
fi

if ! [[ "$VM_IP" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
    echo "Error: invalid IPv4 address: $VM_IP"
    exit 1
fi

echo "Creating VM $VMID ($VM_NAME) with IP $VM_IP..."

SSH_KEYS_FILE="$(mktemp)"

cat "$MAC_SSH_KEY" "$VM_ADMIN_SSH_KEY" > "$SSH_KEYS_FILE"

trap 'rm -f "$SSH_KEYS_FILE"' EXIT

qm clone "$TEMPLATE_ID" "$VMID" \
    --name "$VM_NAME" \
    --full 1

qm set "$VMID" \
    --ciuser sysadmin \
    --sshkeys "$SSH_KEYS_FILE" \
    --ipconfig0 "ip=${VM_IP}/24,gw=${GATEWAY}"

qm start "$VMID"

echo
echo "VM created:"
echo "  ID:       $VMID"
echo "  Name:     $VM_NAME"
echo "  IP:       $VM_IP"
echo "  SSH:      ssh sysadmin@$VM_IP"
```

### 7.2 Usage

From the repository root on Proxmox:

```bash
./scripts/create-dev-vm.sh <VMID> <project-name> <IP>
```

Example:

```bash
./scripts/create-dev-vm.sh 153 new-project 192.168.1.153
```

The script:

1. verifies the parameters
2. checks that the VM ID is available
3. verifies that template `198` exists
4. verifies the Mac and Proxmox administration public keys
5. injects both keys through Cloud-Init
6. performs a full clone
7. assigns the static IP
8. starts the VM

---

## 8. SSH Architecture

Three separate SSH relationships are deliberately used:

```text
Mac ───────────────SSH───────────────┐
                                     ▼
Proxmox ────────────SSH──────► Development VM ─── SSH ───► GitHub
```

These connections use **separate SSH keys**.

### 8.1 Mac → VM

The Mac's existing public key is stored on Proxmox:

```text
/root/id_ed25519.pub
```

Cloud-Init injects this public key into the VM.

The private key never leaves the Mac.

Example:

```bash
ssh sysadmin@192.168.1.150
```

SSH password authentication is not required.

### 8.2 Proxmox → VM

The setup script connects from Proxmox to the VM with a separate administration key:

```text
Private key: /root/.ssh/id_ed25519_vm_admin
Public key:  /root/.ssh/id_ed25519_vm_admin.pub
```

The public key is injected into each VM by `create-dev-vm.sh`. It lets `setup-dev-project.sh` configure the VM without using the Mac's private key.

### 8.3 VM → GitHub

Each project VM has its **own dedicated GitHub SSH key**.

In GitHub mode, `setup-dev-project.sh` creates it when needed at `~/.ssh/id_ed25519_github`, displays the public key, then pauses for it to be added to GitHub as an **Authentication Key**. The script tests `ssh -T git@github.com` before cloning.

### Important

Never copy the Mac's private SSH key into a VM.

| Key                       | Location    | Purpose          |
| ------------------------- | ----------- | ---------------- |
| Mac SSH key               | Mac         | Mac → VM         |
| Proxmox administration key| Proxmox     | Proxmox → VM     |
| Project GitHub key        | Project VM  | VM → GitHub      |

---

## 9. Project Setup

Run the project scripts from the repository root on Proxmox:

```bash
cd ~/proxmox-local
```

### 9.1 Setup Script

`setup-dev-project.sh` configures Git for the VM and supports two modes.

For a new local-only project, omit the GitHub repository:

```bash
./scripts/setup-dev-project.sh 153 mon-projet 192.168.1.153
```

It creates `/home/sysadmin/Projects/mon-projet` and initializes an empty Git repository on the `main` branch. It does not create a GitHub SSH key or an initial commit.

For an existing GitHub repository, provide the optional fourth argument:

```bash
./scripts/setup-dev-project.sh 153 mon-projet 192.168.1.153 maquejp/mon-projet
```

This configures the VM's dedicated GitHub SSH key, verifies GitHub authentication, and clones the repository into `/home/sysadmin/Projects/mon-projet`. When a new key is created, add the displayed public key to GitHub before continuing. Private repositories are supported when the key has access.

### 9.2 Cleanup Script

When a development VM is no longer needed, remove it and its Proxmox SSH host keys with:

```bash
./scripts/cleanup-dev-vm.sh 153 mon-projet 192.168.1.153 maquejp/mon-projet
```

The fourth argument is optional. The script stops and purges the VM, then removes its IP address from `/root/.ssh/known_hosts` on Proxmox.

It also reminds you to complete the two manual cleanup steps that cannot safely be automated from Proxmox:

- remove the VM IP from the Mac's `~/.ssh/known_hosts`;
- delete the VM's GitHub SSH key and, if appropriate, its test repository.

---

## 10. Git Configuration

`setup-dev-project.sh` configures the global Git identity in the VM.

Verify:

```bash
git config --global --list
```

Update the script if the Git identity changes.

---

## 11. Vite Development Server

Vite normally listens only on localhost.

For LAN development:

```ts
server: {
  host: '0.0.0.0',
},
```

Example:

```ts
export default defineConfig({
  plugins: [react()],
  server: {
    host: "0.0.0.0",
  },
});
```

Start:

```bash
npm run dev
```

The application is then available from the Mac at:

```text
http://<VM-IP>:5173
```

---

## 12. Firewall

Rocky Linux uses `firewalld`.

Allow Vite:

```bash
sudo firewall-cmd --permanent --add-port=5173/tcp
```

Reload:

```bash
sudo firewall-cmd --reload
```

Verify:

```bash
sudo firewall-cmd --list-ports
```

Expected:

```text
5173/tcp
```

Only required ports should be opened.

---

## 13. VS Code Remote SSH

The Mac's SSH configuration contains aliases such as:

```ssh
Host atlantis
    HostName 192.168.1.150
    User sysadmin

Host lebistro
    HostName 192.168.1.151
    User sysadmin

Host jean-philippe
    HostName 192.168.1.152
    User sysadmin
```

Test:

```bash
ssh atlantis
ssh lebistro
ssh jean-philippe
```

VS Code Remote SSH uses the same configuration.

Project directories:

```text
/home/sysadmin/Projects/atlantis
/home/sysadmin/Projects/lebistro
/home/sysadmin/Projects/jean-philippe
```

VS Code Server is installed automatically on first connection.

---

## 14. Current Development VMs

| VM ID | Name            | IP              | Project                    |
| ----: | --------------- | --------------- | -------------------------- |
| `150` | `atlantis`      | `192.168.1.150` | `~/Projects/atlantis`      |
| `151` | `lebistro`      | `192.168.1.151` | `~/Projects/lebistro`      |
| `152` | `jean-philippe` | `192.168.1.152` | `~/Projects/jean-philippe` |

All three VMs:

- are based on template `198`
- use Rocky Linux 10.2
- use Cloud-Init
- use QEMU Guest Agent
- use SSH key authentication
- have Vite port `5173/tcp` open
- are accessed from the Mac through VS Code Remote SSH

### 14.1 atlantis

```text
VM ID:     150
Hostname:  atlantis
IP:        192.168.1.150
Project:   /home/sysadmin/Projects/atlantis
Vite:      5173/tcp
```

Status: operational.

### 14.2 lebistro

```text
VM ID:     151
Hostname:  lebistro
IP:        192.168.1.151
Project:   /home/sysadmin/Projects/lebistro
Vite:      5173/tcp
```

Status: operational.

### 14.3 jean-philippe

```text
VM ID:     152
Hostname:  jean-philippe
IP:        192.168.1.152
Project:   /home/sysadmin/Projects/jean-philippe
Vite:      5173/tcp
```

Status: operational.

`jean-philippe` was recreated from template `198` so that all three project VMs use the same template v2 foundation.

---

## 15. New Project Checklist

### 1. Create the VM

On Proxmox:

```bash
cd ~/proxmox-local
./scripts/create-dev-vm.sh 153 new-project 192.168.1.153
```

### 2. Set up the project

For a new local project:

```bash
./scripts/setup-dev-project.sh 153 new-project 192.168.1.153
```

For an existing GitHub repository:

```bash
./scripts/setup-dev-project.sh 153 new-project 192.168.1.153 maquejp/new-project
```

### 3. Install dependencies

```bash
ssh sysadmin@192.168.1.153 'cd /home/sysadmin/Projects/new-project && npm ci'
```

### 4. Build the project

```bash
ssh sysadmin@192.168.1.153 'cd /home/sysadmin/Projects/new-project && npm run build'
```

### 5. Configure Vite

For Vite projects:

```ts
server: {
  host: '0.0.0.0',
},
```

### 6. Open the Vite port

```bash
sudo firewall-cmd --permanent --add-port=5173/tcp
sudo firewall-cmd --reload
```

### 7. Configure the Mac

Add the VM to `~/.ssh/config`:

```ssh
Host <project>
    HostName <IP>
    User sysadmin
```

Test:

```bash
ssh <project>
```

### 8. Connect with VS Code

Use:

```text
Remote Explorer → SSH → <project>
```

Open:

```text
/home/sysadmin/Projects/<project>
```

---

## 16. Troubleshooting

### 16.1 Vite works inside the VM but not from the Mac

Check the Vite configuration:

```ts
server: {
  host: '0.0.0.0',
},
```

Then check the firewall:

```bash
sudo firewall-cmd --list-ports
```

Confirm:

```text
5173/tcp
```

Check that Vite is listening:

```bash
ss -lntp | grep 5173
```

Expected:

```text
0.0.0.0:5173
```

Then test from the Mac:

```text
http://<VM-IP>:5173
```

---

### 16.2 GitHub reports `Permission denied (publickey)`

Test:

```bash
ssh -T git@github.com
```

Check the VM's public key:

```bash
cat ~/.ssh/id_ed25519_github.pub
```

Ensure that this exact public key has been added to GitHub.

Check the remote:

```bash
git remote -v
```

For SSH, it should look like:

```text
git@github.com:<owner>/<repository>.git
```

Do not use the Mac's private key inside the VM.

---

### 16.3 SSH warning after recreating a VM

A recreated VM at the same IP has a new SSH host key.

On the Mac:

```bash
ssh-keygen -R <VM-IP>
```

Then reconnect:

```bash
ssh sysadmin@<VM-IP>
```

---

### 16.4 `xterm-ghostty` terminal error

If a terminal program reports:

```text
Error opening terminal: xterm-ghostty
```

Temporary workaround:

```bash
export TERM=xterm-256color
```

If necessary, make this persistent:

```bash
nano ~/.bashrc
```

Add:

```bash
export TERM=xterm-256color
```

Then reload:

```bash
source ~/.bashrc
```

---

## 17. Operating Principles

The environment intentionally avoids unnecessary infrastructure complexity.

### Keep

- One project per VM
- Rocky Linux template
- Cloud-Init
- Static IPs
- SSH key authentication
- Git/GitHub
- VS Code Remote SSH
- Native development tools
- Simple firewall configuration
- Proxmox snapshots when useful
- GitHub as the source of project code

### Avoid unless there is a real requirement

- Kubernetes
- Proxmox clustering
- Ceph
- HA
- unnecessary VLANs
- Terraform
- Ansible for simple configuration
- complex CI/CD infrastructure inside Proxmox

### Responsibility boundaries

```text
Proxmox
  └── VM lifecycle / infrastructure

Development VM
  └── OS / tools / project dependencies

GitHub
  └── source code / Git history

GitHub Actions
  └── automated deployment

Mac
  └── workstation / VS Code / SSH client
```

The objective is a development environment that is:

> **simple → reproducible → isolated → maintainable**

---

## 18. Quick Reference

### Infrastructure

```text
Proxmox
  IP:       192.168.1.128
  Gateway:  192.168.1.1
  Bridge:   vmbr0
  Template: 198 / rocky-dev-template-v2
```

### Database VM

```text
100  databases
     192.168.1.129
```

### Project VMs

```text
150  atlantis
     192.168.1.150

151  lebistro
     192.168.1.151

152  jean-philippe
     192.168.1.152

153+ future projects
```

### Development server

```text
Vite: 5173/tcp
```

### SSH

```text
Mac → VM
    Mac SSH key

Proxmox → VM
    Proxmox administration key

VM → GitHub
    Dedicated project SSH key
```

### Project location

```text
/home/sysadmin/Projects/<project>
```

### Create a new VM

```bash
./scripts/create-dev-vm.sh <VMID> <project> <IP>
```

### Set up a local project

```bash
./scripts/setup-dev-project.sh <VMID> <project> <IP>
```

### Set up a GitHub project

```bash
./scripts/setup-dev-project.sh <VMID> <project> <IP> <github-repo>
```

### Remove a development VM

```bash
./scripts/cleanup-dev-vm.sh <VMID> <project> <IP> [github-repo]
```

### Connect

```bash
ssh sysadmin@<IP>
```

### GitHub test

```bash
ssh -T git@github.com
```

### Build

```bash
npm ci
npm run build
```

### Start Vite

```bash
npm run dev
```

### Access from Mac

```text
http://<VM-IP>:5173
```

---

## Appendix: Current Infrastructure Overview

```text
                         ┌──────────────────────┐
                         │      Proximus        │
                         │      192.168.1.1     │
                         └──────────┬───────────┘
                                    │
                              192.168.1.0/24
                                    │
             ┌──────────────────────┴──────────────────────┐
             │                                             │
             │                                             │
   ┌─────────▼─────────┐                         ┌─────────▼─────────┐
   │      Proxmox       │                         │       Mac         │
   │   192.168.1.128    │◄────── SSH ────────────│    Workstation    │
   │                    │                         │                   │
   │       vmbr0        │                         │   VS Code         │
   └─────────┬─────────┘                         └───────────────────┘
             │
      ┌──────┼───────────────┬───────────────┐
      │      │               │               │
      ▼      ▼               ▼               ▼
   .129    .150            .151            .152
 databases atlantis        lebistro        jean-philippe
```

The infrastructure is intentionally kept small and explicit.

Future additions should follow the same model unless a concrete requirement justifies a different architecture.
