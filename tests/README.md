# Testing Guide

**Purpose**: Guide for testing Ansible playbooks locally using Docker containers before deployment.

---

## Overview

This directory contains resources for testing Ansible playbooks in isolated Docker environments. Testing in containers allows you to validate playbooks safely before running them on real machines.

**Benefits**:
- Safe testing without affecting your actual machines
- Fast iteration during development
- Reproducible test environments
- Platform-specific testing (Ubuntu, WSL-like, etc.)

---

## Quick Start

### Prerequisites

```bash
# Install Docker
# macOS (via Homebrew)
brew install --cask docker

# Ubuntu/Debian
sudo apt-get update
sudo apt-get install docker.io docker-compose

# Verify installation
docker --version
docker-compose --version
```

### Basic Testing Workflow

```bash
# 1. Navigate to tests directory
cd ~/Development/terminal_improvements/ansible-playbooks/tests

# 2. Build test container
docker build -t ansible-test-ubuntu:latest -f Dockerfile.ubuntu .

# 3. Run container
docker run -it --rm \
  -v $(pwd)/..:/ansible \
  -w /ansible \
  ansible-test-ubuntu:latest bash

# 4. Inside container, run playbook in check mode
ansible-playbook playbooks/wsl/setup.yml --check -vv

# 5. If check passes, run for real
ansible-playbook playbooks/wsl/setup.yml -vv
```

---

## Docker Test Images

### Ubuntu Test Container

**File**: `Dockerfile.ubuntu`

```dockerfile
FROM ubuntu:22.04

# Install dependencies
RUN apt-get update && apt-get install -y \
    git \
    python3 \
    python3-pip \
    sudo \
    && rm -rf /var/lib/apt/lists/*

# Install Ansible
RUN pip3 install ansible

# Create test user
RUN useradd -m -s /bin/bash testuser && \
    echo "testuser ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

USER testuser
WORKDIR /home/testuser

CMD ["/bin/bash"]
```

**Usage**:
```bash
# Build
docker build -t ansible-test-ubuntu:latest -f tests/Dockerfile.ubuntu .

# Run playbook test
docker run -it --rm \
  -v $(pwd):/ansible \
  -w /ansible \
  ansible-test-ubuntu:latest \
  ansible-playbook playbooks/wsl/setup.yml --check
```

### macOS Simulation Container

**Note**: True macOS containers aren't possible, but we can test shell configs in Ubuntu:

```bash
# Test shell setup role
docker run -it --rm \
  -v $(pwd):/ansible \
  -w /ansible \
  ansible-test-ubuntu:latest \
  ansible-playbook playbooks/servers/shell.yml --check
```

---

## Testing Specific Playbooks

### WSL Playbook

```bash
# Full test with verbose output
docker run -it --rm \
  -v $(pwd):/ansible \
  -w /ansible \
  ansible-test-ubuntu:latest \
  ansible-playbook playbooks/wsl/setup.yml --check -vv

# Test specific tags
docker run -it --rm \
  -v $(pwd):/ansible \
  -w /ansible \
  ansible-test-ubuntu:latest \
  ansible-playbook playbooks/wsl/setup.yml --check --tags shell
```

### Server Playbooks

```bash
# Test base server setup
docker run -it --rm \
  -v $(pwd):/ansible \
  -w /ansible \
  ansible-test-ubuntu:latest \
  ansible-playbook playbooks/servers/base.yml -i tests/inventory-test.yml --check

# Test shell setup
docker run -it --rm \
  -v $(pwd):/ansible \
  -w /ansible \
  ansible-test-ubuntu:latest \
  ansible-playbook playbooks/servers/shell.yml -i tests/inventory-test.yml --check
```

### Mac Playbooks

**Note**: Mac playbooks cannot be fully tested in Docker (macOS-specific tasks will fail). Instead:

1. **Syntax validation**: Already done in Phase 6
2. **Shell role testing**: Test common-shell in Ubuntu container
3. **Real testing**: Use `--check` mode on actual Mac

```bash
# On actual Mac
cd ~/Development/terminal_improvements/ansible-playbooks
ansible-playbook playbooks/mac/personal.yml -i inventories/localhost -K --check
```

---

## Test Inventory

**File**: `tests/inventory-test.yml`

```yaml
all:
  hosts:
    test-server:
      ansible_connection: local
      ansible_user: testuser
      machine_type: server

  vars:
    ansible_python_interpreter: /usr/bin/python3
```

---

## Validation Scripts

### Syntax Check Script

