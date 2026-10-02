# Proxmox Development Environment

Scripts and configuration for provisioning development virtual machines on a personal Proxmox VE server.

The goal is to provide a simple, reproducible and maintainable way to create isolated development environments for different projects.

## Principles

- **Rocky Linux by default**
- Use another OS only when a project has a specific technical requirement
- Provision VMs directly through scripts
- Use Cloud-Init for initial VM configuration
- Use SSH keys instead of passwords
- Use static IP addresses for predictable VM access
- Keep VM provisioning separate from project setup
- Avoid Proxmox templates unless they become useful later
- Prefer simple and explicit configuration over automation complexity
- Follow KISS, DRY and SOLID principles where applicable

## Architecture

The environment is divided into separate responsibilities:

    create-dev-vm.sh
            |
            | VM provisioning
            v
       Rocky Linux VM
            |
            +-----------------------+
            |                       |
            v                       v
    setup-dev-shell.sh      setup-dev-project.sh
            |                       |
            | Base developer        | Project-specific
            | shell environment     | environment
            v                       v
       Developer tools        Application stack

### VM provisioning

`create-dev-vm.sh` is responsible for creating and configuring a development VM on Proxmox.

It handles infrastructure-level concerns such as:

- VM creation
- CPU and memory allocation
- VM disk
- network configuration
- static IP configuration
- Cloud-Init
- SSH access
- QEMU Guest Agent
- base operating system configuration
- automatic VM startup

It should not contain project-specific configuration.

### Developer shell setup

`setup-dev-shell.sh` is responsible for configuring the common developer shell environment inside an existing development VM.

It currently handles:

- Rocky Linux package updates
- CRB repository configuration
- EPEL configuration
- Git installation
- `bat`
- `ripgrep`
- `eza`
- Starship
- user-local `PATH`
- Bash aliases
- Starship configuration

The shell setup is intentionally independent from project-specific tooling.

### Project setup

`setup-dev-project.sh` is responsible for preparing a development environment inside an existing VM.

A project may either:

- start from an existing Git repository
- start as a new project

The script must therefore **not assume that a Git repository already exists**.

Project-specific tooling and configuration should remain separate from the generic VM provisioning logic.

## Default Operating System

The default operating system is:

**Rocky Linux**

Development VMs use the Rocky Linux GenericCloud image together with Cloud-Init.

The Rocky image is used as the source disk and imported into the Proxmox VM storage when creating a VM.

Other distributions may be supported when required by a specific project or technology.

Examples of legitimate reasons to use another OS could include:

- vendor-specific software requirements
- incompatible packages
- tooling that officially targets another distribution
- testing a specific operating system

The default should remain Rocky Linux whenever there is no technical reason to deviate from it.

## VM Configuration

The current default development VM configuration is:

| Setting | Default |
|---|---|
| Operating system | Rocky Linux |
| CPU | 6 cores |
| Memory | 16 GB |
| Disk | 60 GB |
| Storage | `local-lvm` |
| Network bridge | `vmbr0` |
| Network | VirtIO |
| IP configuration | Static IPv4 |
| Gateway | `192.168.1.1` |
| Machine type | `q35` |
| BIOS | SeaBIOS |
| CPU type | `host` |
| Cloud-Init | Enabled |
| QEMU Guest Agent | Enabled |
| SSH authentication | SSH public key |
| VM startup | Automatic |

The defaults can be overridden when creating a VM.

## VM Naming and Addressing

VM IDs and IP addresses are explicitly selected when creating a VM.

For example:

    VM ID    IP address

    201      192.168.1.201
    202      192.168.1.202
    203      192.168.1.203
    204      192.168.1.204
    205      192.168.1.205

The provisioning script validates that:

- the VM ID is valid and available
- the IP address is valid
- the IP address is not already configured on another VM

The script does not automatically allocate VM IDs or IP addresses.

This keeps the infrastructure predictable and easy to understand.

## SSH Access

Development VMs use SSH key authentication.

The Proxmox host stores the SSH key pair used to access the development VMs:

    /root/.ssh/id_ed25519_vm_admin
    /root/.ssh/id_ed25519_vm_admin.pub

The public key is injected into the VM through Cloud-Init.

The private key remains on the Proxmox host and is used by administration scripts such as `setup-dev-shell.sh`.

The default Cloud-Init user is:

    dev

Example manual connection:

    ssh \
        -i /root/.ssh/id_ed25519_vm_admin \
        dev@192.168.1.205

## Repository Structure

The structure is intentionally kept small.

    .
    ├── README.md
    ├── create-dev-vm.sh
    ├── setup-dev-shell.sh
    ├── setup-dev-project.sh
    └── profiles/

The structure may evolve as requirements become clearer.

## Usage

### Create a development VM

The minimum required parameters are:

- VM name
- VM ID
- static IP address

Example:

    ./create-dev-vm.sh \
        --name taskmanager \
        --id 201 \
        --ip 192.168.1.201

