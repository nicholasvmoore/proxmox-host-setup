# Proxmox Host Setup - Codebase Rules and Guidelines

## Project Overview

This is an Ansible automation project for Proxmox VE host setup and LXC container provisioning, specifically designed to create and configure:
- **Jellyfin Media Server** (VMID 200) with Intel GPU hardware acceleration
- **Docker Host** (VMID 201) with Intel GPU support and AI/ML workloads
- **Proxmox Host Configuration** with necessary dependencies

## Core Architecture Rules

### 1. Playbook Structure and Organization

#### Main Orchestration
- **`main.yml`** is the single entry point that orchestrates all other playbooks
- **NEVER** run individual playbooks directly in production - always use `main.yml`
- Playbooks are executed in this order:
  1. `proxmox_host_setup.yml` - Host setup and Jellyfin container
  2. `proxmox_templates.yml` - Template downloads
  3. `vm_template_setup.yml` - VM template configuration
  4. `docker.yml` - Docker container creation and configuration
  5. `jellyfin.yml` - Jellyfin service installation and configuration

#### Playbook Responsibilities
- **`proxmox_host_setup.yml`**: Proxmox host dependencies + Jellyfin LXC container creation
- **`jellyfin.yml`**: Jellyfin service installation, Nginx reverse proxy, SSL certificates
- **`docker.yml`**: Complete Docker LXC container lifecycle (creation + software + configuration)
- **`proxmox_templates.yml`**: Container template downloads
- **`vm_template_setup.yml`**: VM template configuration

### 2. Handler Management Rules

#### Centralized Handler Architecture
- **ALL** handlers are defined in the `handlers/` directory
- **NEVER** define handlers directly in playbooks
- Use `import_tasks: handlers/main.yml` in every playbook
- Handler files are organized by function:
  - `handlers/lxc_containers.yml` - LXC container start/stop operations
  - `handlers/services.yml` - Service control (nginx, docker, jellyfin)
  - `handlers/system.yml` - System-level operations (reboot)

#### Handler Usage Rules
- Handlers must be parameterized with variables (e.g., `{{ service_name }}`, `{{ lxc_vmid }}`)
- Use `notify` with appropriate variable context
- Example: `notify: "Restart service"` with `vars: { service_name: "nginx" }`

### 3. Container Management Rules

#### LXC Container Creation
- **VMID Assignment**: Jellyfin = 200, Docker = 201
- **Template Usage**: Ubuntu 24.04 LTS for both containers
- **Resource Allocation**:
  - Jellyfin: 4 vCPU, 4GB RAM, 100GB disk (ssd0)
  - Docker: 8 vCPU, 16GB RAM, 100GB disk (ssd1)
- **Network Configuration**: DHCP on vmbr0 for both containers

#### Container Configuration Updates
- **ALWAYS** stop container before configuration changes
- Use `when: ansible_check_mode == false` to prevent dry-run issues
- Apply configuration via handlers to restart containers
- Configuration files are managed in `/var/lib/ansible/lxc-configs/`

#### Hardware Acceleration Rules
- **Intel GPU Access**: Both containers require Intel GPU device access
- **Device Mapping**: 
  - Jellyfin: `/dev/dri/renderD128` only
  - Docker: `/dev/dri/card0` and `/dev/dri/renderD128`
- **UID/GID Mapping**: Complex mapping required for GPU access (see templates)

### 4. Security and Authentication Rules

#### Ansible Vault Usage
- **ALL** sensitive variables must be encrypted in `vars/proxmox_vars.yml`
- Vault password file location: `~/.ssh/ansible_key.key`
- **NEVER** commit unencrypted sensitive data
- Use `--vault-password-file=~/.ssh/ansible_key.key` for all playbook runs

#### API Token Management
- Proxmox API tokens are stored in encrypted variables
- Each host has separate API credentials:
  - `brix_api_token_secret` for brix.pcola.moorenix.com
  - `prox0_api_token_secret` for prox0.pcola.moorenix.com

### 5. Tagging System Rules

#### Required Tags for All Tasks
- **EVERY** task must have appropriate tags
- Use hierarchical tagging (e.g., `docker_container` + `docker_software`)
- Tags enable granular execution and testing

#### Available Tag Categories
- **Container Management**: `jellyfin_container`, `docker_container`
- **Creation vs Configuration**: `*_container_creation`, `*_container_configuration`
- **Service-Specific**: `docker_software`, `docker_gpu_config`, `docker_images`
- **Host Operations**: `proxmox_host_setup`, `container_templates`

#### Tag Usage Examples
```bash
# Complete Docker setup
ansible-playbook -i inventory docker.yml --tags docker_container

# Only Docker software installation
ansible-playbook -i inventory docker.yml --tags docker_software

# Only GPU configuration
ansible-playbook -i inventory docker.yml --tags docker_gpu_config
```

### 6. Environment and Dependencies Rules

#### Python Environment
- **ALWAYS** use virtual environment (`venv/`)
- **ALWAYS** activate environment before running Ansible: `source activate.sh`
- Python 3.8+ required
- Dependencies managed in `requirements.txt`

#### Ansible Collections
- Collections defined in `requirements.yml`
- **REQUIRED** collections:
  - `community.general` (Proxmox modules)
  - `community.docker` (Docker modules)
  - `ansible.posix` (System tasks)

#### Environment Setup
- Use `./setup.sh` for automated environment setup
- Manual setup requires: venv creation, pip install, ansible-galaxy install

### 7. Template and Configuration Rules

#### Jinja2 Templates
- All configuration files use Jinja2 templates in `templates/`
- Templates must include `{{ ansible_managed }}` comment
- Use descriptive variable names with clear context