**File**: `tests/validate-syntax.sh`

```bash
#!/bin/bash

set -e

echo "Validating all playbooks..."

playbooks=(
  "playbooks/mac/personal.yml"
  "playbooks/mac/work.yml"
  "playbooks/wsl/setup.yml"
  "playbooks/servers/base.yml"
  "playbooks/servers/shell.yml"
)

for playbook in "${playbooks[@]}"; do
  echo "Checking $playbook..."
  ansible-playbook "$playbook" --syntax-check
  echo "✓ $playbook is valid"
done

echo ""
echo "All playbooks passed syntax validation!"
```

**Usage**:
```bash
chmod +x tests/validate-syntax.sh
./tests/validate-syntax.sh
```

### Role Test Script

**File**: `tests/test-role.sh`

```bash
#!/bin/bash

ROLE=$1

if [ -z "$ROLE" ]; then
  echo "Usage: ./tests/test-role.sh <role-name>"
  echo "Example: ./tests/test-role.sh common-shell"
  exit 1
fi

echo "Testing role: $ROLE"

docker run -it --rm \
  -v $(pwd):/ansible \
  -w /ansible \
  ansible-test-ubuntu:latest \
  ansible-playbook tests/test-playbook-${ROLE}.yml --check -vv
```

**Usage**:
```bash
chmod +x tests/test-role.sh
./tests/test-role.sh common-shell
```

---

## Testing Checklist

Before deploying to real machines, complete this checklist:

- [ ] All playbooks pass syntax validation (`validate-syntax.sh`)
- [ ] WSL playbook tested in Ubuntu container (check mode)
- [ ] Server playbooks tested in Ubuntu container (check mode)
- [ ] Mac playbooks tested in check mode on actual Mac
- [ ] common-shell role tested in container
- [ ] Dependencies installed via `ansible-galaxy install -r requirements.yml`
- [ ] No errors in verbose output (`-vv`)
- [ ] Idempotency verified (run twice, second run shows no changes)

---

## Docker Compose Setup

**File**: `tests/docker-compose.yml`

```yaml
version: '3.8'

services:
  ubuntu-test:
    build:
      context: ..
      dockerfile: tests/Dockerfile.ubuntu
    volumes:
      - ..:/ansible
    working_dir: /ansible
    command: tail -f /dev/null

  wsl-test:
    build:
      context: ..
      dockerfile: tests/Dockerfile.ubuntu
    volumes:
      - ..:/ansible
    working_dir: /ansible
    environment:
      - WSL_DISTRO_NAME=Ubuntu
    command: tail -f /dev/null
```

**Usage**:
```bash
# Start all test containers
docker-compose -f tests/docker-compose.yml up -d

# Run tests in ubuntu-test container
docker-compose -f tests/docker-compose.yml exec ubuntu-test \
  ansible-playbook playbooks/servers/base.yml --check

# Stop containers
docker-compose -f tests/docker-compose.yml down
```

---

## Troubleshooting

### Container Permission Issues

If you encounter permission errors:
```bash
# Run container as root
docker run -it --rm --user root \
  -v $(pwd):/ansible \
  -w /ansible \
  ansible-test-ubuntu:latest bash
```

### Ansible Not Found

```bash
# Install Ansible in container
pip3 install ansible

# Or rebuild container
docker build --no-cache -t ansible-test-ubuntu:latest -f tests/Dockerfile.ubuntu .
```

### Volume Mount Issues

```bash
# Use absolute paths
docker run -it --rm \
  -v /home/user/Development/terminal_improvements/ansible-playbooks:/ansible \
  -w /ansible \
  ansible-test-ubuntu:latest bash
```

---

## Next Steps

After Docker testing passes:

1. **Review** - Review all test output for warnings
2. **Deploy to WSL** - Lowest risk, current machine
3. **Deploy to old Mac** - Test macOS-specific tasks
4. **Deploy to test server** - Validate server configs
5. **Gradual rollout** - Deploy to remaining machines

See `TESTING_CHECKLIST.md` for complete deployment procedures.

---

## Resources

- [Ansible Testing Strategies](https://docs.ansible.com/ansible/latest/reference_appendices/test_strategies.html)
- [Docker Documentation](https://docs.docker.com/)
- [Molecule](https://molecule.readthedocs.io/) - Advanced Ansible testing framework
- [Ansible Lint](https://ansible-lint.readthedocs.io/) - Best practices linter

---

**Status**: Template created, containers not yet built
**Next**: Create Dockerfile.ubuntu and test with WSL playbook
