# AGENTS.md - Proxmox Host Setup Ansible Project

## Commands
```bash
# Lint YAML files
yamllint .

# Lint Ansible playbooks
ansible-lint

# Activate pyenv virtual environment first
pyenv activate ansible

# Run main playbook (requires vault password file)
ansible-playbook -i inventory main.yml --vault-password-file=~/.ssh/ansible_key.key

# Run specific playbooks
ansible-playbook -i inventory proxmox_host_setup.yml --vault-password-file=~/.ssh/ansible_key.key
ansible-playbook -i inventory jellyfin.yml --vault-password-file=~/.ssh/ansible_key.key

# Run k3s cluster deployment (modular structure example)
ansible-playbook -i inventory k3s-cluster.yml --vault-password-file=~/.ssh/proxmox-key.key

# Run individual phases
ansible-playbook -i inventory playbooks/k3s-vm-create.yml --vault-password-file=~/.ssh/proxmox-key.key
ansible-playbook -i inventory playbooks/k3s-vm-bootstrap.yml --vault-password-file=~/.ssh/proxmox-key.key
ansible-playbook -i inventory playbooks/k3s-cluster-configure.yml --vault-password-file=~/.ssh/proxmox-key.key

# Run individual tasks with tags
ansible-playbook -i inventory main.yml --tags="jellyfin_container_creation"
ansible-playbook -i inventory k3s-cluster.yml --tags="k3s_server"
```

## Project Architecture

### Preferred Structure (Modular Approach)
For new infrastructure deployments, follow the modular pattern established by the k3s cluster:

```
project-root/
├── <deployment-name>.yml          # Main orchestrator (import_playbook only)
├── playbooks/
│   ├── <deployment>-infra.yml     # Infrastructure creation (VMs/containers)
│   ├── <deployment>-bootstrap.yml # Initialization and discovery
│   └── <deployment>-configure.yml # Software installation via roles
├── roles/
│   ├── <component>_base/          # Common configuration
│   ├── <component>_server/        # Server/control-plane specific
│   └── <component>_agent/         # Agent/worker specific
└── vars/
    └── <deployment>_vars.yml      # Centralized configuration
```

#### Example: K3s Cluster Structure
```
k3s-cluster.yml                    # Orchestrator
playbooks/
├── k3s-vm-create.yml              # Phase 1: VM infrastructure
├── k3s-vm-bootstrap.yml           # Phase 2: Cloud-init & IP discovery
└── k3s-cluster-configure.yml      # Phase 3: K3s installation
roles/
├── k3s_node/                      # Base: dependencies, cgroups
├── k3s_server/                    # Control plane installation
└── k3s_agent/                     # Worker node installation
vars/
└── k3s_vars.yml                   # Node definitions with roles
```

### Architecture Principles

#### 1. Separation of Concerns
- **Playbooks**: Infrastructure orchestration (Proxmox API, VM creation, IP discovery)
- **Roles**: Software configuration (idempotent, reusable, platform-agnostic)
- **Variables**: Single source of truth (centralized in vars/)

#### 2. Phase-Based Execution
Break deployments into logical phases:
1. **Infrastructure**: Create VMs/containers, configure resources
2. **Bootstrap**: Wait for initialization, discover IPs, prepare access
3. **Configure**: Install software, apply roles, verify deployment

#### 3. Dynamic Inventory
For VM-based deployments:
- Use qemu-guest-agent for IP discovery
- Create dynamic inventory groups based on roles
- Support deployments without DNS resolution

#### 4. Role Design
Each role should be:
- **Idempotent**: Safe to run multiple times
- **Focused**: Single responsibility (base, server, agent)
- **Reusable**: Works on VMs, bare metal, or other platforms
- **Testable**: Can be tested with Molecule independently

### Platform-Specific Considerations

#### Alpine Linux
- **Privilege Escalation**: Use `become_method: doas` (not sudo)
- **Service Management**: Use `ansible.builtin.service` (not systemd module)
- **Package Manager**: `ansible.builtin.apk` module (no cache_valid_time parameter)
- **Init System**: OpenRC, not systemd

#### Proxmox VMs
- **Cloud-init**: Use NoCloud datasource with SATA CD-ROM for q35 machine type
- **Guest Agent**: Install qemu-guest-agent for IP discovery and management
- **Hardware Acceleration**: Map /dev/dri devices with proper UID/GID
- **UEFI**: Use efidisk0 with q35 machine type

## Code Style
- Use proper Ansible indentation
- Start all files with `---` YAML document separator
- Use `ansible.builtin.` prefix for core modules, community collections for others
- Variable files encrypted with Ansible Vault (vars/proxmox_vars.yml)
- Use descriptive task names with proper capitalization
- Group related tasks with tags for selective execution
- Use block/when constructs for conditional task groups
- Handlers for service restarts and state changes
- Comments for complex configurations (especially LXC mappings)
- **Main orchestrators**: Use `import_playbook` only, no tasks
- **Playbook files**: Infrastructure logic, direct module calls
- **Role files**: Configuration logic, idempotent operations
- **Delegate to localhost**: Always set `become: false` to avoid doas/sudo issues

## Cursor Rules
Comprehensive Cursor rules have been generated in `.cursor/rules/` directory:

- **project-overview.mdc** - Project structure and infrastructure overview
- **ansible-style.mdc** - Ansible coding style and best practices (applies to *.yml,*.yaml files)
- **commands.mdc** - Common commands and workflows
- **container-config.mdc** - LXC container configuration and hardware acceleration
- **handlers.mdc** - Handler system and service management patterns
- **troubleshooting.mdc** - Common issues and debugging guide
- **variables.mdc** - Variable management and vault security (applies to vars/*.yml files)
- **templates.mdc** - Jinja2 template patterns (applies to templates/*.j2 files)
- **development.mdc** - Development workflow and testing strategies
- **security.mdc** - Security best practices and compliance requirements

These rules provide comprehensive guidance for:
- Ansible playbook development and best practices
- LXC container configuration and hardware acceleration
- Security practices and vault management
- Development workflows and testing strategies
- Troubleshooting common issues
- Template and variable management

## Copilot Rules
None detected.
