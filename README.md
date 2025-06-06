# proxmox-host-setup

## How to use

To run this playbook, you need to create the ansible_key to decrypt the vault and place it in a safe location.

```bash
ansible-playbook -i inventory main.yml --vault-password=~/.ssh/ansible_key.key
```

## Proxmox LXC Image Templates

Location for images: [Proxmox Images](http://download.proxmox.com/images/system/)