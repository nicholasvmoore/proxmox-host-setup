# AGENTS.md - Proxmox Host Setup Ansible Project

## Commands
```bash
# Lint YAML files
yamllint .

# Lint Ansible playbooks  
ansible-lint

# Run main playbook (requires vault password file)
ansible-playbook -i inventory main.yml --vault-password-file=~/.ssh/ansible_key.key

# Run specific playbooks
ansible-playbook -i inventory proxmox_host_setup.yml --vault-password-file=~/.ssh/ansible_key.key
ansible-playbook -i inventory jellyfin.yml --vault-password-file=~/.ssh/ansible_key.key
```

## Code Style
- Use YAML with 2-space indentation, no line length limits (yamllint configured)
- Start all files with `---` YAML document separator
- Use `ansible.builtin.` prefix for core modules, community collections for others
- Variable files encrypted with Ansible Vault (vars/proxmox_vars.yml)
- Use descriptive task names with proper capitalization
- Group related tasks with tags for selective execution
- Use block/when constructs for conditional task groups
- Handlers for service restarts and state changes
- Comments for complex configurations (especially LXC mappings)