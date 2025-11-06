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
PYENV_VERSION=ansible ansible-playbook -i inventory main.yml --vault-password-file=~/.ssh/proxmox-key.key

# Individual playbooks (legacy)
PYENV_VERSION=ansible ansible-playbook -i inventory proxmox_host_setup.yml --vault-password-file=~/.ssh/proxmox-key.key
PYENV_VERSION=ansible ansible-playbook -i inventory jellyfin.yml --vault-password-file=~/.ssh/proxmox-key.key
PYENV_VERSION=ansible ansible-playbook -i inventory docker.yml --vault-password-file=~/.ssh/proxmox-key.key

# K3s cluster deployment (modular structure)
PYENV_VERSION=ansible ansible-playbook -i inventory k3s-cluster.yml --vault-password-file=~/.ssh/proxmox-key.key

# K3s individual phases (for testing/debugging)
PYENV_VERSION=ansible ansible-playbook -i inventory playbooks/k3s-vm-create.yml --vault-password-file=~/.ssh/proxmox-key.key
PYENV_VERSION=ansible ansible-playbook -i inventory playbooks/k3s-vm-bootstrap.yml --vault-password-file=~/.ssh/proxmox-key.key
PYENV_VERSION=ansible ansible-playbook -i inventory playbooks/k3s-cluster-configure.yml --vault-password-file=~/.ssh/proxmox-key.key
```

### Targeted Execution
```bash
# Target specific hosts
PYENV_VERSION=ansible ansible-playbook -i inventory docker.yml --limit docker --vault-password-file=~/.ssh/proxmox-key.key

# Target specific tasks with tags
PYENV_VERSION=ansible ansible-playbook -i inventory docker.yml --tags docker_images --vault-password-file=~/.ssh/proxmox-key.key
PYENV_VERSION=ansible ansible-playbook -i inventory k3s-cluster.yml --tags k3s_base --vault-password-file=~/.ssh/proxmox-key.key
PYENV_VERSION=ansible ansible-playbook -i inventory k3s-cluster.yml --tags k3s_server --vault-password-file=~/.ssh/proxmox-key.key

# Dry run (check mode)
PYENV_VERSION=ansible ansible-playbook -i inventory docker.yml --check --vault-password-file=~/.ssh/proxmox-key.key
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

### Playbook Structure (Legacy)
- `main.yml`: Entry point that orchestrates all infrastructure setup (Proxmox + Docker + Jellyfin)
- `proxmox_host_setup.yml`: Configures Proxmox host, downloads templates, creates Jellyfin LXC container
- `docker.yml`: Complete Docker container lifecycle (creation + software installation + configuration)
- `jellyfin.yml`: Installs and configures Jellyfin inside the LXC container

### Modular Architecture (Preferred for New Deployments)

**IMPORTANT**: All new infrastructure deployments should follow the modular pattern established by the k3s cluster deployment.

#### Directory Structure
```
<deployment-name>.yml              # Main orchestrator (import_playbook only)
playbooks/
├── <deployment>-infra.yml         # Infrastructure creation (VMs/containers)
├── <deployment>-bootstrap.yml     # Initialization and IP discovery
└── <deployment>-configure.yml     # Software installation via roles
roles/
├── <component>_base/              # Common configuration for all nodes
│   ├── tasks/main.yml             # Base setup tasks
│   ├── defaults/main.yml          # Default variables
│   └── handlers/main.yml          # Service handlers
├── <component>_server/            # Server/control-plane specific
│   ├── tasks/main.yml
│   ├── defaults/main.yml
│   └── handlers/main.yml
└── <component>_agent/             # Agent/worker specific
    ├── tasks/main.yml
    ├── defaults/main.yml
    └── handlers/main.yml
vars/
└── <deployment>_vars.yml          # Centralized node/resource definitions
```

