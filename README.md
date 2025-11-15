# Ansible Playbooks

**Consolidated repository for managing dotfiles, shell configurations, and system setup across all environments.**

This is the central automation repository that replaces the old `ansible-roles/` and consolidates content from `mac-dev-playbook/`. It provides:
- ✅ Modern shell configuration (zinit, Starship, modern tools)
- ✅ macOS system preferences and applications
- ✅ Server base configuration (packages, Docker, users)
- ✅ DRY architecture with 4 shared roles
- ✅ Clear organization by platform (mac/, wsl/, servers/)

## Quick Start

### Personal Mac

```bash
cd ~/ansible-playbooks  # Or wherever you cloned this repo
ansible-galaxy install -r requirements.yml
ansible-playbook playbooks/mac/personal.yml -i inventories/localhost -K
```

### Work Mac

```bash
ansible-galaxy install -r requirements.yml
ansible-playbook playbooks/mac/work.yml -i inventories/localhost -K
```

### WSL

```bash
ansible-playbook playbooks/wsl/setup.yml
exec zsh
```

### Servers

```bash
# Base system (packages, Docker, users)
ansible-playbook playbooks/servers/base.yml -i inventories/servers.yml

# Modern shell
ansible-playbook playbooks/servers/shell.yml -i inventories/servers.yml
```

## Repository Structure

```
ansible-playbooks/
├── roles/                 # Shared roles (DRY)
│   ├── common-shell/      # Modern shell (all platforms)
│   ├── mac-system/        # macOS preferences & fonts
│   ├── app-config/        # Application configs (Sublime, iTerm, Vim)
│   └── server-base/       # Base server setup
│
├── playbooks/             # Platform-specific playbooks
│   ├── mac/
│   │   ├── personal.yml   # Personal Mac
│   │   ├── work.yml       # Work Mac
│   │   └── vars/          # Variable files
│   ├── wsl/
│   │   └── setup.yml      # WSL setup
│   └── servers/
│       ├── base.yml       # Base server config
│       ├── shell.yml      # Shell setup
│       └── vars/          # Server variables
│
├── tasks/                 # Shared task files
│   ├── mac/               # Mac-specific tasks
│   └── common/            # Common tasks
│
├── inventories/           # Inventory examples
│   ├── localhost          # Local machine
│   └── servers-example.yml # Server inventory template
│
├── docs/                  # Documentation
│   ├── PLAYBOOKS.md       # Playbook usage reference
│   └── ROLES.md           # Role documentation
│
├── tests/                 # Testing infrastructure
│   ├── docker/            # Docker test containers
│   ├── scripts/           # Validation scripts
│   ├── inventories/       # Test inventories
│   ├── README.md          # Complete testing guide
│   └── mac-validation-checklist.md
│
├── .github/workflows/     # CI/CD automation
│   └── test-playbooks.yml # GitHub Actions workflow
│
├── requirements.yml       # Galaxy dependencies
├── ansible.cfg            # Ansible configuration
├── Makefile               # Testing & deployment commands
└── README.md              # This file
```

## Testing

Complete Docker-based testing infrastructure with CI/CD automation.

### Quick Testing

```bash
# Run syntax validation
make test-syntax

# Run complete Docker test suite
make test

# Test specific components
make test-wsl           # Test WSL playbook
make test-server        # Test server playbooks
make test-idempotency   # Verify idempotency
```

### Mac Testing

Mac playbooks require manual testing on actual Mac hardware:

```bash
# Check mode (dry run)
make mac-personal-check

# Apply playbook
make mac-personal
```

See `tests/mac-validation-checklist.md` for complete Mac testing procedures.

### Testing Documentation

- **[tests/README.md](tests/README.md)** - Complete testing guide (Docker, CI/CD, validation)
- **[tests/mac-validation-checklist.md](tests/mac-validation-checklist.md)** - Mac testing procedures
- **[Makefile](Makefile)** - 25+ convenient testing and deployment commands

## What's New

**Consolidated from**:
- `ansible-roles/` → Renamed to `ansible-playbooks/`
- `mac-dev-playbook/` → Content extracted into roles and playbooks
- Infra integration via shared roles

