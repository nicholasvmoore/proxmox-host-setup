# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is an Ansible project for automating Proxmox host setup and LXC container provisioning, specifically focused on creating and configuring a Jellyfin media server in an LXC container with hardware acceleration support.

## Key Commands

### Running Playbooks
```bash
# Main playbook execution (requires vault password file)
ansible-playbook -i inventory main.yml --vault-password-file=~/.ssh/ansible_key.key

# Run specific playbooks
ansible-playbook -i inventory proxmox_host_setup.yml --vault-password-file=~/.ssh/ansible_key.key
ansible-playbook -i inventory jellyfin.yml --vault-password-file=~/.ssh/ansible_key.key
```

### Linting
```bash
# YAML linting (yamllint config disables line-length rule)
yamllint .

# Ansible linting (empty ansible-lint file exists)
ansible-lint
```

## Architecture

### Playbook Structure
- `main.yml`: Entry point that orchestrates both host setup and Jellyfin installation
- `proxmox_host_setup.yml`: Configures Proxmox host, downloads templates, creates LXC container
- `jellyfin.yml`: Installs and configures Jellyfin inside the LXC container

### Key Components

#### Proxmox Host Setup (`proxmox_host_setup.yml`)
- Installs Proxmox API dependencies (python3-proxmoxer, python3-requests, python3-paramiko)
- Downloads Ubuntu 24.04 LTS container template
- Creates Jellyfin LXC container (VMID 200) with:
  - 4 CPU cores, 4GB RAM, 100GB SSD storage
  - DHCP networking on vmbr0
  - Hardware passthrough for Intel GPU (/dev/dri/renderD128)
  - Media directory mount from host (/lun0/media)
  - Complex UID/GID mapping for hardware access

#### Jellyfin Setup (`jellyfin.yml`)
- Server tooling installation (tasks/server_tooling.yml)
- Jellyfin installation with hardware acceleration drivers
- Nginx reverse proxy setup
- Certbot SSL certificate management with auto-renewal
- SystemD service configuration

### Infrastructure Details
- Target hosts: `proxmox_hosts` (for host setup), `jellyfin` (for container setup)
- Proxmox API host: brix.pcola.moorenix.com
- LXC container hostname: jellyfin
- Public domain: jellyfin.moorenix.com (configurable via `jellyfin_public_domain`)
- Hardware acceleration: Intel GPU with proper device permissions and UID mapping

### Security Configuration
- Ansible Vault used for sensitive variables (vars/proxmox_vars.yml)
- SSL certificates via Let's Encrypt
- Proper file permissions and ownership
- Hardware device access through LXC configuration

### Tags Available
- `proxmox_host_setup`: Host configuration tasks
- `container_templates`: Template download tasks
- `jellyfin_container_creation`: Container creation
- `jellyfin_container_configuration`: Container config file modification
- `jellyfin_container`: All container-related tasks

## Important Notes

- The vault password file must be located at `~/.ssh/ansible_key.key`
- Container creation tasks have specific comments about initial vs. update operations
- Hardware acceleration requires complex UID/GID mapping for device access
- SystemD timer has a typo: `cerbot-renew.timer` should be `certbot-renew.timer`
- Certificate generation includes hardcoded email (nicholasvmoore@gmail.com)