#### Example: K3s Cluster
```
k3s-cluster.yml                    # Orchestrator (3 import_playbook statements)
playbooks/
├── k3s-vm-create.yml              # Creates 3 Alpine VMs with cloud-init
├── k3s-vm-bootstrap.yml           # Waits for boot, discovers IPs, creates dynamic inventory
└── k3s-cluster-configure.yml      # Applies roles to install k3s
roles/
├── k3s_node/                      # Base: apk packages, cgroups, dependencies
├── k3s_server/                    # Installs k3s server with cluster-init
└── k3s_agent/                     # Installs k3s agent, joins cluster
vars/
└── k3s_vars.yml                   # Defines 3 nodes with roles (server/agent)
```

#### Design Principles

**1. Separation of Concerns**
- **Playbooks**: Infrastructure orchestration using Proxmox API, VM management, network discovery
- **Roles**: Software configuration that is idempotent, reusable, and platform-agnostic
- **Variables**: Single source of truth for all node/resource definitions

**2. Phase-Based Execution**
All deployments should have 3 distinct phases:
- **Phase 1 (Infrastructure)**: Create VMs/containers, configure hardware, set up cloud-init
- **Phase 2 (Bootstrap)**: Wait for initialization, discover dynamic IPs, create inventory groups
- **Phase 3 (Configure)**: Apply roles to install and configure software

**3. Dynamic Inventory Management**
For VM-based deployments:
- Use qemu-guest-agent to discover IP addresses after VM boot
- Use `add_host` to create dynamic inventory groups (e.g., `k3s_servers`, `k3s_agents`)
- Assign hosts to role-based groups for targeted role application
- Avoids DNS resolution issues by using IPs directly

**4. Role Hierarchy**
Roles should follow a base → specific pattern:
- **Base role**: Common configuration applied to all nodes (dependencies, system config)
- **Server role**: Control plane or primary node configuration
- **Agent role**: Worker or secondary node configuration

Each role must be:
- Idempotent (safe to run multiple times)
- Focused (single responsibility)
- Reusable (works on VMs, bare metal, containers)
- Testable (can be validated with Molecule)

#### Platform-Specific Considerations

**Alpine Linux (Used by K3s Cluster)**
- **Privilege Escalation**: Always use `become_method: doas` (not sudo)
  - Alpine uses `doas` by default, not `sudo`
  - Add `become_method: doas` to all plays that need privilege escalation
- **Service Management**: Use `ansible.builtin.service`, NOT `ansible.builtin.systemd`
  - Alpine uses OpenRC, not systemd
  - Handlers should use `ansible.builtin.service` module
- **Package Management**: `ansible.builtin.apk` module specifics
  - No `cache_valid_time` parameter (not supported)
  - Use `update_cache: true` for package index updates
- **Init System**: OpenRC commands differ from systemd
  - Services: `rc-service <name> start/stop/restart`
  - Enable on boot: `rc-update add <service> default`

**Proxmox VM Deployments**
- **Cloud-init**: Use NoCloud datasource for reliability
  - Set `citype: nocloud` in VM configuration
  - Use SATA CD-ROM (not IDE) for q35 machine type compatibility
  - Configure datasource in template: `datasource_list: [ NoCloud ]`
- **QEMU Guest Agent**: Essential for IP discovery
  - Install `qemu-guest-agent` in VM templates via virt-customize
  - Enable on boot: `rc-update add qemu-guest-agent default` (Alpine)
  - Use `qm guest cmd` for IP discovery via Proxmox host
- **Machine Types**:
  - **q35**: Modern, UEFI-compatible, requires SATA (not IDE)
  - **i440fx**: Legacy, BIOS-compatible, supports IDE
  - Always use q35 for new deployments
- **Hardware Passthrough**:
  - GPU: Map `/dev/dri/renderD128` and `/dev/dri/card0`
  - Requires proper UID/GID mapping in LXC configuration
  - Use `agent: "enabled=1"` for guest agent communication

