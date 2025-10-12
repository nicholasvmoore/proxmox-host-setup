# Proxmox Host Setup

Ansible playbooks for automated setup and configuration of Proxmox VE hosts
and LXC containers.

## Overview

This project creates and configures the following infrastructure:

### LXC Containers Created

#### Jellyfin Media Server (VMID: 200)

- **Purpose**: Media streaming and transcoding server
- **Resources**: 4 vCPU, 4GB RAM, 100GB disk (ssd0)
- **Features**:
  - Intel GPU hardware acceleration (/dev/dri/renderD128)
  - Media directory mount from host (/lun0/media)
  - Nginx reverse proxy with SSL/TLS certificates
  - Automatic certificate renewal via Certbot
- **Network**: DHCP on vmbr0
- **Template**: Ubuntu 24.04 LTS

#### Docker Host (VMID: 201)

- **Purpose**: Docker containerization platform
- **Resources**: 8 vCPU, 16GB RAM, 100GB disk (ssd1)
- **Features**:
  - Intel GPU hardware acceleration (/dev/dri/card0 and /dev/dri/renderD128)
  - Docker CE with BuildKit enabled
  - Security nesting enabled for container-in-container support
  - Intel media drivers and GPU tools
  - Pre-pulled Docker images for AI/ML workloads
- **Network**: DHCP on vmbr0
- **Template**: Ubuntu 24.04 LTS
- **Pre-installed Images**:
  - `intelanalytics/ipex-llm-inference-cpp-xpu:latest` - Intel AI inference
    engine

## How to Use

### Prerequisites

#### System Requirements

- Python 3.12 with pyenv
- Git
- Access to a Proxmox VE host

#### Environment Setup

```bash
# Clone the repository
git clone <repository-url>
cd proxmox-host-setup

# Run the automated setup script (recommended)
./setup.sh

# Or manually activate pyenv virtual environment
pyenv activate ansible
pip install -r requirements.txt
ansible-galaxy collection install -r requirements.yml
```

2. **Create the ansible vault key** to decrypt encrypted variables:

   ```bash
   # Place your vault password in a secure file
   echo "your_vault_password" > ~/.ssh/ansible_key.key
   chmod 600 ~/.ssh/ansible_key.key
   ```

3. **Configure your inventory**: Update the `inventory` file with your
   Proxmox host details.

### Running Playbooks

#### Complete Infrastructure Setup

```bash
# Activate pyenv virtual environment
pyenv activate ansible

# Run all setup tasks (host setup + container creation)
ansible-playbook -i inventory main.yml \
  --vault-password-file=~/.ssh/ansible_key.key
```

#### Individual Playbooks

**Proxmox Host Setup (creates LXC containers)**:

```bash
# Activate pyenv virtual environment
pyenv activate ansible

ansible-playbook -i inventory proxmox_host_setup.yml \
  --vault-password-file=~/.ssh/ansible_key.key
```

**Jellyfin Configuration**:

```bash
# Activate pyenv virtual environment
pyenv activate ansible

ansible-playbook -i inventory jellyfin.yml \
  --vault-password-file=~/.ssh/ansible_key.key
```

**Docker Configuration**:

```bash
# Activate pyenv virtual environment
pyenv activate ansible

ansible-playbook -i inventory docker.yml \
  --vault-password-file=~/.ssh/ansible_key.key
```

### Targeting Specific Machines/Tasks

For faster testing and targeted deployments, you can limit execution to
specific hosts or tasks:

#### Target Specific Hosts

```bash
# Only run against jellyfin container
ansible-playbook -i inventory jellyfin.yml --limit jellyfin \
  --vault-password-file=~/.ssh/ansible_key.key

# Only run against docker container
ansible-playbook -i inventory docker.yml --limit docker \
  --vault-password-file=~/.ssh/ansible_key.key

# Only run against proxmox hosts
ansible-playbook -i inventory proxmox_host_setup.yml --limit brix \
  --vault-password-file=~/.ssh/ansible_key.key
```

#### Target Specific Tasks with Tags

