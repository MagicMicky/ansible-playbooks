# Testing Guide

Comprehensive testing infrastructure for Ansible playbooks with **full isolation**, **security validation**, and **performance tracking**.

---

## Table of Contents

- [Overview](#overview)
- [Quick Start](#quick-start)
- [Test Architecture](#test-architecture)
- [Docker Testing](#docker-testing)
- [Test Scripts](#test-scripts)
- [Mac Testing](#mac-testing)
- [CI/CD Integration](#cicd-integration)
- [Performance Tracking](#performance-tracking)
- [Makefile Commands](#makefile-commands)
- [Troubleshooting](#troubleshooting)

---

## Overview

This testing infrastructure provides safe, reproducible testing of Ansible playbooks before deployment to real machines.

**Key Features**:
- **Container Isolation**: Each playbook runs in dedicated Docker container (no state pollution)
- **Comprehensive Validation**: 19 tests covering security, performance, profile isolation
- **macOS CI Testing**: GitHub Actions macOS runners for native Mac playbook testing
- **Performance Tracking**: Automatic shell startup time measurement with regression detection
- **Test Helper Library**: Reusable assertions reduce boilerplate by ~30%
- **GitHub Actions CI/CD**: Automated testing on every push/PR

**What Is Tested**:
- ✅ WSL playbook (`playbooks/wsl/setup.yml`) - Docker + CI
- ✅ Server playbooks (`playbooks/servers/*.yml`) - Docker + CI
- ✅ Mac personal playbook (`playbooks/mac/personal.yml`) - GitHub Actions macOS runner
- ✅ Security validation (permissions, secrets detection)
- ✅ Profile isolation (no cross-contamination)
- ✅ Configuration content validation
- ✅ Performance regression detection

**Test Count**: 19 tests total (WSL: 9, Server: 9, Syntax: 1)

---

## Quick Start

### Prerequisites

```bash
# Install Docker and Docker Compose
# macOS (via Homebrew)
brew install --cask docker

# Ubuntu/Debian/WSL
sudo apt-get update
sudo apt-get install docker.io docker-compose-plugin

# Verify installation
docker --version
docker compose version
```

### Understanding the Test Commands

**IMPORTANT**: Test commands fall into different categories:

| Command Type | Container Behavior | Use When |
|--------------|-------------------|----------|
| `make test` | Starts → Tests → **Stops** | Full validation before deployment |
| `make test-syntax` | **No containers** | Quick syntax check |
| `make test-wsl` | Starts → **Leaves running** | Testing specific playbook |
| `make test-docker-shell` | Enters container | Debugging test issues |
| `make clean` | **Stops & removes** | Cleanup after testing |

**Key Differences**:

- **`test-syntax`**: Fast, no Docker, just validates YAML syntax
- **`test`** (alias for `test-all`): Full suite, automatically cleans up
- **`test-wsl`**, **`test-server`**: Individual playbook tests, containers stay running for debugging
- **`test-idempotency`**: Runs playbook TWICE, ensures 2nd run makes no changes
- **`test-shell-validation`**: Checks installed tools, startup time, config files
- **`test-docker-shell`**: Opens interactive bash for manual debugging

### Running Tests (Using Makefile)

The easiest way to run tests is using the provided Makefile:

```bash
# Show all available commands (with categories)
make help

# Recommended: Full test suite (cleans up automatically)
make test                     # All 19 tests (~10-15 min)

# Quick syntax check (no Docker needed)
make test-syntax              # Fast (~10s)

# Individual tests (containers stay running for debugging)
make test-wsl                 # Apply WSL playbook in container
make test-server              # Apply server playbook
make test-idempotency-wsl     # Verify WSL idempotency
make test-idempotency-server  # Verify server idempotency
make test-validation-wsl      # Check WSL shell config
make test-validation-server   # Check server shell config
make test-performance-wsl     # Track WSL startup time
make test-performance-server  # Track server startup time
make test-profile-isolation-wsl    # Verify WSL profile isolation
make test-config-content-wsl       # Validate WSL config content

# Debugging
make test-shell               # Open zsh in WSL container
make test-shell-server        # Open zsh in server container
make test-visual              # Apply playbook + open shell (WSL)
make clean                    # Stop and remove all containers
```

## Test Architecture

### Container Isolation

Each playbook runs in its own Docker container to **prevent state pollution**:

```
wsl-test container        server-test container
┌─────────────────┐      ┌─────────────────┐
│ WSL Playbook    │      │ Server Playbook │
│ + 8 validations │      │ + 8 validations │
└─────────────────┘      └─────────────────┘
         │                        │
         └────────┬───────────────┘
                  │
          ┌───────▼───────┐
          │ Syntax Check  │
          │   (1 test)    │
          └───────────────┘
```

### Test Suite (19 Tests)

**Phase 1: Syntax Validation** (1 test)
- YAML syntax check for all playbooks

**Phase 2: WSL Playbook Tests** (9 tests)
1. Check mode execution
2. Apply mode execution
3. Shell validation (tools, startup)
4. Idempotency verification
5. Security validation
6. Tool version verification
7. Profile isolation
8. Configuration content
9. **Performance tracking**

**Phase 3: Server Playbook Tests** (9 tests)
Same as WSL but for server environment

### Manual Testing Workflow

```bash
# 1. Navigate to ansible-playbooks directory
cd ~/Development/terminal_improvements/ansible-playbooks

# 2. Install dependencies
ansible-galaxy install -r requirements.yml

# 3. Build Docker test containers
cd tests/docker
docker compose build

# 4. Start containers
docker compose up -d

# 5. Run tests inside container
docker compose exec ubuntu-test ./tests/scripts/run-all-tests.sh

# 6. Stop containers when done
docker compose down
```

---

## Docker Testing

### Container Architecture

Three specialized containers for different testing scenarios:

| Container | Purpose | Environment Variables |
|-----------|---------|----------------------|
| `ubuntu-test` | General Ubuntu testing | Standard Ubuntu 22.04 |
| `wsl-test` | WSL playbook simulation | `WSL_DISTRO_NAME=Ubuntu-22.04` |
| `server-test` | Server playbook testing | `hostname=dev-test-01` |

### Docker Files

**Dockerfile.ubuntu** (`tests/docker/Dockerfile.ubuntu`):
- Base: Ubuntu 22.04
- Includes: Python3, Ansible, git, zsh, sudo, build-essential
- Test user: `testuser` with passwordless sudo

**docker-compose.yml** (`tests/docker/docker-compose.yml`):
- Orchestrates all three test containers
- Mounts repository to `/ansible` in containers
- Keeps containers running for repeated test execution

### Using Docker Containers

```bash
# Start containers
cd tests/docker
docker compose up -d

# Execute commands in containers
docker compose exec ubuntu-test bash                  # Interactive shell
docker compose exec -T wsl-test <command>            # Run command directly

# Test specific playbook
docker compose exec wsl-test ansible-playbook playbooks/wsl/setup.yml -i tests/inventories/wsl.yml

# Check container logs
docker compose logs ubuntu-test

# Stop containers
docker compose down

# Rebuild containers (after Dockerfile changes)
docker compose build --no-cache
```

---

## Test Scripts

All test scripts located in `tests/scripts/` and executable.

### 1. validate-syntax.sh

Validates syntax of all Ansible playbooks.

```bash
# Usage
./tests/scripts/validate-syntax.sh

# What it does
# - Finds all *.yml files in playbooks/
# - Runs ansible-playbook --syntax-check on each
# - Reports PASS/FAIL for each playbook
# - Exits with non-zero status if any fail
```

### 2. validate-shell.sh

Validates shell configuration after playbook execution.

```bash
# Usage (run inside container after applying playbook)
./tests/scripts/validate-shell.sh

# What it checks
# 1. Shell Startup: Verifies zsh starts without errors (detects path issues)
# 2. Essential Tools: starship, fzf, zoxide, ripgrep
# 3. Laptop Tools: bat, eza, fd (optional, if not server profile)
# 4. Starship Configuration: ~/.config/starship.toml exists
# 5. Zinit Installation: ~/.local/share/zinit/zinit.git/ exists
# 6. Zsh Configuration: ~/.zshrc exists and is readable
# 7. Dotfiles Content: Verifies dotfiles directory is accessible
#    - Resolves symlink to find dotfiles location
#    - Checks core/*.zsh files exist
#    - Verifies profiles/ directory structure
#    - Confirms starship config in dotfiles
```

**Key Feature**: Section 7 (Dotfiles Content) is critical for detecting path resolution issues. It verifies that the dynamically resolved `DOTFILES_DIR` actually contains the expected files, preventing "no matches found" errors that occur when paths are misconfigured.

### 3. test-playbook.sh

Generic playbook test runner with timing.

```bash
# Usage
./tests/scripts/test-playbook.sh <playbook> <inventory> [--check]

# Examples
./tests/scripts/test-playbook.sh playbooks/wsl/setup.yml tests/inventories/wsl.yml
./tests/scripts/test-playbook.sh playbooks/servers/base.yml tests/inventories/ubuntu.yml --check

# What it does
# - Validates playbook and inventory exist
# - Runs playbook with verbose output (-vv)
# - Reports execution time
# - Exits with playbook's exit status
```

### 4. test-idempotency.sh

Tests playbook idempotency (no changes on second run).

```bash
# Usage
./tests/scripts/test-idempotency.sh <playbook> <inventory>

# Example
./tests/scripts/test-idempotency.sh playbooks/wsl/setup.yml tests/inventories/wsl.yml

# What it does
# - Runs playbook twice
# - Verifies second run has changed=0
# - PASSES if no changes on second run
# - FAILS if changes detected
```

### 5. check-tools.sh

Lists installed tools and their versions.

```bash
# Usage
./tests/scripts/check-tools.sh

# What it shows
# - Essential tools (git, zsh, starship, fzf, zoxide, ripgrep)
# - Development tools (bat, eza, fd)
# - Server tools (docker, docker-compose)
# - Build tools (make, gcc, curl, wget)
# - Configuration files status
```

### 6. run-all-tests.sh

Master test runner - executes complete test suite.

```bash
# Usage
./tests/scripts/run-all-tests.sh

# Test sequence
# 1. Install Ansible dependencies
# 2. Syntax validation
# 3. WSL playbook (check mode)
# 4. WSL playbook (apply)
# 5. Server shell playbook (check mode)
# 6. Server shell playbook (apply)
# 7. Idempotency test
# 8. Shell validation
# 9. Tools check

# Exit status
# - 0: All tests passed
# - 1: One or more tests failed
```

---

## Test Inventories

Located in `tests/inventories/`.

### ubuntu.yml

Standard Ubuntu environment for general testing.

```yaml
all:
  hosts:
    localhost:
      ansible_connection: local
      ansible_python_interpreter: /usr/bin/python3
  vars:
    configure_homebrew: false
    ansible_user: testuser
    ansible_become: yes
```

### wsl.yml

WSL environment simulation with WSL-specific variables.

```yaml
all:
  hosts:
    localhost:
      ansible_connection: local
  vars:
    shell_profile: wsl
    # WSL_DISTRO_NAME set via docker-compose environment
```

### servers.yml

Multiple server types for machine detection testing.

```yaml
all:
  children:
    production_servers:
      hosts:
        prod-web-01:
          expected_prompt_char: "!"
          expected_prompt_color: red
    dev_servers:
      hosts:
        dev-test-01:
          expected_prompt_char: "·"
          expected_prompt_color: orange
```

---

## Mac Testing

Mac playbooks cannot be fully tested in Docker. Use the manual validation checklist.

### Mac Validation Process

1. **Read the checklist**: `tests/mac-validation-checklist.md`
2. **Backup**: Create Time Machine backup
3. **Check mode**: Run playbook with `--check` flag
4. **Apply**: Run playbook on test Mac (old MacBook recommended)
5. **Validate**: Follow checklist steps to verify all changes
6. **Test idempotency**: Run playbook second time, verify no changes

### Quick Mac Commands

```bash
# Personal Mac (check mode)
ansible-playbook playbooks/mac/personal.yml -i inventories/localhost -K --check

# Personal Mac (apply)
ansible-playbook playbooks/mac/personal.yml -i inventories/localhost -K

# Work Mac (check mode)
ansible-playbook playbooks/mac/work.yml -i inventories/localhost -K --check

# Work Mac (apply)
ansible-playbook playbooks/mac/work.yml -i inventories/localhost -K
```

### What to Validate on Mac

- Shell startup time (<100ms target)
- Starship prompt rendering (λ character, correct color)
- Modern tools installed (starship, fzf, zoxide, bat, eza, fd)
- Homebrew packages installed
- macOS preferences applied (Dock, Finder, Trackpad, etc.)
- Application configs (Sublime, iTerm2, Vim)
- Git configuration
- Work-specific tools (work Mac only: terraform, kubectl, helm, k9s)

See `tests/mac-validation-checklist.md` for complete checklist.

---

## CI/CD Integration

### GitHub Actions Workflow

**File**: `.github/workflows/test-playbooks.yml`

Runs automatically on:
- Push to `main` or `develop` branches
- Pull requests to `main` or `develop`
- Manual trigger via GitHub UI

**Jobs**:
1. **syntax-check**: Validates all playbook syntax
2. **ansible-lint**: Runs ansible-lint for best practices
3. **test-ubuntu**: Tests WSL and server playbooks in Ubuntu
4. **test-idempotency**: Verifies playbooks are idempotent
5. **summary**: Aggregates results and reports pass/fail

**Viewing Results**:
- Go to repository on GitHub
- Click "Actions" tab
- View workflow runs and logs

### Handling Private Roles in CI

**Important**: The `work-tasks` role is a **private repository** and cannot be accessed by GitHub Actions.

**How we handle this**:
- All Galaxy dependency installations use `--ignore-errors` flag
- This allows private repos to fail gracefully without breaking CI
- CI only tests public playbooks (`wsl/setup.yml`, `servers/*.yml`)
- Work playbook (`mac/work.yml`) is NOT tested in CI (requires manual testing)

**Why it doesn't fail locally**:
- Your local machine has SSH keys configured to access private repos
- When you run `make test-syntax` or other commands, Galaxy can install work-tasks successfully

**Tested in CI**:
- ✅ WSL playbook
- ✅ Server playbooks
- ✅ Syntax validation (skips work.yml if role missing)

**NOT tested in CI** (manual testing required):
- ❌ Work playbook (`mac/work.yml`) - requires private work-tasks role

### Pre-commit Hooks

**File**: `.pre-commit-config.yaml`

Runs automatically before every git commit (after setup).

**Setup**:
```bash
# Install pre-commit
pip install pre-commit

# Install hooks
pre-commit install

# Run manually on all files
pre-commit run --all-files
```

**Hooks**:
- Trailing whitespace removal
- End-of-file fixer
- YAML validation
- YAML linting (yamllint)
- Ansible linting (ansible-lint)
- Shell script linting (shellcheck)
- Markdown linting

**Bypass** (not recommended):
```bash
git commit --no-verify -m "message"
```

---

## Makefile Commands

Convenient commands for testing and deployment.

### Testing Commands

```bash
make help                  # Show all available commands
make test                  # Run complete test suite
make test-syntax           # Syntax validation only
make test-docker-build     # Build Docker containers
make test-docker-up        # Start Docker containers
make test-docker-down      # Stop Docker containers
make test-docker-shell     # Open shell in ubuntu-test container
make test-wsl              # Test WSL playbook
make test-server           # Test server playbooks
make test-idempotency      # Test idempotency
make test-shell            # Validate shell configuration
make lint                  # Run ansible-lint
make lint-fix              # Run pre-commit hooks
make clean                 # Clean up test containers and artifacts
```

### Deployment Commands

```bash
make deps                  # Install Ansible Galaxy dependencies
make install               # Install pre-commit hooks

# Mac playbooks
make mac-personal-check    # Check mode for personal Mac
make mac-personal          # Apply personal Mac playbook
make mac-work-check        # Check mode for work Mac
make mac-work              # Apply work Mac playbook

# WSL playbook
make wsl-setup             # Apply WSL setup

# Server playbooks (requires INVENTORY variable)
make server-base INVENTORY=path/to/inventory
make server-shell INVENTORY=path/to/inventory
```

### Documentation Commands

```bash
make docs                  # Open documentation
make status                # Show project status
```

---

## Troubleshooting

### Docker Container Issues

**Problem**: Containers won't start

```bash
# Check Docker is running
docker ps

# View container logs
cd tests/docker
docker compose logs ubuntu-test

# Rebuild containers
docker compose build --no-cache
docker compose up -d
```

**Problem**: Permission errors in container

```bash
# Containers run as testuser by default
# Check file permissions in mounted volume
ls -la /ansible

# If needed, change ownership on host
sudo chown -R $USER:$USER .
```

**Problem**: Ansible not found in container

```bash
# Rebuild container (Ansible should be in Dockerfile)
cd tests/docker
docker compose build --no-cache ubuntu-test
```

### Playbook Test Failures

**Problem**: Playbook fails in check mode but not documented

```bash
# Run with increased verbosity
ansible-playbook <playbook> -i <inventory> --check -vvv

# Check for:
# - Missing variables
# - Incorrect inventory settings
# - Role dependencies not installed
```

**Problem**: Idempotency test fails

```bash
# Identify which tasks changed on second run
ansible-playbook <playbook> -i <inventory> -vv | grep changed

# Common causes:
# - Templates with timestamps
# - Commands without "creates" or "changed_when"
# - File permissions not properly set
# - Git clones without version pinning
```

**Problem**: Shell validation fails

```bash
# Check what failed
./tests/scripts/validate-shell.sh

# Common issues:
# - Tool not installed (check role tasks)
# - Configuration file missing (check role templates)
# - Shell startup time too slow (profile plugin loading)
# - Dotfiles path resolution errors (see below)
```

**Problem**: Dotfiles path resolution errors ("no matches found")

This typically manifests as:
```
/home/testuser/.zshrc:10: no matches found: /home/testuser/Development/dotfiles/zsh/core/*.zsh
```

**Root Cause**: The `.zshrc` cannot find the dotfiles directory.

**How It Works**:
1. Ansible creates symlink: `~/.zshrc` → `{{ dotfiles_repo }}/zsh/.zshrc`
2. Shell sources `~/.zshrc` which resolves its own location via symlink
3. `.zshrc` determines `DOTFILES_DIR` dynamically (not hardcoded)
4. All config files are sourced from `$DOTFILES_DIR/zsh/core/*.zsh`

**Validation**:
```bash
# Check symlink exists
ls -la ~/.zshrc
# Expected: ~/.zshrc -> /path/to/dotfiles/zsh/.zshrc

# Verify dotfiles directory exists
readlink -f ~/.zshrc | xargs dirname | xargs dirname
# Expected: /home/testuser/dotfiles-test (in tests)
# Expected: /home/user/Development/dotfiles (production)

# Check core files exist
DOTFILES=$(readlink -f ~/.zshrc | xargs dirname | xargs dirname)
ls -la $DOTFILES/zsh/core/
# Expected: 6 .zsh files (00-detect.zsh through 40-functions.zsh)

# Test shell startup manually
zsh -i -c 'echo "DOTFILES_DIR=$DOTFILES_DIR"'
# Should show resolved path, not error
```

**Debugging**:
```bash
# Inside container/test environment
docker compose exec wsl-test bash

# Check what ansible created
ls -la /home/testuser/.zshrc
ls -la /home/testuser/dotfiles-test/

# Test .zshrc directly
su - testuser
zsh -i

# If you see "ERROR: Dotfiles directory not found"
# - Verify ansible cloned/copied dotfiles
# - Check dotfiles_repo variable in inventory
# - Verify symlink target matches actual location
```

**Why Tests Previously Missed This**:
- Old validation script had `|| echo "0:00.00"` fallback
- This masked shell startup errors
- New validation (Section 7) explicitly checks dotfiles content
- New error detection catches "no matches found" messages

**Fixed in**: Shell validation v2 (with dotfiles content checks)

### CI/CD Issues

**Problem**: GitHub Actions failing

```bash
# View logs on GitHub:
# Repository → Actions → Failed workflow → Click job → View logs

# Common causes:
# - Syntax errors in playbooks
# - ansible-lint warnings elevated to errors
# - Missing dependencies in requirements.yml
# - Ubuntu package installation failures
```

**Problem**: Pre-commit hooks failing

```bash
# See what failed
pre-commit run --all-files

# Fix specific hook
pre-commit run ansible-lint --all-files

# Skip temporarily (not recommended)
git commit --no-verify
```

### Performance Issues

**Problem**: Shell startup time too slow

```bash
# Measure startup time
time zsh -i -c exit

# Profile zinit plugins
zinit times

# Disable heavy plugins in profile config
# Edit: roles/common-shell/templates/zshrc.j2
```

**Problem**: Tests take too long

```bash
# Run specific tests instead of full suite
make test-syntax           # Fast (~10s)
make test-wsl             # Medium (~2min)
make test-all             # Slow (~5min)

# Skip idempotency tests during development
./tests/scripts/test-playbook.sh <playbook> <inventory> --check
```

---

## Testing Best Practices

### Before Committing Code

1. Run syntax validation: `make test-syntax`
2. Run pre-commit hooks: `pre-commit run --all-files`
3. Test affected playbooks: `make test-wsl` or `make test-server`
4. Review verbose output for warnings

### Before Deploying to Real Machines

1. Run complete test suite: `make test`
2. Review GitHub Actions results (if pushed)
3. Test on lowest-risk machine first (WSL or old Mac)
4. Run playbook in check mode on target machine
5. Apply playbook with verbose output
6. Validate using appropriate checklist

### Development Workflow

```bash
# 1. Make changes to playbook or role
vim roles/common-shell/tasks/main.yml

# 2. Test syntax
make test-syntax

# 3. Test in Docker
make test-docker-build
make test-wsl

# 4. Review output
docker compose -f tests/docker/docker-compose.yml logs ubuntu-test

# 5. Iterate until tests pass

# 6. Run pre-commit hooks
pre-commit run --all-files

# 7. Commit
git add .
git commit -m "feat: update common-shell role"

# 8. Push (triggers CI/CD)
git push
```

---

## Performance Tracking

The testing infrastructure includes automatic shell startup performance tracking with regression detection.

### Using Performance Tracking

```bash
# Track performance in containers (saves to history)
make test-performance-wsl
make test-performance-server

# View performance history
make test-performance-history

# Check performance without saving
cd tests/docker
docker compose exec wsl-test /ansible/tests/scripts/track-performance.sh --check-only
```

### Performance Metrics

- **Measurement**: 5 runs, average
- **Container baseline**: <200ms
- **Native baseline**: <100ms
- **Regression threshold**: >20% over baseline triggers failure
- **History format**: JSON file in `tests/test-results/perf-history.json`

### Investigating Regressions

```bash
# Inside container after playbook applied
zsh -i -c 'time source ~/.zshrc'  # Measure startup
zinit times                        # Show plugin load times
```

Common causes:
- Heavy plugins added
- Network operations in init
- Compilation issues with zinit

---

## Performance Benchmarks

### Expected Test Times

| Test | Duration | Notes |
|------|----------|-------|
| Syntax validation | 5-10s | Fast, no containers |
| Docker build | 1-2min | First build only, cached after |
| WSL playbook test | 1-3min | Includes tool installations |
| Server playbook test | 1-2min | Minimal profile, faster |
| Idempotency test | 2-4min | Runs playbook twice |
| Complete suite | 10-15min | All 19 tests sequentially |

### Shell Startup Targets

| Environment | Target | Baseline (Prezto) |
|-------------|--------|-------------------|
| Laptop | <100ms | 200-300ms |
| Server | <50ms | N/A |
| Container | <200ms | N/A (overhead) |

---

## Resources

- **Ansible Docs**: [Testing Strategies](https://docs.ansible.com/ansible/latest/reference_appendices/test_strategies.html)
- **Docker Docs**: [Docker Compose](https://docs.docker.com/compose/)
- **Ansible Lint**: [Documentation](https://ansible-lint.readthedocs.io/)
- **Pre-commit**: [Framework](https://pre-commit.com/)
- **GitHub Actions**: [Workflow Syntax](https://docs.github.com/en/actions/reference/workflow-syntax-for-github-actions)

---

**Testing Infrastructure Status**: ✅ Complete (Phase 3 in progress)

**Test Count**: 19 tests (WSL: 9, Server: 9, Syntax: 1)

**Last Updated**: 2025-11-16

For deployment procedures, see `STATUS.md` and main `README.md`.
For improvement roadmap, see `TESTING_IMPROVEMENTS.md`.
