# Roles Documentation

Complete reference for all shared roles in the `ansible-playbooks/` repository.

## Table of Contents

- [Overview](#overview)
- [common-shell](#common-shell)
- [mac-system](#mac-system)
- [app-config](#app-config)
- [server-base](#server-base)
- [Creating Custom Roles](#creating-custom-roles)

---

## Overview

The consolidated repository provides 4 shared roles that implement the DRY principle:

| Role | Purpose | Used By |
|------|---------|---------|
| `common-shell` | Modern shell configuration (zinit, starship) | All platforms |
| `mac-system` | macOS system preferences and fonts | Mac playbooks |
| `app-config` | Application configurations (Sublime, iTerm, Vim) | Mac playbooks |
| `server-base` | Base server setup (packages, Docker, users) | Server playbooks |

All roles are idempotent and can be run multiple times safely.

---

## common-shell

**Location**: `roles/common-shell/`

### Purpose

Configures modern shell environment with:
- Zinit plugin manager (hybrid OMZ approach)
- Starship prompt with machine-type differentiation
- Modern CLI tools (fzf, zoxide, ripgrep, bat, eza, fd)
- Machine profile system (personal, work, server, wsl)

### Variables

```yaml
# Machine profile (required)
machine_profile: personal  # personal, pro, server, wsl

# Server type (optional, auto-detected from hostname when machine_profile=server)
# Options: prod, production, dev-server, gaming-server, dedicated-server, homelab, generic
# Only set manually to override auto-detection
server_type: generic

# Dotfiles configuration
dotfiles_repo: "{{ ansible_env.HOME }}/dotfiles"
dotfiles_repo_url: git@github.com:YourUsername/dotfiles.git
dotfiles_branch: main

# Tool installation (optional, defaults shown)
install_starship: true
install_fzf: true
install_zoxide: true
install_bat: true       # Heavy, skip on servers
install_eza: true       # Heavy, skip on servers
install_fd: true        # Heavy, skip on servers
install_ripgrep: true
skip_heavy_tools: false  # Set true for servers
```

### Machine Profiles

**personal** (Laptop):
- Full plugin suite (autosuggestions, syntax highlighting)
- All modern tools installed
- Blue λ prompt character
- Target startup: <100ms

**pro** (Work Laptop):
- Extends personal profile
- Adds work tools: AWS CLI, Terraform, Kubectl, Helm
- Cyan λ prompt character
- Work-specific aliases and functions

**server** (Servers):
- Minimal plugin set (performance-focused)
- Only essential tools (starship, fzf, zoxide, ripgrep)
- Auto-detects server type by hostname pattern
- Character and color vary by server type (see Server Type Detection below)
- Target startup: <50ms

**wsl** (Windows Subsystem for Linux):
- Extends laptop profile
- WSL-specific integrations (Windows path, docker)
- Blue λ prompt character

### Server Type Detection

When `machine_profile` is set to `server`, the role automatically detects the server type based on the hostname pattern. This determines the Starship prompt character and color.

**Hostname Patterns → Server Types**:

| Hostname Pattern | Server Type | Character | Color | Use Case |
|-----------------|-------------|-----------|-------|----------|
| `prod-*`, `production-*` | `prod` | `!` | Red (#FF5370) | Production servers (maximum alert) |
| `dev-*` | `dev-server` | `·` | Orange (#FFB86C) | Development servers |
| `gaming-*` | `gaming-server` | `·` | Purple (#C792EA) | Gaming servers |
| `homelab-*`, `home-*`, `nas-*` | `homelab` | `·` | Cyan (#89DDFF) | Homelab/personal servers |
| `dedicated-*`, `dedi-*` | `dedicated-server` | `·` | Coral (#F78C6C) | Dedicated servers |
| (other) | `generic` | `·` | Cyan (#89DDFF) | Generic servers |

**Examples**:
- `prod-web-01` → Production (red `!`)
- `dev-test-01` → Development (orange `·`)
- `gaming-srv-01` → Gaming (purple `·`)
- `homelab-nas-01` → Homelab (cyan `·`)

**Manual Override**: You can explicitly set `server_type` in your playbook to override auto-detection:

```yaml
roles:
  - role: common-shell
    vars:
      machine_profile: server
      server_type: prod  # Force production styling
```

**Detection Logic**: Located in `roles/common-shell/tasks/configure-shell.yml` lines 10-20. The detection runs before generating the Starship environment configuration.

### Usage Examples

**Personal laptop**:
```yaml
roles:
  - role: common-shell
    vars:
      machine_profile: personal
      dotfiles_branch: main
    tags: ['shell']
```

**Server (minimal)**:
```yaml
roles:
  - role: common-shell
    vars:
      machine_profile: server
      skip_heavy_tools: true
      install_bat: false
      install_eza: false
      install_fd: false
    tags: ['shell']
```

### Tasks

- Platform detection (macOS, Linux, WSL)
- Package manager detection (apt, brew)
- Tool installation (starship, modern tools)
- Dotfiles repository cloning/updating
- Shell configuration linking
- Zinit initialization

### Tags

- `shell` - All shell configuration
- `dotfiles` - Dotfiles management
- `tools` - Modern tool installation
- `starship` - Starship prompt

---

## mac-system

**Location**: `roles/mac-system/`

### Purpose

Configures macOS system preferences and installs fonts:
- Dock settings (size, auto-hide)
- System preferences (keyboard, Finder, appearance)
- Powerline fonts for terminal

### Variables

```yaml
# Dock settings
dock_tilesize: 45

# System preferences (all default to true)
enable_save_panel_expanded: true
disable_smart_quotes: true
disable_smart_dashes: true
disable_autocorrect: true
show_all_extensions: true
enable_dark_mode: true

# Font installation
install_powerline_fonts: true
powerline_font_repo: git@github.com:abertsch/Menlo-for-Powerline.git
fonts_dir: ~/Library/Fonts
```

### Usage Example

```yaml
roles:
  - role: mac-system
    when: ansible_os_family == "Darwin"
    tags: ['osx', 'system', 'fonts']
```

### Tasks

**osx-defaults.yml**:
- Dock tile size configuration
- Expand save dialogs by default
- Disable smart quotes/dashes
- Disable autocorrect
- Show file extensions in Finder
- Enable dark mode

**fonts.yml**:
- Clone Menlo Powerline font repo
- Install 4 font variants (regular, italic, bold, bold italic)
- Clean up temporary files

### Handlers

- `Restart Dock` - Restarts Dock to apply changes
- `Set dark mode` - Toggles dark mode via AppleScript

### Tags

- `osx` - All macOS settings
- `preferences` - System preferences
- `dock` - Dock settings
- `fonts` - Font installation
- `powerline-fonts` - Powerline fonts specifically

---

## app-config

**Location**: `roles/app-config/`

### Purpose

Configures application settings by linking to dotfiles:
- Sublime Text (keybindings, preferences)
- iTerm2 (terminal preferences)
- Vim (plugins and themes)

### Variables

```yaml
# Application toggles
configure_sublime: true
configure_iterm: true
configure_vim: true

# Dotfiles location
dotfiles_repo_local_destination: "{{ ansible_env.HOME }}/dotfiles"

# Vim script (optional)
vim_script: ~/.to_be_installed/vim/install.sh
```

### Usage Example

```yaml
roles:
  - role: app-config
    tags: ['apps', 'config']
```

### Tasks

**sublime.yml**:
- Ensure Sublime Text User directory exists
- Link keymap from dotfiles
- Link preferences from dotfiles

**iterm.yml**:
- Link iTerm2 preferences plist

**vim.yml**:
- Run vim plugin installation script

### Tags

- `apps` - All application configs
- `config` - All configurations
- `sublime` - Sublime Text only
- `iterm` - iTerm2 only
- `vim` - Vim only

---

## server-base

**Location**: `roles/server-base/`

### Purpose

Base server configuration:
- Install essential packages
- Install and configure Docker
- Create users with SSH keys
- Configure passwordless sudo

### Variables

```yaml
# User configuration
server_users:
  - name: magicmicky
    shell: /bin/zsh
    groups: ['sudo', 'docker']
    ssh_key: "ssh-rsa AAAA..."
  - name: ansible
    groups: ['docker']
    ssh_key: "ssh-ed25519 AAAA..."

# Package installation
base_packages:
  - git
  - htop
  - tar
  - zsh
  - acl
  - unzip
  - curl

# Docker
install_docker: true
docker_packages:
  - docker-ce
  - docker-ce-cli
  - containerd.io
  - docker-buildx-plugin
  - docker-compose-plugin

# Sudoers
enable_passwordless_sudo: true
```

### Usage Example

```yaml
roles:
  - role: server-base
    become: yes
    tags: ['base', 'packages', 'docker', 'users']
```

### Tasks

**packages.yml**:
- Update apt cache
- Install base packages from list

**docker.yml**:
- Install Docker prerequisites
- Add Docker GPG key and repository
- Install Docker packages
- Start and enable Docker service

**users.yml**:
- Configure passwordless sudo for sudo group
- Create users from list
- Add users to specified groups
- Create SSH directories
- Add SSH public keys

### Handlers

- `Update apt cache` - Updates apt package index
- `Restart Docker` - Restarts Docker service

### Tags

- `base` - All base configuration
- `packages` - Package installation
- `docker` - Docker installation
- `users` - User management
- `ssh` - SSH key setup

---

## Creating Custom Roles

### Directory Structure

```
roles/
└── my-custom-role/
    ├── defaults/
    │   └── main.yml      # Default variables
    ├── tasks/
    │   └── main.yml      # Main task entry point
    ├── handlers/
    │   └── main.yml      # Handlers (optional)
    ├── files/            # Static files (optional)
    ├── templates/        # Jinja2 templates (optional)
    └── vars/             # Role variables (optional)
        └── main.yml
```

### Example Role

**roles/my-custom-role/defaults/main.yml**:
```yaml
---
my_setting: default_value
enable_feature: true
```

**roles/my-custom-role/tasks/main.yml**:
```yaml
---
- name: Do something
  debug:
    msg: "Setting is {{ my_setting }}"
  when: enable_feature
```

### Using Your Role

**In a playbook**:
```yaml
---
- name: My Playbook
  hosts: localhost

  roles:
    - role: my-custom-role
      vars:
        my_setting: custom_value
      tags: ['custom']
```

### Best Practices

1. **Idempotency**: Tasks should be safe to run multiple times
2. **Defaults**: Provide sensible defaults in `defaults/main.yml`
3. **Documentation**: Add README.md to role directory
4. **Tags**: Use consistent tagging for selective execution
5. **Variables**: Prefix role variables to avoid conflicts
6. **Conditionals**: Use `when:` for optional features
7. **Testing**: Test on clean system before deploying

---

## Role Dependencies

Roles can depend on other roles. Define in `meta/main.yml`:

```yaml
---
dependencies:
  - role: common-shell
    vars:
      machine_profile: personal
```

This ensures `common-shell` runs before your role.

---

## Variable Precedence

Variables can be set in multiple places (lowest to highest priority):

1. Role defaults (`defaults/main.yml`)
2. Inventory variables
3. Playbook vars_files
4. Playbook vars
5. Role vars (`vars/main.yml`)
6. Extra vars (`-e` flag)

**Example**:
```bash
# Override via command line (highest priority)
ansible-playbook playbook.yml -e "machine_profile=server"
```

---

## Related Documentation

- **PLAYBOOKS.md** - How to use playbooks
- **INTEGRATION.md** - Integrating roles with existing playbooks
- **MIGRATION.md** - Migrating from old structure