```bash
# Only create containers (skip configuration)
ansible-playbook -i inventory proxmox_host_setup.yml \
  --tags container_creation --vault-password-file=~/.ssh/ansible_key.key

# Only configure jellyfin container
ansible-playbook -i inventory proxmox_host_setup.yml \
  --tags jellyfin_container --vault-password-file=~/.ssh/ansible_key.key

# Only configure docker container
ansible-playbook -i inventory proxmox_host_setup.yml \
  --tags docker_container --vault-password-file=~/.ssh/ansible_key.key

# Only download templates
ansible-playbook -i inventory proxmox_host_setup.yml \
  --tags container_templates --vault-password-file=~/.ssh/ansible_key.key
```

#### Skip Specific Tasks

```bash
# Skip container creation, only run configuration
ansible-playbook -i inventory main.yml --skip-tags container_creation \
  --vault-password-file=~/.ssh/ansible_key.key

# Skip server upgrades for faster testing
ansible-playbook -i inventory docker.yml --skip-tags upgrade \
  --vault-password-file=~/.ssh/ansible_key.key
```

### Available Tags

- `proxmox_host_setup` - All host setup tasks
- `container_templates` - Template downloads
- `jellyfin_container` - All Jellyfin container tasks
- `jellyfin_container_creation` - Jellyfin container creation only
- `jellyfin_container_configuration` - Jellyfin container configuration only
- `docker_container` - All Docker container tasks
- `docker_container_creation` - Docker container creation only
- `docker_container_configuration` - Docker container configuration only
- `docker_software` - Docker software installation only
- `docker_gpu_config` - GPU support configuration only
- `docker_images` - Docker image pulls only
- `docker_server_tooling` - Basic server tools installation

### Testing Changes Quickly

For rapid development and testing:

```bash
# Test Docker playbook changes on docker container only
ansible-playbook -i inventory docker.yml --limit docker --check \
  --vault-password-file=~/.ssh/ansible_key.key

# Apply only specific service restart (dry-run first)
ansible-playbook -i inventory docker.yml --limit docker --tags docker_service \
  --check --vault-password-file=~/.ssh/ansible_key.key

# Quick syntax check without execution
ansible-playbook -i inventory docker.yml --syntax-check

# List all available tags
ansible-playbook -i inventory main.yml --list-tags \
  --vault-password-file=~/.ssh/ansible_key.key

# Test just Docker image pulling
ansible-playbook -i inventory docker.yml --limit docker --tags docker_images \
  --vault-password-file=~/.ssh/ansible_key.key
```

## Troubleshooting

### Common Issues

#### Docker Image Pull Failures

If you encounter errors when pulling Docker images:

1. **Missing Python Docker SDK**: The playbook automatically installs
   required dependencies on target hosts

2. **Network connectivity**: Ensure the Docker container has internet access

3. **Docker service not running**: Check if Docker service is active with
   `systemctl status docker`

#### Collection Not Found Errors

```bash
# Reinstall Ansible collections
ansible-galaxy collection install -r requirements.yml --force
```

#### Vault Decryption Errors

```bash
# Verify vault password file exists and has correct permissions
ls -la ~/.ssh/ansible_key.key
chmod 600 ~/.ssh/ansible_key.key
```

### Environment Issues

If you encounter environment-related issues:

```bash
# Recreate the virtual environment
rm -rf venv
./setup.sh

# Or activate existing environment
source activate.sh
```

## Recent Changes & Improvements

This project has undergone significant restructuring to improve modularity,
eliminate code duplication, and enhance maintainability.

### Major Architectural Changes

#### 1. Centralized Handler Management

- **New Structure**: Created `handlers/` directory with modular handler files
  - `handlers/main.yml` - Main import file for all handlers
  - `handlers/lxc_containers.yml` - LXC container start/stop handlers
  - `handlers/services.yml` - Service control handlers (nginx, docker)
  - `handlers/system.yml` - System-level handlers (reboot)
- **Benefits**: Eliminated duplicate handlers across playbooks, centralized
  maintenance
- **Impact**: All playbooks now use `import_tasks: handlers/main.yml` for
  consistent handler behavior

#### 2. Self-Contained Docker Management

- **Restructured `docker.yml`**: Now includes complete Docker container
  lifecycle
  - **Play 1**: Container creation on Proxmox host with proper GPU and
    nesting configuration
  - **Play 2**: Wait for container to be online
  - **Play 3**: Complete Docker software installation and configuration
- **Removed Dependencies**: Docker components removed from
  `proxmox_host_setup.yml`
