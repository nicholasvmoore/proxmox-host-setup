# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is an Ansible project for automating Proxmox host setup and LXC container provisioning, specifically focused on creating and configuring a Jellyfin media server in an LXC container with hardware acceleration support.

## Key Commands

When running ansible or python always preface the command with `PYENV_VERSION=ansible` to enable the ansible pyenv virtual environment

### Environment Setup

```bash
# Create pyenv
pyenv create ansible 3.13

PYENV_VERSION=ansible pip install -r requirements.txt
PYENV_VERSION=ansible ansible-galaxy collection install -r requirements.yml
```

### Running Playbooks

```bash
# Complete infrastructure setup (all containers)
ansible-playbook -i inventory main.yml --vault-password-file=~/.ssh/proxmox-key.key

# Individual playbooks
ansible-playbook -i inventory proxmox_host_setup.yml --vault-password-file=~/.ssh/proxmox-key.key
ansible-playbook -i inventory jellyfin.yml --vault-password-file=~/.ssh/proxmox-key.key
ansible-playbook -i inventory docker.yml --vault-password-file=~/.ssh/proxmox-key.key
```

### Targeted Execution
```bash
# Target specific hosts
ansible-playbook -i inventory docker.yml --limit docker --vault-password-file=~/.ssh/proxmox-key.key

# Target specific tasks with tags
ansible-playbook -i inventory docker.yml --tags docker_images --vault-password-file=~/.ssh/proxmox-key.key

# Dry run (check mode)
ansible-playbook -i inventory docker.yml --check --vault-password-file=~/.ssh/proxmox-key.key
```

### Linting
```bash
# YAML linting (yamllint config disables line-length rule)
yamllint .

# Markdown linting (excludes CLAUDE.md files via .markdownlintignore)
markdownlint .

# Ansible linting (empty ansible-lint file exists)
ansible-lint

# Syntax check
ansible-playbook -i inventory main.yml --syntax-check
```

## Architecture

### Playbook Structure
- `main.yml`: Entry point that orchestrates all infrastructure setup (Proxmox + Docker + Jellyfin)
- `proxmox_host_setup.yml`: Configures Proxmox host, downloads templates, creates Jellyfin LXC container
- `docker.yml`: Complete Docker container lifecycle (creation + software installation + configuration)
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

#### Docker Container Setup (`docker.yml`)
- Creates Docker LXC container (VMID 201) with:
  - 8 CPU cores, 16GB RAM, 100GB SSD storage (ssd1)
  - Intel GPU hardware acceleration (/dev/dri/card0 and /dev/dri/renderD128)
  - Security nesting enabled for container-in-container support
- Docker CE installation with BuildKit enabled
- Intel media drivers and GPU tools installation
- Pre-pulled Docker images for AI/ML workloads:
  - `intelanalytics/ipex-llm-inference-cpp-xpu:latest`

### Infrastructure Details
- Target hosts: `brix` (for brix.pcola.moorenix.com setup), `jellyfin` (for Jellyfin container), `docker` (for Docker container) `prox0_host` (for prox0.pcola.moorenix.com setup)
- Proxmox API hosts:
  - brix.pcola.moorenix.com
    - api_token_id: automation
    - api_token_secret: brix_api_token_secret
  - prox0.pcola.moorenix.com
    - api_token_id: automation
    - api_token_secret: prox0_api_token_secret
- LXC containers:
  - Jellyfin: hostname `jellyfin`, VMID 200
  - Docker: hostname `docker`, VMID 201
- Public domain: jellyfin.moorenix.com (configurable via `jellyfin_public_domain`)
- Hardware acceleration: Intel GPU with proper device permissions and UID mapping

### Security Configuration
- Ansible Vault used for sensitive variables (vars/proxmox_vars.yml)
- SSL certificates via Let's Encrypt
- Proper file permissions and ownership
- Hardware device access through LXC configuration

### Handler Architecture
- Centralized, reusable handlers in `handlers/` directory
- Handlers use variables for flexibility (e.g., `{{ service_name }}`, `{{ lxc_vmid }}`)
- Generic handlers avoid hardcoded values for maximum reusability
- Use `notify` with appropriate variables to trigger handlers

### Tags Available

#### General
- `proxmox_host_setup`: Host configuration tasks
- `container_templates`: Template download tasks

#### Jellyfin Container
- `jellyfin_container`: All Jellyfin container tasks
- `jellyfin_container_creation`: Jellyfin container creation only
- `jellyfin_container_configuration`: Container config file modification

#### Docker Container
- `docker_container`: Complete Docker setup (creation + configuration)
- `docker_container_creation`: Docker LXC container creation only
- `docker_container_configuration`: Container configuration only
- `docker_software`: Docker CE installation only
- `docker_gpu_config`: Intel GPU support configuration
- `docker_images`: Docker image management
- `docker_server_tooling`: Basic server tools installation

## Important Notes

### Environment & Authentication
- The vault password file must be located at `~/.ssh/proxmox-key.key`
- Use `./setup.sh && source activate.sh` for automated environment setup
- Certificate generation includes hardcoded email (nicholasvmoore@gmail.com)

### Container Management
- Container creation tasks have specific comments about initial vs. update operations
- Hardware acceleration requires complex UID/GID mapping for device access
- Docker container supports nesting for container-in-container scenarios
- SystemD timer has a typo: `cerbot-renew.timer` should be `certbot-renew.timer`

### Development Workflow
- Use `--check` flag for dry runs before applying changes
- Use `--limit <host>` to target specific containers during development
- Use granular tags for faster iteration (e.g., `--tags docker_images`)
- When using handlers, set required variables like `service_name` or `lxc_vmid`
- Example handler usage: `notify: "Restart service"` with `vars: { service_name: "nginx" }`
