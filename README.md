# Ansible Shared Roles

Shared Ansible roles for managing shell configuration, dotfiles, and machine profiles across multiple environments (personal laptops, work laptops, servers, WSL).

## Purpose

These roles implement the DRY (Don't Repeat Yourself) principle by providing common configuration management that can be reused across:
- `mac-dev-playbook` (personal Mac setup)
- `mac-playbook-work` (work Mac setup)
- `infra/ansible` (server configurations)

## Roles

### common-shell
Universal shell setup role that handles:
- Platform detection (macOS, Linux, WSL)
- Starship prompt installation and configuration
- Modern CLI tools installation (fzf, zoxide, bat, eza, fd, ripgrep)
- Zinit plugin manager setup
- Machine type detection and configuration

**Supported Machine Profiles:**
- `personal` - Personal laptop
- `work` - Work laptop
- `server` - Servers (minimal configuration)
- `wsl` - Windows Subsystem for Linux

### dotfiles-manager
Manages dotfiles repository cloning, linking, and updates.

### machine-profile
Handles machine-specific configuration based on detected or specified profile.

## Usage

### In ansible.cfg

```ini
[defaults]
roles_path = ./roles:~/Development/ansible-roles/roles:~/.ansible/roles
```

### In Playbooks

```yaml
---
- hosts: localhost
  vars:
    machine_profile: personal
    dotfiles_repo_url: "git@github.com:USER/dotfiles.git"
    dotfiles_branch: main

  roles:
    - role: common-shell
      tags: ['shell']
```

## Variables

See individual role `defaults/main.yml` files for available variables.

## Requirements

- Ansible 2.9+
- Git
- Supported platforms: macOS, Debian/Ubuntu, RHEL/CentOS

## Directory Structure

```
ansible-roles/
├── README.md
├── requirements.yml          # External role dependencies
└── roles/
    ├── common-shell/
    │   ├── defaults/
    │   │   └── main.yml
    │   ├── tasks/
    │   │   ├── main.yml
    │   │   ├── detect-platform.yml
    │   │   ├── install-starship.yml
    │   │   ├── install-modern-tools.yml
    │   │   ├── setup-zinit.yml
    │   │   └── configure-shell.yml
    │   ├── templates/
    │   │   └── machine-detect.zsh.j2
    │   └── files/
    ├── dotfiles-manager/
    └── machine-profile/
```

## License

MIT