#### LXC Configuration Templates
- **`jellyfin_lxc.conf.j2`**: Jellyfin container with GPU access
- **`docker_lxc.conf.j2`**: Docker container with nesting and GPU access
- Complex UID/GID mapping for hardware device access

#### Service Configuration Templates
- **`nginx_vhost.j2`**: Nginx reverse proxy for Jellyfin
- **`certbot_*.j2`**: SSL certificate management
- **`options-ssl-nginx.j2`**: SSL configuration

### 8. Execution and Testing Rules

#### Playbook Execution
- **ALWAYS** use `--vault-password-file=~/.ssh/ansible_key.key`
- Use `--check` for dry runs before applying changes
- Use `--limit <host>` for targeted execution
- Use `--tags <tag>` for specific task execution

#### Development Workflow
1. Make changes to playbooks/templates
2. Run syntax check: `ansible-playbook -i inventory <playbook> --syntax-check`
3. Run dry-run: `ansible-playbook -i inventory <playbook> --check`
4. Apply changes: `ansible-playbook -i inventory <playbook>`

#### Testing Patterns
```bash
# Test specific container
ansible-playbook -i inventory docker.yml --limit docker --check

# Test specific functionality
ansible-playbook -i inventory docker.yml --tags docker_images --check

# Full deployment
ansible-playbook -i inventory main.yml --vault-password-file=~/.ssh/ansible_key.key
```

### 9. File and Directory Structure Rules

#### Required Directory Structure
```
proxmox-host-setup/
├── handlers/           # Centralized handlers
├── tasks/             # Reusable task definitions
├── templates/         # Jinja2 configuration templates
├── vars/             # Encrypted variables
├── main.yml          # Main orchestration playbook
├── *.yml             # Individual playbooks
├── inventory         # Host definitions
├── requirements.txt  # Python dependencies
├── requirements.yml  # Ansible collections
└── setup.sh         # Environment setup script
```

#### File Naming Conventions
- Playbooks: `*.yml` (lowercase with underscores)
- Templates: `*.j2` (descriptive names)
- Handlers: `*.yml` (grouped by function)
- Variables: `*_vars.yml` (encrypted)

### 10. Code Quality and Maintenance Rules

#### Ansible Best Practices
- Use `ansible.builtin.` prefix for core modules
- Use `community.*` prefix for community modules
- Include proper error handling with `when` conditions
- Use `async` and `poll` for long-running tasks
- Include meaningful task names and descriptions

#### Documentation Requirements
- **EVERY** playbook must have clear purpose and usage documentation
- Complex configurations must include inline comments
- Template files must explain complex mappings (UID/GID, device access)

#### Code Review Checklist
- [ ] All tasks have appropriate tags
- [ ] Handlers are centralized and parameterized
- [ ] Sensitive data is encrypted
- [ ] Templates include `{{ ansible_managed }}`
- [ ] Error handling is appropriate
- [ ] Documentation is clear and complete

### 11. Troubleshooting and Debugging Rules

#### Common Issues and Solutions
- **Collection errors**: Reinstall with `ansible-galaxy collection install -r requirements.yml --force`
- **Vault errors**: Verify `~/.ssh/ansible_key.key` exists and has correct permissions
- **Container access**: Check LXC configuration and device mappings
- **Service failures**: Check handler execution and service status

#### Debugging Commands
```bash
# Check Ansible version and collections
ansible --version
ansible-galaxy collection list

# Verify vault password
ansible-vault view vars/proxmox_vars.yml --vault-password-file=~/.ssh/ansible_key.key

# Test connectivity
ansible all -i inventory -m ping

# List available tags
ansible-playbook -i inventory main.yml --list-tags
```

### 12. Production Deployment Rules

#### Pre-deployment Checklist
- [ ] Environment is properly set up (`./setup.sh`)
- [ ] Vault password file is secure and accessible
- [ ] Inventory file contains correct host information
- [ ] All required collections are installed
- [ ] Dry-run passes without errors

#### Deployment Process
1. **Test Environment**: Run full deployment in test environment first
2. **Staged Deployment**: Use tags to deploy components incrementally
3. **Monitoring**: Monitor container status and service health
4. **Rollback Plan**: Have rollback procedures documented

#### Post-deployment Verification
- [ ] All containers are running and accessible
- [ ] Services are responding correctly
- [ ] SSL certificates are valid and auto-renewal is configured
- [ ] Hardware acceleration is working (GPU access)
- [ ] Docker images are pulled and accessible

## Violation Consequences

### Code Quality Violations
- **Missing tags**: Task will not be targetable for testing
- **Hardcoded values**: Reduces maintainability and flexibility
- **Missing error handling**: Can cause playbook failures
- **Unencrypted secrets**: Security vulnerability

### Architecture Violations
- **Handler duplication**: Maintenance nightmare, inconsistent behavior
- **Direct playbook execution**: Bypasses orchestration, can cause state issues
- **Missing vault usage**: Security risk, sensitive data exposure

### Process Violations
- **Skipping dry-run**: Can cause production issues
- **Missing environment setup**: Dependency failures
- **Incorrect tag usage**: Inefficient testing and deployment

## Enforcement

These rules are enforced through:
- **Code review process**: All changes must follow these rules
- **Automated testing**: CI/CD pipeline validates rule compliance
- **Documentation**: Rules are documented and accessible
- **Training**: Team members are trained on these rules
- **Regular audits**: Periodic review of codebase compliance

## Updates and Maintenance

- Rules are reviewed quarterly
- Updates require team consensus
- Changes are documented with rationale
- All team members are notified of rule changes
- Rule violations are tracked and addressed promptly