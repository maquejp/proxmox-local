# Proxmox Development Environment

Scripts and configuration for provisioning development virtual machines on
a personal Proxmox VE server.

The goal is to provide a simple, reproducible and maintainable way to create
isolated development environments for different projects.

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
