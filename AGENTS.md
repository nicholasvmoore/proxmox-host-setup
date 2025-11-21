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
# NOTE: Ensure DNS resolution works for all hostnames before running
ansible-playbook -i inventory k3s-cluster.yml --vault-password-file=~/.ssh/proxmox-key.key

# Run individual phases
ansible-playbook -i inventory playbooks/k3s-vm-create.yml --vault-password-file=~/.ssh/proxmox-key.key
ansible-playbook -i inventory playbooks/k3s-vm-bootstrap.yml --vault-password-file=~/.ssh/proxmox-key.key
ansible-playbook -i inventory playbooks/k3s-cluster-configure.yml --vault-password-file=~/.ssh/proxmox-key.key

# Install GitHub Actions Runner Controller
ansible-playbook -i inventory playbooks/github-actions-runner-controller.yml --vault-password-file=~/.ssh/proxmox-key.key

# Run individual tasks with tags
ansible-playbook -i inventory main.yml --tags="jellyfin_container_creation"
ansible-playbook -i inventory k3s-cluster.yml --tags="k3s_server"
```

## Development Workflow

### Testing Before Commit
**ALWAYS test changes before committing and pushing** - this ensures code quality and prevents broken deployments:

#### 1. **Syntax Validation**
```bash
# Lint all YAML files
yamllint .

# Lint Ansible playbooks and roles
ansible-lint

# Check for YAML syntax errors specifically
python -c "import yaml; yaml.safe_load(open('file.yml'))"
```

#### 2. **Dry-Run Testing**
```bash
# Test playbooks with --check (dry-run mode)
ansible-playbook -i inventory playbook.yml --check --vault-password-file=~/.ssh/vault.key

# Test specific tags
ansible-playbook -i inventory main.yml --tags="component" --check

# Test variable syntax
ansible-playbook -i inventory playbook.yml --syntax-check
```

#### 3. **Functional Testing**
```bash
# Test connectivity to hosts
ansible -i inventory all -m ping

# Test specific modules
ansible -i inventory group -m command -a "uptime"

# Test role functionality on single host
ansible-playbook -i inventory playbook.yml --limit hostname
```

#### 4. **Integration Testing**
```bash
# Test complete workflows
ansible-playbook -i inventory k3s-cluster.yml --check --vault-password-file=~/.ssh/proxmox-key.key

# Verify DNS resolution before cluster deployment
ansible -i inventory k3s_nodes -m command -a "getent hosts {{ inventory_hostname }}"

# Test service availability
ansible -i inventory k3s_servers -m command -a "sudo systemctl status k3s"
```

### Commit and Push Guidelines

#### Before Committing:
- ✅ **All tests pass** - syntax, linting, and dry-run
- ✅ **Documentation updated** - AGENTS.md reflects changes
- ✅ **No hardcoded values** - use variables and vault for secrets
- ✅ **Idempotent changes** - playbooks can run multiple times safely
- ✅ **Peer review** - share changes for feedback when possible

#### Commit Message Format:
```bash
# Feature commits
feat: add HA k3s cluster support
feat: implement hostname-first networking

# Fix commits
fix: resolve DNS resolution issues in bootstrap
fix: correct k3s server join logic

# Documentation commits
docs: update AGENTS.md with testing guidelines
docs: add DNS troubleshooting section

# Refactor commits
refactor: simplify VM creation playbook
refactor: consolidate role variables
```

#### Push Checklist:
- 🔍 **Test in staging** - deploy to test environment first
- 📋 **Backup critical data** - ensure recovery possible
- 🚨 **Review impact** - check for service disruptions
- 📝 **Update runbooks** - document any operational changes
- 🏷️ **Version tagging** - tag releases for rollback capability

### Troubleshooting Failed Tests

#### Common Issues:
- **Connection failures**: Check SSH keys, firewall rules, DNS resolution
- **Permission errors**: Verify vault passwords, sudo access, API tokens
- **Variable undefined**: Check variable files, vault encryption, group_vars
- **Module failures**: Test modules individually, check Ansible version compatibility

#### Debug Commands:
```bash
# Increase verbosity
ansible-playbook -i inventory playbook.yml -vvv

# Debug specific tasks
ansible-playbook -i inventory playbook.yml --step --check

# Test variable values
ansible -i inventory hostname -m debug -a "var=variable_name"

# Check facts gathering
ansible -i inventory hostname -m setup | grep "ansible_"
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

**DNS Requirements for K3s HA Clusters:**
- All nodes must be resolvable by hostname from all other nodes
- Use FQDNs in `k3s_vars.yml` (e.g., `k3s-node-01.example.com`)
- Configure DNS server or `/etc/hosts` entries via Ansible
- K3s server join commands use `--server=https://hostname:6443` format
- TLS certificates include hostname SANs for secure communication

### Architecture Principles

#### 1. Separation of Concerns
- **Playbooks**: Infrastructure orchestration (Proxmox API, VM creation, IP discovery)
- **Roles**: Software configuration (idempotent, reusable, platform-agnostic)
- **Variables**: Single source of truth (centralized in vars/)

