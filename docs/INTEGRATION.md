# Integrating Shared Roles with Existing Playbooks

This document explains how to integrate the shared `common-shell` role with your existing Ansible playbooks.

## Architecture Overview

```
terminal_improvements/
├── ansible-roles/              # Shared roles (DRY principle)
│   ├── roles/common-shell/    # Universal shell setup
│   └── playbooks/             # Standalone playbooks
│
├── mac-dev-playbook/          # Personal Mac → uses common-shell
├── mac-playbook-work/         # Work Mac → uses common-shell
└── infra/ansible/             # Servers → uses common-shell
```

## Integration Steps

### 1. mac-dev-playbook Integration

**File: `mac-dev-playbook/ansible.cfg`**

Add or update the `roles_path`:

```ini
[defaults]
roles_path = ./roles:~/Development/terminal_improvements/ansible-roles/roles:~/.ansible/roles
inventory = inventory
nocows = 1
```

**File: `mac-dev-playbook/main.yml`**

Replace the old zsh task with the shared role:

```yaml
---
- hosts: all
  connection: local

  vars_files:
    - default.config.yml

  pre_tasks:
    - include_vars: "{{ item }}"
      with_fileglob:
        - "{{ playbook_dir }}/config.yml"
      tags: ['always']

  roles:
    - role: geerlingguy.mac.homebrew
      tags: ['homebrew']

    # NEW: Use shared common-shell role
    - role: common-shell
      vars:
        machine_profile: "{{ 'work' if configure_work else 'personal' }}"
        dotfiles_repo: "{{ ansible_env.HOME }}/Development/terminal_improvements/dotfiles"
        dotfiles_repo_url: "git@github.com:MagicMicky/dotfiles.git"
        dotfiles_branch: main  # or modern-shell-2025 for testing
      tags: ['shell', 'dotfiles']

  tasks:
    - import_tasks: tasks/vim.yml
      when: configure_vim
      tags: ['vim']

    # REMOVE: Old zsh task
    # - import_tasks: tasks/zsh.yml
    #   when: configure_zsh
    #   tags: ['zsh']

    - import_tasks: tasks/sublime.yml
      when: configure_sublime
      tags: ['sublime']

    # ... rest of tasks
```

**Commands:**

```bash
cd ~/Development/terminal_improvements/mac-dev-playbook

# Dry-run
make check

# Deploy shell configuration only
ansible-playbook main.yml --tags shell

# Full deployment
make install
```

### 2. mac-playbook-work Integration

**File: `mac-playbook-work/meta/main.yml`**

Update to use the shared role:

```yaml
---
dependencies:
  - role: common-shell
    vars:
      machine_profile: work
      dotfiles_repo: "{{ ansible_env.HOME }}/Development/terminal_improvements/dotfiles"
      dotfiles_repo_url: "git@github.com:MagicMicky/dotfiles.git"
      dotfiles_branch: main
```

**File: `mac-playbook-work/tasks/work.yml`**

Keep your sensitive work configurations here. The shared role handles the base shell setup, and this handles company-specific additions:

```yaml
---
# Company-specific work configurations
# Sensitive configs that don't belong in public dotfiles

- name: Ensure work config directory exists
  file:
    path: "{{ ansible_env.HOME }}/.zsh.d"
    state: directory

- name: Link work environment file
  file:
    src: "{{ playbook_dir }}/files/workenv.sh"
    dest: "{{ ansible_env.HOME }}/.zsh.d/zworkenv"
    state: link

# Additional company-specific tasks...
```

### 3. infra/ansible Integration

**File: `infra/ansible/ansible.cfg`**

Add the shared roles path:

```ini
[defaults]
roles_path = ./roles:~/Development/terminal_improvements/ansible-roles/roles:~/.ansible/roles
inventory = inventory.yaml
```

**File: `infra/ansible/ubuntu/shell-setup.yml`** (new file)

Create a dedicated playbook for shell setup:

```yaml
---
# Deploy modern shell to Ubuntu servers

- name: Configure Shell on Ubuntu Servers
  hosts: all
  become: no

  vars:
    machine_profile: server
    dotfiles_repo: "/opt/dotfiles"
    dotfiles_repo_url: "git@github.com:MagicMicky/dotfiles.git"
    dotfiles_branch: main

    # Minimal tools for servers
    install_starship: true
    install_fzf: true
    install_zoxide: true
    install_ripgrep: true
    skip_heavy_tools: true

  roles:
    - role: common-shell
      tags: ['shell']
```