- **Enhanced Tagging**: Granular control over Docker operations with
  comprehensive tag system

#### 3. Improved Tagging System

- **Docker-specific tags**:
  - `docker_container` - Complete Docker setup (creation + configuration)
  - `docker_container_creation` - LXC container creation only
  - `docker_container_configuration` - Container configuration only
  - `docker_software` - Docker CE installation only
  - `docker_gpu_config` - Intel GPU support configuration
  - `docker_images` - Docker image management
  - `docker_server_tooling` - Basic server tools
- **Benefits**: Precise targeting of specific operations for faster testing
  and deployment

#### 4. Enhanced Docker Container Features

- **Intel GPU Optimization**: Complete Intel GPU support with both
  `/dev/dri/card0` and `/dev/dri/renderD128`
- **Security Nesting**: Proper Docker-in-LXC configuration with AppArmor
  and cgroup settings
- **Pre-installed Images**: Automated pulling of AI/ML workload images
  - `intelanalytics/ipex-llm-inference-cpp-xpu:latest` for Intel AI inference
- **Resource Allocation**: 8 vCPU, 16GB RAM, 100GB disk on ssd1 storage

#### 5. Modular Playbook Structure

- **Focused `proxmox_host_setup.yml`**: Now handles only general Proxmox
  setup and Jellyfin container
- **Comprehensive `docker.yml`**: Complete Docker container management in
  single file
- **Updated `main.yml`**: Proper orchestration of all components
- **Consistent `jellyfin.yml`**: Uses centralized handlers

### Code Quality Improvements

#### 1. Eliminated Code Duplication

- **Handler Consolidation**: Single source of truth for all handlers
- **Consistent Patterns**: Standardized task structure across playbooks
- **DRY Principle**: No repeated handler definitions

#### 2. Enhanced Maintainability

- **Modular Design**: Each playbook has clear, focused responsibility
- **Centralized Configuration**: Handlers managed from single location
- **Consistent Naming**: Standardized task and handler names

#### 3. Improved Documentation

- **Comprehensive README**: Detailed usage examples with targeting options
- **Inline Comments**: Clear explanations of complex LXC configurations
- **Tag Documentation**: Complete list of available tags with descriptions

### Usage Pattern Changes

#### Before

```bash
# Had to run multiple playbooks with unclear dependencies
ansible-playbook -i inventory proxmox_host_setup.yml --tags docker_container
ansible-playbook -i inventory docker.yml  # Incomplete container setup
```

#### After

```bash
# Single command for complete Docker setup
ansible-playbook -i inventory docker.yml --tags docker_container

# Or granular control
ansible-playbook -i inventory docker.yml --tags docker_software
ansible-playbook -i inventory docker.yml --tags docker_images
```

### Performance Improvements

- **Reduced Execution Time**: Granular tagging allows targeting specific changes
- **Parallel Development**: Independent playbooks enable concurrent
  development
- **Faster Testing**: Ability to test individual components without full
  deployment

## Project Structure

### Configuration Files

- `inventory` - Defines all managed hosts and groups
- `vars/proxmox_vars.yml` - Encrypted variables (API tokens, passwords, etc.)
- `ansible.cfg` - Ansible configuration settings

### Playbooks

- `main.yml` - Main playbook that orchestrates all others
- `proxmox_host_setup.yml` - General Proxmox host setup and Jellyfin container
- `jellyfin.yml` - Jellyfin media server configuration
- `docker.yml` - Complete Docker container management (creation + configuration)

### Supporting Files

- `handlers/` - Centralized handler definitions
  - `main.yml` - Imports all handler files
  - `lxc_containers.yml` - LXC container handlers
  - `services.yml` - Service control handlers
  - `system.yml` - System-level handlers
- `tasks/` - Reusable task definitions
  - `server_tooling.yml` - Common server setup tasks
- `templates/` - Jinja2 templates for configuration files

### Environment Setup

- `requirements.txt` - Python dependencies for control machine
- `requirements.yml` - Ansible Galaxy collection requirements
- `setup.sh` - Automated environment setup script
- `activate.sh` - Virtual environment activation script (created by setup.sh)

## Proxmox LXC Image Templates

Default template used: `ubuntu-24.04-standard_24.04-2_amd64.tar.zst`

Location for additional images: [Proxmox Images](http://download.proxmox.com/images/system/)