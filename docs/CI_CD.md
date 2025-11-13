# CI/CD Automation Guide

**Purpose**: Continuous Integration and Continuous Deployment setup for Ansible playbooks.

---

## Overview

This document describes the CI/CD automation strategy for the ansible-playbooks repository, including:
- GitHub Actions workflows
- Pre-commit hooks
- Automated testing
- Quality checks
- Deployment automation

**Status**: Planning document (not yet implemented)

---

## GitHub Actions Workflows

### Syntax Validation Workflow

**File**: `.github/workflows/validate.yml`

```yaml
name: Validate Playbooks

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  validate:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v3

      - name: Set up Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.10'

      - name: Install Ansible
        run: |
          pip install ansible ansible-lint yamllint

      - name: Validate YAML syntax
        run: |
          yamllint -c .yamllint .

      - name: Validate Ansible syntax
        run: |
          for playbook in playbooks/**/*.yml; do
            echo "Validating $playbook..."
            ansible-playbook "$playbook" --syntax-check
          done

      - name: Run Ansible Lint
        run: |
          ansible-lint playbooks/ roles/

      - name: Validate requirements.yml
        run: |
          yamllint requirements.yml
```

### Docker Testing Workflow

**File**: `.github/workflows/test.yml`

```yaml
name: Test Playbooks

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  test-ubuntu:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v3

      - name: Build test container
        run: |
          docker build -t ansible-test:latest -f tests/Dockerfile.ubuntu .

      - name: Test WSL playbook
        run: |
          docker run --rm \
            -v $(pwd):/ansible \
            -w /ansible \
            ansible-test:latest \
            ansible-playbook playbooks/wsl/setup.yml --check -vv

      - name: Test server playbooks
        run: |
          docker run --rm \
            -v $(pwd):/ansible \
            -w /ansible \
            ansible-test:latest \
            ansible-playbook playbooks/servers/base.yml \
            -i tests/inventory-test.yml --check -vv

  test-idempotency:
    runs-on: ubuntu-latest
    needs: test-ubuntu

    steps:
      - name: Checkout code
        uses: actions/checkout@v3

      - name: Build test container
        run: |
          docker build -t ansible-test:latest -f tests/Dockerfile.ubuntu .

      - name: Test idempotency (WSL)
        run: |
          # First run
          docker run --rm \
            -v $(pwd):/ansible \
            -w /ansible \
            ansible-test:latest \
            ansible-playbook playbooks/wsl/setup.yml

          # Second run (should show no changes)
          docker run --rm \
            -v $(pwd):/ansible \
            -w /ansible \
            ansible-test:latest \
            ansible-playbook playbooks/wsl/setup.yml | tee output.log

          # Check for changes
          if grep -q "changed=0" output.log; then
            echo "✓ Idempotency test passed"
          else
            echo "✗ Idempotency test failed"
            exit 1
          fi
```

### Documentation Workflow

**File**: `.github/workflows/docs.yml`

```yaml
name: Documentation Checks

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  check-docs:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v3

      - name: Check for broken links
        uses: gaurav-nelson/github-action-markdown-link-check@v1
        with:
          use-quiet-mode: 'yes'
          config-file: '.markdown-link-check.json'

      - name: Validate documentation structure
        run: |
          required_docs=(
            "README.md"
            "STATUS.md"
            "NEXT_STEPS.md"
            "TESTING_CHECKLIST.md"
            "docs/MIGRATION.md"
            "docs/PLAYBOOKS.md"
            "docs/ROLES.md"
          )

          for doc in "${required_docs[@]}"; do
            if [ ! -f "$doc" ]; then
              echo "✗ Missing required documentation: $doc"
              exit 1
            fi
          done

          echo "✓ All required documentation present"
```

---

## Pre-commit Hooks

### Installation

```bash
# Install pre-commit
pip install pre-commit

# Install hooks in repository
cd ~/Development/terminal_improvements/ansible-playbooks
pre-commit install
```

### Configuration

**File**: `.pre-commit-config.yaml`

```yaml
repos:
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v4.4.0
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: check-yaml
        args: [--allow-multiple-documents]
      - id: check-added-large-files
      - id: check-merge-conflict
      - id: mixed-line-ending

  - repo: https://github.com/adrienverge/yamllint
    rev: v1.32.0
    hooks:
      - id: yamllint
        args: [-c=.yamllint]

  - repo: https://github.com/ansible/ansible-lint
    rev: v6.17.2
    hooks:
      - id: ansible-lint
        files: \.(yaml|yml)$
        args: [--exclude, .github/]

  - repo: https://github.com/psf/black
    rev: 23.7.0
    hooks:
      - id: black
        language_version: python3
        files: \.(py)$

  - repo: https://github.com/markdownlint/markdownlint
    rev: v0.12.0
    hooks:
      - id: markdownlint
        args: [--config, .markdownlint.yml]
```

**Usage**:
```bash
# Run on all files
pre-commit run --all-files

# Run on staged files (automatic on git commit)
git commit -m "your message"

# Skip hooks (emergency only)
git commit --no-verify -m "emergency fix"
```

---

## Quality Check Configuration

### yamllint Configuration

**File**: `.yamllint`

```yaml
---
extends: default

rules:
  line-length:
    max: 120
    level: warning

  indentation:
    spaces: 2
    indent-sequences: true

  comments:
    min-spaces-from-content: 1

  braces:
    max-spaces-inside: 1

  brackets:
    max-spaces-inside: 1

  truthy:
    allowed-values: ['true', 'false', 'yes', 'no']

ignore: |
  .github/
  tests/
  venv/
```

