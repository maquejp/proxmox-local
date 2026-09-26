# Proxmox Development Environment

Scripts and configuration for provisioning development virtual machines on a personal Proxmox VE server.

The goal is to provide a simple, reproducible and maintainable way to create isolated development environments for different projects.

## Principles

- **Rocky Linux by default**
- Use another OS only when a project has a specific technical requirement
- Provision VMs directly through scripts
- Avoid Proxmox templates unless they become useful later
- Use Cloud-Init for initial VM configuration
- Use SSH keys instead of passwords
- Keep VM provisioning separate from project setup
- Prefer simple and explicit configuration over automation complexity
- Follow KISS, DRY and SOLID principles where applicable

## Architecture

The environment is divided into two main responsibilities:

```text
create-dev-vm.sh
        │
        │  VM provisioning
        ▼
   Rocky Linux VM
        │
        │  Project setup
        ▼
setup-dev-project.sh
```

### VM provisioning

`create-dev-vm.sh` is responsible for creating and configuring a development VM on Proxmox.

It handles infrastructure-level concerns such as:

- VM creation
- CPU and memory
- storage
- network
- Cloud-Init
- SSH access
- base operating system configuration

It should not contain project-specific configuration.

### Project setup

`setup-dev-project.sh` is responsible for preparing a development environment inside an existing VM.

A project may either:

- start from an existing Git repository
- start as a new project

Project-specific tooling and configuration should remain separate from the generic VM provisioning logic.

## Default Operating System

The default operating system is:

**Rocky Linux**

Other distributions may be supported when required by a specific project or technology.

Examples of legitimate reasons to use another OS could include:

- vendor-specific software requirements
- incompatible packages
- tooling that officially targets another distribution
- testing a specific operating system

The default should remain Rocky Linux whenever there is no technical reason to deviate from it.

## Repository Structure

The structure is intentionally kept small.

```text
.
├── README.md
├── create-dev-vm.sh
├── setup-dev-project.sh
└── profiles/
```

The structure may evolve as requirements become clearer.

## Usage

### Create a development VM

```bash
./create-dev-vm.sh \
    --name demo-react-taskmanager \
    --id 201 \
    --cores 6 \
    --memory 16G \
    --disk 60G
```

### Configure a project

```bash
./setup-dev-project.sh \
    --vm 201 \
    --type react-express
```

> The command-line interface is currently a design target and may change during implementation.

## Design Goals

The scripts should make it possible to:

1. Create a clean development VM quickly.
2. Recreate a VM without relying on undocumented manual steps.
3. Keep infrastructure configuration independent from application projects.
4. Make the resulting environment understandable and debuggable.
5. Avoid unnecessary infrastructure tooling.

## Non-Goals

This project is not intended to become a general-purpose infrastructure automation framework.

It does not currently aim to provide:

- multi-node Proxmox management
- high-availability configuration
- cluster orchestration
- complex configuration management
- automatic production deployment
- a large collection of pre-built VM templates

## Status

🚧 Work in progress.

The provisioning workflow and command-line interface are currently being designed.
