# Inventories

This directory contains Ansible inventory files for different environments.

## Files

- **localhost** - Local machine inventory (for Mac and WSL deployments)
- **servers-example.yml** - Example server inventory (copy to `servers.yml` and customize)

## Usage

### Local Deployments (Mac/WSL)

```bash
# Personal Mac
ansible-playbook playbooks/mac/personal.yml -i inventories/localhost -K

# Work Mac
ansible-playbook playbooks/mac/work.yml -i inventories/localhost -K

# WSL
ansible-playbook playbooks/wsl/setup.yml -i inventories/localhost
```

### Server Deployments

```bash
# Copy example and customize
cp inventories/servers-example.yml inventories/servers.yml
vim inventories/servers.yml  # Add your servers

# Deploy to all servers (full setup)
ansible-playbook playbooks/servers/setup.yml -i inventories/servers.yml

# Deploy to specific group
ansible-playbook playbooks/servers/setup.yml -i inventories/servers.yml --limit homelab

# Deploy shell only (skip base system setup)
ansible-playbook playbooks/servers/setup.yml -i inventories/servers.yml -e configure_server_base=false
```

## Inventory Structure

### Groups

- **production** - Production servers (critical, high-alert)
- **development** - Dev/staging servers
- **homelab** - Home lab servers
- **gaming** - Gaming servers

### Host Variables

Each host should define:
- `ansible_host` - IP address or hostname
- `machine_type` - Determines shell prompt character and color
  - `prod` → Red ! (production)
  - `dev-server` → Orange · (development)
  - `homelab-server` → Cyan · (homelab)
  - `gaming-server` → Purple · (gaming)

## Security Notes

- **Do not commit** `servers.yml` with production IPs to public repositories
- Keep server inventories in private infrastructure repositories
- Use SSH key authentication (no passwords in inventory)
- Consider using Ansible Vault for sensitive variables