#### 2. Hostname-First Networking
**ALWAYS use hostnames instead of IP addresses** for all configurations:
- **Ansible inventory**: Define hosts by fully qualified domain names (FQDN)
- **K3s cluster URLs**: Use `--server=https://hostname:6443` format
- **Service discovery**: Rely on DNS resolution, never hardcode IPs
- **TLS certificates**: Generate certificates with hostname SANs
- **No manual intervention**: All networking must be automated through Ansible

#### 3. Phase-Based Execution
Break deployments into logical phases:
1. **Infrastructure**: Create VMs/containers, configure resources
2. **Bootstrap**: Wait for initialization, discover IPs, prepare access
3. **Configure**: Install software, apply roles, verify deployment

#### 4. Dynamic Inventory
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
- **DNS Configuration**: Ensure hostname resolution works via DNS or hosts file
- **Network Setup**: Configure static hostnames in cloud-init metadata

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
- **Hostname usage**: Always use FQDNs, never hardcode IP addresses in configurations
- **DNS dependency**: Ensure all services can resolve hostnames before deployment

## DNS and Hostname Management

### Requirements
- **FQDN Usage**: All hosts must be defined with fully qualified domain names
- **DNS Resolution**: Hostnames must resolve from all nodes in the cluster
- **No IP Dependencies**: Configurations must not rely on hardcoded IP addresses
- **Automated Setup**: DNS or hosts file entries must be managed through Ansible

### Common DNS Issues and Solutions

#### 1. Hostname Resolution Failures
**Symptoms**: `ping hostname` fails, services can't connect to each other
**Solutions**:
- Verify DNS server configuration in `/etc/resolv.conf`
- Add entries to `/etc/hosts` via Ansible `ansible.builtin.lineinfile`
- Ensure cloud-init sets correct hostname in VM metadata

#### 2. K3s Cluster Join Failures
**Symptoms**: Additional servers fail to join with "connection refused" errors
**Solutions**:
- Verify first server hostname resolves: `nslookup k3s-node-01.example.com`
- Check K3s server URL uses hostname: `--server=https://hostname:6443`
- Ensure firewall allows traffic on port 6443 between nodes

#### 3. Certificate Validation Errors
**Symptoms**: TLS handshake failures, certificate validation errors
**Solutions**:
- K3s automatically generates certificates with hostname SANs
- Ensure `--tls-san=hostname` is used during server initialization
- Verify hostname matches certificate common name

### Ansible DNS Configuration Patterns

```yaml
# Add hosts entries for cluster nodes
- name: Configure /etc/hosts for cluster DNS resolution
  ansible.builtin.lineinfile:
    path: /etc/hosts
    line: "{{ item.ip }} {{ item.hostname }} {{ item.shortname }}"
    state: present
  loop: "{{ cluster_nodes }}"
  when: dns_server is not defined

# Verify hostname resolution
- name: Test hostname resolution
  ansible.builtin.command: "getent hosts {{ inventory_hostname }}"
  register: hostname_check
  failed_when: hostname_check.rc != 0
```

## GitHub Actions Integration

### GitHub Actions Runner Controller (ARC)

The project includes automated deployment of the GitHub Actions Runner Controller to enable self-hosted runners on your K3s cluster.

#### Prerequisites
- **GitHub Authentication**: Either a GitHub App or Personal Access Token
- **DNS Resolution**: All cluster nodes must be reachable via hostnames
- **Cert-Manager**: Automatically installed as a prerequisite

#### Installation
```bash
# Install ARC on existing cluster
ansible-playbook -i inventory playbooks/github-actions-runner-controller.yml --vault-password-file=~/.ssh/proxmox-key.key
```

#### Configuration Options

**GitHub App Authentication (Recommended):**
```bash
export GITHUB_APP_ID="your-app-id"
export GITHUB_APP_PRIVATE_KEY="your-private-key"
export GITHUB_APP_INSTALLATION_ID="your-installation-id"
```

**Personal Access Token Authentication:**
```bash
export GITHUB_TOKEN="your-personal-access-token"
```

#### Runner Configuration
- **Repository**: Configured in `vars/arc_vars.yml`
- **Labels**: `self-hosted`, `linux`, `x64`
- **Resources**: CPU/Memory limits and requests
- **Ephemeral**: Runners are cleaned up after each job

#### Management Commands
```bash
# Check ARC status
kubectl get pods -n actions-runner-system

# View runner deployments
kubectl get runnerdeployments -n actions-runner-system

# Scale runners
kubectl scale runnerdeployment example-runners --replicas=3 -n actions-runner-system

# View runner logs
kubectl logs -n actions-runner-system deployment/actions-runner-controller
```

#### Security Considerations
- **Network Policies**: Consider implementing Kubernetes network policies
- **RBAC**: Limit runner access to necessary resources only
- **Secrets Management**: Store GitHub credentials securely (Ansible Vault recommended)
- **Resource Limits**: Configure appropriate CPU/memory limits to prevent resource exhaustion

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