**File: `infra/ansible/ubuntu/base.yml`** (update)

Import the shell setup:

```yaml
---
- name: Base Server Configuration
  hosts: all

  tasks:
    - import_tasks: base/packages.yml
      tags: ['packages']

    - import_tasks: base/docker.yml
      tags: ['docker']

    - import_tasks: base/users.yml
      tags: ['users']

# NEW: Import shell setup
- import_playbook: shell-setup.yml
  tags: ['shell']
```

**Commands:**

```bash
cd ~/Development/terminal_improvements/infra/ansible/ubuntu

# Deploy to specific server
ansible-playbook -i inventory.yaml shell-setup.yml --limit test-server

# Deploy to all servers
ansible-playbook -i inventory.yaml shell-setup.yml

# Just check what would change
ansible-playbook -i inventory.yaml shell-setup.yml --check
```

## Rollout Strategy

### Phase 1: WSL (Current Machine - Lowest Risk)

```bash
cd ~/Development/terminal_improvements/ansible-roles
make check-wsl    # Dry-run
make wsl          # Deploy
```

### Phase 2: Test on Old MacBook

```bash
cd ~/Development/terminal_improvements/mac-dev-playbook

# Update ansible.cfg and main.yml first
make check        # Dry-run
make install-tags shell  # Deploy shell only
```

### Phase 3: Test Server

```bash
cd ~/Development/terminal_improvements/infra/ansible/ubuntu

# Create shell-setup.yml first
ansible-playbook -i inventory.yaml shell-setup.yml --limit dev-server-01 --check
ansible-playbook -i inventory.yaml shell-setup.yml --limit dev-server-01
```

### Phase 4: All Servers (Gradual)

Roll out by server type:
1. Dev servers
2. Homelab
3. Gaming/Dedicated
4. Production (last!)

### Phase 5: Work Laptop (Highest Risk)

```bash
cd ~/Development/terminal_improvements/mac-playbook-work

# Update meta/main.yml first
# BACKUP EVERYTHING FIRST!
ansible-playbook main.yml --check
ansible-playbook main.yml
```

## Benefits of This Approach

### 1. DRY (Don't Repeat Yourself)
- Shell setup defined once in `common-shell` role
- Used by all 3 playbooks (mac-dev, mac-work, infra)
- Changes propagate everywhere automatically

### 2. Consistent Configuration
- Same modern shell across all environments
- Same Starship prompt with appropriate differentiation
- Same modern tools where appropriate

### 3. Easy Testing
- Test role changes on WSL first (low risk)
- Roll out gradually to other environments
- Easy rollback via Ansible tags

### 4. Maintainability
- Update one role instead of three playbooks
- Clear separation of concerns
- Work isolation maintained

### 5. Flexibility
- Override variables per playbook
- Skip heavy tools on servers
- Enable/disable features per environment

## Variables Reference

Key variables you can override per playbook:

```yaml
machine_profile: personal|work|server|wsl
dotfiles_repo: "/path/to/dotfiles"
dotfiles_repo_url: "git@github.com:user/dotfiles.git"
dotfiles_branch: main|modern-shell-2025

install_starship: true|false
install_fzf: true|false
install_zoxide: true|false
install_bat: true|false
install_eza: true|false
install_fd: true|false
install_ripgrep: true|false

skip_heavy_tools: true|false  # Auto-set for servers
set_default_shell: true|false
```

## Troubleshooting

### Role not found
```bash
# Check roles_path in ansible.cfg
ansible-config dump | grep ROLES_PATH

# Verify role exists
ls ~/Development/terminal_improvements/ansible-roles/roles/common-shell
```

### Dependencies not installed
```bash
# Install galaxy dependencies
ansible-galaxy install -r requirements.yml
```

### Variables not being passed
```bash
# Debug with verbose output
ansible-playbook main.yml --tags shell -vvv
```

## Next Steps

1. ✅ Test on WSL (`make wsl`)
2. Update mac-dev-playbook ansible.cfg and main.yml
3. Test on old MacBook
4. Update infra ansible
5. Test on dev server
6. Update mac-playbook-work
7. Full rollout

---

**Key Principle**: Test on low-risk environments first (WSL), then progressively roll out to higher-risk environments (work laptop last).