**Dynamic Inventory Pattern**
```yaml
- name: Get IP address from qemu-guest-agent
  ansible.builtin.shell: |
    /usr/sbin/qm guest cmd {{ item.vmid }} network-get-interfaces | jq -r '.[] | select(.name=="eth0") | ."ip-addresses"[] | select(.["ip-address-type"]=="ipv4") | .["ip-address"]'
  register: vm_ips
  loop: "{{ nodes }}"

- name: Add nodes to dynamic inventory
  ansible.builtin.add_host:
    name: "{{ item.item.hostname }}"
    ansible_host: "{{ item.stdout }}"
    ansible_user: <username>
    groups:
      - nodes_dynamic
      - "{{ item.item.role }}_nodes"  # Role-based grouping
  loop: "{{ vm_ips.results }}"
  delegate_to: localhost
```

**Delegation Best Practices**
- When delegating tasks to localhost, always set `become: false`
- This prevents trying to use `doas` on the control machine
- Example:
  ```yaml
  - name: Save token to localhost
    ansible.builtin.copy:
      content: "{{ token }}"
      dest: /tmp/token
    delegate_to: localhost
    become: false  # Critical!
  ```

### Key Components (Legacy Architecture)

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

#### Proxmox Hosts
- Target hosts: `brix` (for brix.pcola.moorenix.com setup), `jellyfin` (for Jellyfin container), `docker` (for Docker container), `prox0` (for prox0.pcola.moorenix.com setup)
- Proxmox API hosts:
  - brix.pcola.moorenix.com
    - api_token_id: automation
    - api_token_secret: brix_api_token_secret
  - prox0.pcola.moorenix.com
    - api_token_id: automation
    - api_token_secret: prox0_api_token_secret

#### LXC Containers
- Jellyfin: hostname `jellyfin`, VMID 200
  - 4 CPU cores, 4GB RAM, 100GB SSD
  - Intel GPU hardware acceleration
- Docker: hostname `docker`, VMID 201
  - 8 CPU cores, 16GB RAM, 100GB SSD
  - Intel GPU hardware acceleration
  - Container nesting enabled

#### K3s Cluster (VMs on prox0)
- k3s-node-01: VMID 300, Control plane (server)
  - 4 CPU cores, 8GB RAM, 20GB SSD
  - IP: 192.168.16.214 (dynamic DHCP)
  - Role: k3s server with cluster-init
- k3s-node-02: VMID 301, Worker (agent)
  - 4 CPU cores, 8GB RAM, 20GB SSD
  - IP: 192.168.16.199 (dynamic DHCP)
  - Role: k3s agent
- k3s-node-03: VMID 302, Worker (agent)
  - 4 CPU cores, 8GB RAM, 20GB SSD
  - IP: 192.168.16.223 (dynamic DHCP)
  - Role: k3s agent
- OS: Alpine Linux v3.22
- K3s version: v1.33.5+k3s1
- Container runtime: containerd 2.1.4-k3s1
- Disabled components: Traefik, ServiceLB

#### Other Details
- Public domain: jellyfin.moorenix.com (configurable via `jellyfin_public_domain`)
- Hardware acceleration: Intel GPU with proper device permissions and UID mapping
- VM templates: Ubuntu 24.04 LTS (VMID 1000), Alpine 3.22 (VMID 1001)

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

#### K3s Cluster
- `k3s_vm_creation`: VM infrastructure creation phase
- `k3s_software`: All k3s software installation tasks
- `k3s_base`: Base node configuration (dependencies, cgroups)
- `k3s_server`: K3s control plane installation
- `k3s_agent`: K3s worker node installation

## Important Notes

### Environment & Authentication
- The vault password file must be located at `~/.ssh/proxmox-key.key`
- Use `./setup.sh && source activate.sh` for automated environment setup
- Certificate generation includes hardcoded email (nicholasvmoore@gmail.com)
- **IMPORTANT**: `vars/proxmox_vars.yml` must ALWAYS be encrypted with ansible-vault before committing to git
  - To decrypt for editing: `PYENV_VERSION=ansible ansible-vault decrypt vars/proxmox_vars.yml --vault-password-file=~/.ssh/proxmox-key.key`
  - To re-encrypt after editing: `PYENV_VERSION=ansible ansible-vault encrypt vars/proxmox_vars.yml --vault-password-file=~/.ssh/proxmox-key.key`
  - Never commit the file in decrypted state

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