**New Roles**:
- `mac-system` - macOS system preferences and fonts
- `app-config` - Application configurations
- `server-base` - Base server setup

**New Playbooks**:
- `playbooks/mac/personal.yml` - Replaces `mac-dev-playbook/main.yml`
- `playbooks/mac/work.yml` - Work laptop with pro profile
- `playbooks/servers/base.yml` - Server base configuration

## Features

### Modern Shell

- **Zinit** plugin manager (3-4x faster than OMZ framework)
- **Starship** prompt with machine-type differentiation
- **Modern tools**: fzf, zoxide, ripgrep, bat, eza, fd
- **Auto-detection** of machine type by hostname
- **Profiles**: personal, pro, server, wsl

### Machine Type Indicators

| Type | Character | Color | Use Case |
|------|-----------|-------|----------|
| Laptop (personal) | λ | Blue | Personal development |
| Laptop (work) | λ | Cyan | Work development |
| Production | ! | Red | Critical servers |
| Dev Server | · | Orange | Development servers |
| Gaming | · | Purple | Gaming servers |
| Homelab | · | Cyan | Home lab servers |

### DRY Architecture

One definition, multiple uses:
- `common-shell` role used by Mac, WSL, and server playbooks
- `server-base` role used by infra and standalone playbooks
- No duplication of shell setup or system configuration

## Documentation

### Playbook & Role Documentation
- **[PLAYBOOKS.md](docs/PLAYBOOKS.md)** - Playbook usage guide
- **[ROLES.md](docs/ROLES.md)** - Role documentation

### Testing & Deployment
- **[tests/README.md](tests/README.md)** - Complete testing guide
- **[tests/mac-validation-checklist.md](tests/mac-validation-checklist.md)** - Mac testing procedures

## Requirements

- Ansible 2.9+
- Git
- Supported platforms: macOS, Debian/Ubuntu, RHEL/CentOS

## Installation

```bash
# Clone if needed
cd ~
git clone <repo-url> ansible-playbooks
cd ansible-playbooks

# Install dependencies
ansible-galaxy install -r requirements.yml

# Run playbook for your platform
ansible-playbook playbooks/<platform>/<playbook>.yml
```

## Common Tasks

### Update Dependencies

```bash
ansible-galaxy install -r requirements.yml --force
```

### Dry Run (Check Mode)

```bash
ansible-playbook playbooks/mac/personal.yml -i inventories/localhost -K --check
```

### Run Specific Tags

```bash
# Only shell configuration
ansible-playbook playbooks/mac/personal.yml -i inventories/localhost -K --tags shell

# Only macOS system settings
ansible-playbook playbooks/mac/personal.yml -i inventories/localhost -K --tags osx,system
```

### Verbose Output

```bash
ansible-playbook playbooks/mac/personal.yml -i inventories/localhost -K -vv
```

## Customization

### Variables

Edit variable files to customize installations:
- `playbooks/mac/vars/personal.yml` - Personal Mac settings
- `playbooks/mac/vars/work.yml` - Work Mac settings
- `playbooks/servers/vars/defaults.yml` - Server defaults

### Inventory

Copy and customize inventory files:
```bash
cp inventories/servers-example.yml inventories/servers.yml
vim inventories/servers.yml  # Add your servers
```

## Integration

This repository integrates with:
- **mac-playbook-work** - Work-specific configs (private repo)
- **infra/ansible** - Server infrastructure automation
- **dotfiles** - Shell configuration files

See [INTEGRATION.md](docs/INTEGRATION.md) for details.

## Contributing

When adding new roles or playbooks:
1. Follow existing structure and conventions
2. Add comprehensive documentation
3. Use tags for selective execution
4. Ensure idempotency (safe to run multiple times)
5. Test on clean system before committing

## Deployment

Recommended order for deploying to your machines:
1. **WSL** - Low risk, clean environment
2. **Old MacBook** - Test macOS deployment
3. **Servers** - Gradual rollout
4. **Work Laptop** - Last, highest risk (backup first!)

## License

MIT

---

**Last Updated**: 2025-01-14
