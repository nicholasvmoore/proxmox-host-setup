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

# Run individual tasks with tags
ansible-playbook -i inventory main.yml --tags="jellyfin_container_creation"
```

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