This creates a VM using the default configuration:

    CPU:      6 cores
    Memory:   16 GB
    Disk:     60 GB
    IP:       192.168.1.201

The VM is automatically started after provisioning.

Defaults can be overridden:

    ./create-dev-vm.sh \
        --name big-project \
        --id 202 \
        --ip 192.168.1.202 \
        --cores 8 \
        --memory 24G \
        --disk 100G

### Configure the developer shell

After the VM has been created and started, the common developer shell environment can be configured with:

    ./setup-dev-shell.sh --vm 201

The script connects to the VM through SSH and configures the `dev` user's shell environment.

It installs and configures:

- Git
- `bat`
- `ripgrep`
- `eza`
- Starship
- Bash aliases
- local user `PATH`

The script is designed to be idempotent where practical. Running it again should not create duplicate shell configuration entries or reinstall components unnecessarily.

After the setup completes, reconnect to the VM:

    ssh \
        -i /root/.ssh/id_ed25519_vm_admin \
        dev@192.168.1.201

### Configure a project

The project setup script will prepare a development environment inside an existing VM.

The intended workflow is:

    ./setup-dev-project.sh \
        --vm 201 \
        --type react-express

A project may be initialized from an existing repository or created as a new project.

The exact command-line interface is still being implemented.

## Development Workflow

The intended workflow is:

    1. Create VM
           |
           v
    2. Rocky Linux + Cloud-Init
           |
           v
    3. VM starts automatically
           |
           v
    4. Configure developer shell
           |
           v
    5. SSH into VM
           |
           v
    6. Setup project
           |
           v
    7. Clone or create project
           |
           v
    8. Develop

Development VMs are intended to be disposable.

If a VM becomes unusable, it should be possible to recreate it rather than relying on undocumented manual configuration.

## Design Goals

The scripts should make it possible to:

1. Create a clean development VM quickly.
2. Recreate a VM without relying on undocumented manual steps.
3. Keep infrastructure configuration independent from application projects.
4. Make the resulting environment understandable and debuggable.
5. Use predictable VM IDs and IP addresses.
6. Keep the provisioning process simple.
7. Avoid unnecessary infrastructure tooling.
8. Provide a consistent base developer shell across development VMs.

## Non-Goals

This project is not intended to become a general-purpose infrastructure automation framework.

It does not currently aim to provide:

- multi-node Proxmox management
- high-availability configuration
- cluster orchestration
- complex configuration management
- automatic production deployment
- a large collection of pre-built VM templates
- automatic project-specific infrastructure provisioning

## Current Status

🚧 **Work in progress**

The following has been validated:

- Rocky Linux GenericCloud image
- Cloud-Init configuration
- static IP configuration
- SSH key authentication
- QEMU Guest Agent
- VM networking
- DNS and Internet connectivity
- VM ID validation
- IP address validation
- configurable CPU, memory and disk defaults
- automated Rocky Linux disk import
- automated disk configuration
- automated Cloud-Init configuration
- automated SSH key configuration
- automated static network configuration
- automated QEMU Guest Agent configuration
- automated VM startup
- automated VM provisioning
- developer shell provisioning
- Git installation
- `bat` installation
- `ripgrep` installation
- `eza` installation
- Starship installation
- Bash alias configuration
- user-local `PATH` configuration

### VM provisioning validation

`create-dev-vm.sh` has been validated by creating development VMs end-to-end.

The resulting VM has been verified for:

- correct Proxmox configuration
- correct disk and storage configuration
- Cloud-Init user configuration
- Cloud-Init network configuration
- static IP connectivity
- SSH access using the configured public key
- QEMU Guest Agent availability
- automatic VM startup

The current provisioning workflow is:

1. Validate VM parameters
2. Validate the Rocky Linux GenericCloud image
3. Create the Proxmox VM
4. Import the Rocky Linux GenericCloud image
5. Configure the VM disk
6. Configure Cloud-Init
7. Configure SSH key authentication
8. Configure the static network
9. Enable QEMU Guest Agent
10. Start the VM

### Developer shell validation

`setup-dev-shell.sh` has been validated against a freshly provisioned Rocky Linux development VM.

The resulting shell environment has been verified for:

- Git availability
- `bat`
- `ripgrep`
- `eza`
- Starship
- user-local executable `PATH`
- Bash aliases
- Git aliases
- Node/npm aliases
- Starship prompt configuration

The shell setup downloads user-level tools such as `eza` and Starship **inside the development VM**, not on the Proxmox host.

For example, the `eza` binary is installed under:

    ~/.local/bin/eza

on the development VM.

The Proxmox host only executes the SSH-based provisioning commands.

### Project setup

The next major step is to implement `setup-dev-project.sh`.

This script will prepare a development environment inside an existing VM and must support both:

- existing Git repositories
- new projects that do not yet have a Git repository

The project setup workflow will remain separate from VM provisioning and generic developer shell configuration.
