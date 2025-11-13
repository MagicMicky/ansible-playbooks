# Playbooks Reference

Comprehensive guide to all playbooks in the `ansible-playbooks/` repository.

## Table of Contents

- [Mac Playbooks](#mac-playbooks)
- [WSL Playbook](#wsl-playbook)
- [Server Playbooks](#server-playbooks)
- [Common Options](#common-options)

---

## Mac Playbooks

Located in `playbooks/mac/`

### Personal Mac (`personal.yml`)

**Purpose**: Configure personal macOS machines with full development environment.

**What It Does**:
- Installs Homebrew packages and casks
- Configures modern shell (zinit, starship, modern tools)
- Sets macOS system preferences (Dock, Finder, keyboard)
- Installs and configures fonts (Menlo Powerline)
- Links application configs (Sublime Text, iTerm2, Vim)
- Installs extra packages (composer, npm, pip, gems)

**Usage**:
```bash
cd ~/Development/terminal_improvements/ansible-playbooks

# Install dependencies first
ansible-galaxy install -r requirements.yml

# Dry run (check mode)
ansible-playbook playbooks/mac/personal.yml -i inventories/localhost -K --check

# Full installation
ansible-playbook playbooks/mac/personal.yml -i inventories/localhost -K

# Run specific tags
ansible-playbook playbooks/mac/personal.yml -i inventories/localhost -K --tags shell
```

**Variables** (`playbooks/mac/vars/personal.yml`):
- `configure_*` - Feature toggles (vim, sublime, iterm, osx)
- `homebrew_installed_packages` - Packages to install
- `homebrew_cask_apps` - GUI applications to install
- `dotfiles_*` - Dotfiles repository settings

**Tags**:
- `homebrew` - Package management
- `shell`, `dotfiles` - Shell configuration
- `osx`, `system`, `fonts` - macOS system settings
- `apps`, `config` - Application configurations
- `packages`, `extra` - Extra package managers

---

### Work Mac (`work.yml`)

**Purpose**: Configure work laptop with pro profile and work-specific tooling.

**Extends**: Inherits from `personal.yml` with work additions.

**Additional Features**:
- Loads **pro** shell profile (work tools enabled)
- Installs work tools: terraform, kubectl, helm, k9s, awscli
- Imports work-specific tasks from `mac-playbook-work` repo (N26 configs)
- Work applications: Slack, Zoom, Docker

**Usage**:
```bash
cd ~/Development/terminal_improvements/ansible-playbooks

# Install dependencies (includes work-tasks role from private repo)
ansible-galaxy install -r requirements.yml

# Full installation
ansible-playbook playbooks/mac/work.yml -i inventories/localhost -K

# Skip work-specific tasks
ansible-playbook playbooks/mac/work.yml -i inventories/localhost -K --skip-tags work,n26
```

**Variables**:
- Inherits from `vars/personal.yml`
- Extends with `vars/work.yml`
- `configure_work: yes` - Enables work role
- Additional work packages and apps

**Security Note**:
- Sensitive N26 configs (env vars, credentials) stay in `mac-playbook-work/`
- Only non-sensitive work tooling in consolidated repo

---

## WSL Playbook

Located in `playbooks/wsl/setup.yml`

**Purpose**: Configure Windows Subsystem for Linux with modern shell.

**What It Does**:
- Configures modern shell with WSL-specific profile
- Installs Linux modern tools: fzf, zoxide, ripgrep
- Sets up WSL-specific aliases and integrations
- Installs Docker and WSL-specific completions

**Usage**:
```bash
cd ~/Development/terminal_improvements/ansible-playbooks

# Dry run
ansible-playbook playbooks/wsl/setup.yml --check

# Full installation
ansible-playbook playbooks/wsl/setup.yml

# Restart shell
exec zsh
```

**Variables**:
- `machine_profile: wsl` - Enables WSL-specific configs
- `dotfiles_branch: modern-shell-2025` - Branch to use

**Expected Result**:
- Blue λ prompt
- WSL integrations (Windows path, docker)
- Fast shell startup (<80ms)

---

## Server Playbooks

Located in `playbooks/servers/`

### Base Server (`base.yml`)

**Purpose**: Configure base server system (packages, Docker, users).

**What It Does**:
- Installs base packages: git, htop, zsh, curl, unzip
- Installs Docker and Docker Compose
- Creates users with SSH keys and sudo access
- Configures passwordless sudo

**Usage**:
```bash
cd ~/Development/terminal_improvements/ansible-playbooks

# Deploy to all servers
ansible-playbook playbooks/servers/base.yml -i inventories/servers.yml

# Deploy to specific group
ansible-playbook playbooks/servers/base.yml -i inventories/servers.yml --limit homelab

# Dry run
ansible-playbook playbooks/servers/base.yml -i inventories/servers.yml --check
```

**Variables** (`playbooks/servers/vars/defaults.yml`):
- `server_users` - List of users to create
- `install_docker: true` - Enable Docker installation
- `base_packages` - Packages to install

---

### Server Shell (`shell.yml`)

**Purpose**: Configure modern shell on servers (minimal, fast).

**What It Does**:
- Installs minimal modern shell (starship, fzf, zoxide)
- Skips heavy tools for performance (no bat, eza, fd)
- Auto-detects server type by hostname
- Configures server profile (minimal plugins)

**Usage**:
```bash
cd ~/Development/terminal_improvements/ansible-playbooks

# Deploy to all servers
ansible-playbook playbooks/servers/shell.yml -i inventories/servers.yml

# Deploy to production (careful!)
ansible-playbook playbooks/servers/shell.yml -i inventories/servers.yml --limit production

# Dry run first (recommended)
ansible-playbook playbooks/servers/shell.yml -i inventories/servers.yml --check
```

**Server Type Detection** (by hostname):
- `prod*`, `production*` → Red ! (production)
- `dev-*`, `staging*` → Orange · (development)
- `gaming*` → Purple · (gaming)
- `homelab*`, `home-*` → Cyan · (homelab)
- Other → Green · (generic server)

**Performance Target**: <50ms shell startup

---

## Common Options

### Ansible Flags

**Check Mode** (dry run):
```bash
--check  # Don't make changes, just show what would change
```

**Tags** (run specific parts):
```bash
--tags shell              # Only shell configuration
--tags osx,system         # Only macOS system settings
--skip-tags work          # Skip work-specific tasks
```

**Verbosity** (debugging):
```bash
-v      # Verbose
-vv     # More verbose
-vvv    # Very verbose (connection debugging)
```

**Ask Sudo Password**:
```bash
-K      # Prompt for sudo password (required for Mac playbooks)
```

**Limit Hosts**:
```bash
--limit prod-web-01      # Run on single host
--limit production       # Run on group
```

---

## Playbook Structure

All playbooks follow this pattern:

```yaml
---
- name: Playbook Name
  hosts: target
  connection: local  # or omit for remote

  vars_files:
    - vars/file.yml  # Optional

  pre_tasks:
    - name: Pre-flight checks
      # ...

  roles:
    - role: shared-role
      tags: ['tag1', 'tag2']

  tasks:
    - name: Additional tasks
      # ...

  post_tasks:
    - name: Completion message
      # ...
```

---

## Tips and Best Practices

### Before Running

1. **Backup first**: Create system backup
2. **Dry run**: Always use `--check` first
3. **Install deps**: Run `ansible-galaxy install -r requirements.yml`
4. **Check variables**: Review vars files for your needs

### During Execution

1. **Watch output**: Look for red errors
2. **Note warnings**: Yellow warnings may need attention
3. **Idempotency**: Re-running should be safe

### After Running

1. **Verify**: Check that services/tools work
2. **Restart shell**: `exec zsh` to load new config
3. **Test**: Run commands to verify (fzf, zoxide, docker, etc.)

---

## Troubleshooting

### "No such file or directory" for vars

**Problem**: Vars file missing

**Solution**:
```bash
ls playbooks/mac/vars/personal.yml
# If missing, create from example or copy from mac-dev-playbook/config.yml
```

### "Role not found"

**Problem**: Galaxy dependencies not installed

**Solution**:
```bash
cd ansible-playbooks
ansible-galaxy install -r requirements.yml --force
```

### Tasks Fail with "Permission denied"

**Problem**: Missing sudo permissions

**Solution**: Add `-K` flag and enter password when prompted

### "Dotfiles repo not found"

**Problem**: Dotfiles repo not cloned

**Solution**:
```bash
cd ~/Development/terminal_improvements
git clone git@github.com:MagicMicky/dotfiles.git
```

---

## Related Documentation

- **MIGRATION.md** - Migrating from old structure
- **ROLES.md** - Role documentation
- **INTEGRATION.md** - Integrating with existing playbooks
- **inventories/README.md** - Inventory setup
