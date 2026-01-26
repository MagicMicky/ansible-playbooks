# Architecture Overview

This document describes the architecture of the modern shell setup across all machine types.

## Design Principles

### DRY (Don't Repeat Yourself)
- **One** `common-shell` role handles all shell setup
- **Multiple playbooks** use the same role with different variables
- **Zero duplication** of shell setup logic

### Coding Standards
All playbooks and tasks follow these conventions:
- **FQCN**: Fully Qualified Collection Names (e.g., `ansible.builtin.debug`)
- **Booleans**: Use `true`/`false` (not `yes`/`no`)
- **Variables**: Use `vars_files:` pointing to `vars/*.yml` (not inline `vars:`)
- **Defaults**: Use `| default(false)` for conditional guards
- **Loop syntax**: Use `loop:` (not `with_items:`)
- **Organization**: Platform-specific tasks live within their playbook folder

### Machine Profile System
Configuration adapts automatically based on `machine_profile`:

| Profile | Use Case | Tools | Prompt |
|---------|----------|-------|--------|
| **laptop** | Personal Mac/Linux | Full suite | Blue λ |
| **pro** | Work laptop | Full + work tools | Cyan λ |
| **server** | Remote servers | Minimal | Varies by type |
| **wsl** | Windows WSL | Full + WSL integration | Blue λ |

### Server Type Detection
When `machine_profile=server`, the hostname determines styling:

| Hostname Pattern | Type | Character | Color |
|-----------------|------|-----------|-------|
| `prod-*`, `production-*` | Production | `!` | Red |
| `dev-*` | Development | `●` | Purple |
| `gaming-*` | Gaming | `●` | Purple |
| `homelab-*`, `nas-*` | Homelab | `●` | Cyan |
| Other | Generic | `●` | Cyan |

## Repository Structure

```
terminal_improvements/
├── ansible-playbooks/     # Central automation (this repo)
│   ├── roles/
│   │   └── common-shell/  # Universal shell setup role
│   ├── playbooks/
│   │   ├── mac/           # macOS playbooks
│   │   │   ├── tasks/     # Mac-specific tasks
│   │   │   └── vars/      # Mac variables
│   │   ├── wsl/           # WSL playbooks
│   │   │   └── vars/      # WSL variables
│   │   └── servers/       # Server playbooks
│   │       └── vars/      # Server variables
│   └── tests/             # Docker-based testing
│
├── dotfiles/              # Shell configurations (public)
│   └── zsh/
│       ├── core/          # Universal configs (numbered)
│       └── profiles/      # Profile-specific configs
│
├── mac-playbook-work/     # Work-specific configs (private)
│
└── infra/                 # Infrastructure (separate concern)
```

## Playbook → Role Call Graph

Which playbooks call which roles:

```
mac/personal.yml
├── geerlingguy.mac.homebrew    # Homebrew packages & casks
├── common-shell                 # Shell setup (zinit, starship, tools)
├── mac-system                   # macOS preferences & fonts
└── app-config                   # Git + Claude configs

mac/work.yml
├── geerlingguy.mac.homebrew    # Homebrew packages & casks
├── common-shell                 # Shell setup (pro profile)
├── mac-system                   # macOS preferences & fonts
├── app-config                   # Git + Claude configs
└── work-tasks                   # Work-specific (from private repo)

wsl/setup.yml
├── common-shell                 # Shell setup (wsl profile)
└── app-config                   # Git + Claude configs

servers/base.yml
└── server-base                  # Base packages, Docker, users

servers/shell.yml
└── common-shell                 # Shell setup (server profile, minimal)
```

**Role summary**:
| Role | Platform | Purpose |
|------|----------|---------|
| `common-shell` | All | Shell config (zinit, starship, modern tools) |
| `app-config` | All | Application configs (git, claude; legacy disabled) |
| `mac-system` | macOS | System preferences, fonts |
| `server-base` | Linux | Base packages, Docker, users |
| `geerlingguy.mac.homebrew` | macOS | Package management (external) |
| `work-tasks` | macOS | Work-specific tasks (private repo) |

## Shell Configuration Flow

### Deployment (Ansible)
```
1. Ansible runs playbook (e.g., wsl/setup.yml)
2. common-shell role executes:
   - Detects platform (Linux/macOS/WSL)
   - Installs tools (starship, fzf, zoxide, zinit)
   - Clones dotfiles repo
   - Creates symlinks in ~/.zsh.d/
   - Sets machine type marker
```

### Runtime (zsh)
```
1. ~/.zshrc sources all files in ~/.zsh.d/
2. Load order (alphabetical):
   - 01-zinit.zsh    → Plugin manager
   - 10-path.zsh     → PATH setup
   - 20-env.zsh      → Environment (UTF-8 fix)
   - 25-tools.zsh    → Tool integrations
   - 30-aliases.zsh  → Universal aliases
   - 40-functions.zsh → Helper functions
   - config.zsh      → Profile config
   - overrides.zsh   → Profile overrides
   - plugins.zsh     → Profile plugins
3. Starship prompt initializes
4. fzf/zoxide initialize
```

## Modern Tool Stack

| Tool | Purpose | Install Method |
|------|---------|----------------|
| **Zinit** | Plugin manager | Git clone |
| **Starship** | Cross-shell prompt | curl installer |
| **fzf** | Fuzzy finder | Git clone |
| **zoxide** | Smart cd | curl installer |
| **bat** | Better cat | apt/brew |
| **eza** | Better ls | apt/brew |
| **fd** | Better find | apt/brew |
| **ripgrep** | Better grep | apt/brew |

## Performance Targets

| Environment | Target | Typical |
|-------------|--------|---------|
| Laptop | <100ms | 50-80ms |
| WSL | <100ms | 60-80ms |
| Server | <50ms | 30-50ms |

Measured with: `time zsh -i -c exit`

## Key Files

### Ansible
- `roles/common-shell/tasks/main.yml` - Role entry point
- `roles/common-shell/defaults/main.yml` - Default variables
- `roles/common-shell/vars/catppuccin-mocha.yml` - Theme colors

### Dotfiles
- `zsh/.zshrc` - Entry point (sources ~/.zsh.d/)
- `zsh/core/20-env.zsh` - UTF-8 locale fix (critical)
- `zsh/profiles/*/plugins.zsh` - Profile-specific plugins

## Known Issues & Fixes

### Tab Completion Bug
**Issue**: Starship caused character duplication in tab completion
**Root Cause**: Invalid UTF-8 locale during Starship init
**Fix**: `zsh/core/20-env.zsh` sets UTF-8 locale with C.UTF-8 fallback
**Reference**: https://github.com/starship/starship/issues/2176

## Testing

```bash
cd ansible-playbooks

# Syntax validation
make test-syntax

# Docker-based tests
make test-wsl      # WSL environment
make test-server   # Server environment
make test-all      # All environments
```

## Deployment

```bash
# WSL
make wsl-check     # Dry run
make wsl           # Deploy

# Mac
make mac-personal  # Personal Mac
make mac-work      # Work Mac (requires mac-playbook-work)

# Server
make server-shell INVENTORY=path/to/inventory.yml
```