### ansible-lint Configuration

**File**: `.ansible-lint`

```yaml
---
skip_list:
  - yaml[line-length]  # Allow long lines in some cases
  - role-name  # Allow flexible role naming

warn_list:
  - experimental  # Warn on experimental features
  - package-latest  # Warn when using package: state=latest

exclude_paths:
  - .github/
  - tests/
  - venv/

use_default_rules: true
```

### markdownlint Configuration

**File**: `.markdownlint.yml`

```yaml
---
# MD013: Line length
MD013: false

# MD033: Inline HTML
MD033: false

# MD041: First line in file should be top-level heading
MD041: false
```

---

## Status Badges

Add to README.md:

```markdown
# Ansible Playbooks

[![Validate](https://github.com/USERNAME/ansible-playbooks/actions/workflows/validate.yml/badge.svg)](https://github.com/USERNAME/ansible-playbooks/actions/workflows/validate.yml)
[![Test](https://github.com/USERNAME/ansible-playbooks/actions/workflows/test.yml/badge.svg)](https://github.com/USERNAME/ansible-playbooks/actions/workflows/test.yml)
[![Documentation](https://github.com/USERNAME/ansible-playbooks/actions/workflows/docs.yml/badge.svg)](https://github.com/USERNAME/ansible-playbooks/actions/workflows/docs.yml)
```

---

## Automated Deployment

### Deployment Workflow (Future)

**File**: `.github/workflows/deploy.yml`

```yaml
name: Deploy

on:
  workflow_dispatch:
    inputs:
      target:
        description: 'Deployment target'
        required: true
        type: choice
        options:
          - wsl
          - personal-mac
          - test-server

      playbook:
        description: 'Playbook to run'
        required: true
        type: string

jobs:
  deploy:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v3

      - name: Set up Ansible
        run: |
          pip install ansible
          ansible-galaxy install -r requirements.yml

      - name: Configure SSH
        run: |
          mkdir -p ~/.ssh
          echo "${{ secrets.SSH_PRIVATE_KEY }}" > ~/.ssh/id_rsa
          chmod 600 ~/.ssh/id_rsa

      - name: Deploy playbook
        run: |
          ansible-playbook ${{ inputs.playbook }} \
            -i inventories/${{ inputs.target }} \
            -vv
```

**Note**: Requires SSH_PRIVATE_KEY secret configured in GitHub repository settings.

---

## Local CI/CD Testing

### Run CI checks locally

```bash
# Validate syntax
ansible-playbook playbooks/wsl/setup.yml --syntax-check

# Run ansible-lint
ansible-lint playbooks/ roles/

# Run yamllint
yamllint .

# Run all pre-commit hooks
pre-commit run --all-files
```

### Simulate GitHub Actions locally

Using [act](https://github.com/nektos/act):

```bash
# Install act
brew install act  # macOS
# or
sudo apt-get install act  # Ubuntu

# Run workflow locally
act -j validate
act -j test-ubuntu
```

---

## Implementation Roadmap

### Phase 1: Basic Validation
- [ ] Create `.github/workflows/validate.yml`
- [ ] Configure yamllint
- [ ] Configure ansible-lint
- [ ] Add status badges to README

### Phase 2: Testing
- [ ] Create `.github/workflows/test.yml`
- [ ] Build Docker test containers
- [ ] Implement idempotency tests
- [ ] Add test coverage reporting

### Phase 3: Pre-commit Hooks
- [ ] Create `.pre-commit-config.yaml`
- [ ] Install pre-commit in repository
- [ ] Configure all hooks
- [ ] Document usage in README

### Phase 4: Documentation
- [ ] Create `.github/workflows/docs.yml`
- [ ] Configure markdown link checker
- [ ] Add documentation validation
- [ ] Create CONTRIBUTING.md

### Phase 5: Deployment
- [ ] Create `.github/workflows/deploy.yml`
- [ ] Configure SSH secrets
- [ ] Test deployment workflow
- [ ] Document deployment process

---

## Security Considerations

### Secrets Management

**Never commit**:
- SSH private keys
- API tokens
- Passwords
- Work-specific credentials

**Use**:
- GitHub Secrets for CI/CD
- Ansible Vault for sensitive vars
- `.gitignore` for local secrets

### GitHub Secrets Required

```
SSH_PRIVATE_KEY - SSH key for deployment
GALAXY_API_KEY  - Ansible Galaxy API key (if publishing roles)
```

---

## Monitoring and Notifications

### Slack Notifications

Add to workflows:

```yaml
      - name: Notify Slack
        if: failure()
        uses: 8398a7/action-slack@v3
        with:
          status: ${{ job.status }}
          text: 'Playbook validation failed!'
          webhook_url: ${{ secrets.SLACK_WEBHOOK }}
```

### Email Notifications

Configure in GitHub repository settings:
- Settings → Notifications
- Enable email notifications for workflow failures

---

## Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Pre-commit Framework](https://pre-commit.com/)
- [Ansible Lint](https://ansible-lint.readthedocs.io/)
- [yamllint](https://yamllint.readthedocs.io/)
- [act - Run GitHub Actions locally](https://github.com/nektos/act)

---

**Status**: Planning document
**Next Steps**: Implement Phase 1 (Basic Validation)
**Priority**: Medium (after successful manual testing)
