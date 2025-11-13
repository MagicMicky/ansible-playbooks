.PHONY: help install test test-syntax test-docker test-all clean lint deps

# Colors for output
BLUE := \033[0;34m
GREEN := \033[0;32m
RED := \033[0;31m
YELLOW := \033[1;33m
NC := \033[0m # No Color

help: ## Show this help message
	@echo '$(BLUE)╔════════════════════════════════════════════════════════════╗$(NC)'
	@echo '$(BLUE)║        Ansible Playbooks - Available Commands             ║$(NC)'
	@echo '$(BLUE)╚════════════════════════════════════════════════════════════╝$(NC)'
	@echo ''
	@echo '$(YELLOW)Quick Start:$(NC)'
	@echo '  make test-syntax          # Fast syntax check (no Docker)'
	@echo '  make test                 # Full test suite in Docker'
	@echo '  make mac-personal         # Deploy to personal Mac'
	@echo ''
	@echo '$(YELLOW)All Commands:$(NC)'
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-22s$(NC) %s\n", $$1, $$2}'
	@echo ''
	@echo '$(YELLOW)Notes:$(NC)'
	@echo '  - Individual tests (test-wsl, test-server) leave containers running'
	@echo '  - Use "make clean" to stop and remove containers'
	@echo '  - Use "make test-docker-shell" to debug inside container'
	@echo ''

deps: ## Install Ansible Galaxy dependencies
	@echo '$(BLUE)Installing Ansible Galaxy dependencies...$(NC)'
	ansible-galaxy install -r requirements.yml

install: deps ## Install pre-commit hooks and dependencies
	@echo '$(BLUE)Installing pre-commit hooks...$(NC)'
	pip install pre-commit
	pre-commit install
	@echo '$(GREEN)✅ Setup complete!$(NC)'

## ═══════════════════════════════════════════════════════════
## Testing Commands
## ═══════════════════════════════════════════════════════════

test: test-all ## [MAIN] Run complete test suite (syntax + Docker tests)

test-syntax: ## [FAST] Syntax check all playbooks (no Docker needed)
	@echo '$(BLUE)Running syntax validation...$(NC)'
	@./tests/scripts/validate-syntax.sh

test-all: deps test-syntax test-docker-build test-docker-up ## [FULL] Complete test suite: syntax, playbooks, validation
	@echo '$(BLUE)Running complete test suite...$(NC)'
	cd tests/docker && docker compose exec -T ubuntu-test /ansible/tests/scripts/run-all-tests.sh
	@$(MAKE) test-docker-down

## ═══════════════════════════════════════════════════════════
## Docker Container Management
## ═══════════════════════════════════════════════════════════

test-docker-build: ## [SETUP] Build Docker test containers
	@echo '$(BLUE)Building Docker test containers...$(NC)'
	cd tests/docker && docker compose build

test-docker-up: ## [SETUP] Start Docker test containers (leaves running)
	@echo '$(BLUE)Starting Docker test containers...$(NC)'
	cd tests/docker && docker compose up -d

test-docker-down: ## [CLEANUP] Stop Docker test containers
	@echo '$(BLUE)Stopping Docker test containers...$(NC)'
	cd tests/docker && docker compose down

test-docker-shell: ## [DEBUG] Open interactive shell in test container
	@echo '$(BLUE)Opening shell in ubuntu-test container...$(NC)'
	@echo '$(YELLOW)Tip: Type "exit" to leave container$(NC)'
	cd tests/docker && docker compose exec ubuntu-test /bin/bash

## ═══════════════════════════════════════════════════════════
## Individual Test Components (containers stay running)
## ═══════════════════════════════════════════════════════════

test-wsl: test-docker-up ## [PLAYBOOK] Apply WSL playbook in container
	@echo '$(BLUE)Testing WSL playbook...$(NC)'
	cd tests/docker && docker compose exec -T wsl-test ansible-playbook playbooks/wsl/setup.yml -i tests/inventories/wsl.yml

test-server: test-docker-up ## [PLAYBOOK] Apply server playbook in container
	@echo '$(BLUE)Testing server playbooks...$(NC)'
	cd tests/docker && docker compose exec -T server-test ansible-playbook playbooks/servers/shell.yml -i tests/inventories/ubuntu.yml

test-idempotency: test-docker-up ## [VALIDATION] Verify playbook runs don't change on 2nd run
	@echo '$(BLUE)Testing idempotency...$(NC)'
	@echo '$(YELLOW)Note: Runs playbook twice, checks for changes on 2nd run$(NC)'
	cd tests/docker && docker compose exec -T wsl-test /ansible/tests/scripts/test-idempotency.sh playbooks/wsl/setup.yml tests/inventories/wsl.yml

test-shell-validation: test-docker-up ## [VALIDATION] Check shell config (startup time, tools installed)
	@echo '$(BLUE)Validating shell configuration...$(NC)'
	cd tests/docker && docker compose exec -T ubuntu-test /ansible/tests/scripts/validate-shell.sh

## ═══════════════════════════════════════════════════════════
## Code Quality
## ═══════════════════════════════════════════════════════════

lint: ## Run ansible-lint on playbooks
	@echo '$(BLUE)Running ansible-lint...$(NC)'
	ansible-lint playbooks/ || true

lint-fix: ## Run pre-commit hooks on all files
	@echo '$(BLUE)Running pre-commit hooks...$(NC)'
	pre-commit run --all-files

clean: test-docker-down ## Stop containers and clean up artifacts
	@echo '$(BLUE)Cleaning up test artifacts...$(NC)'
	rm -rf tests/test-results/*
	find . -name "*.retry" -delete
	find . -name "*.pyc" -delete
	find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
	@echo '$(GREEN)✅ Cleanup complete!$(NC)'
	@echo '$(YELLOW)Note: Containers stopped and removed$(NC)'

## ═══════════════════════════════════════════════════════════
## Production Deployment Commands
## ═══════════════════════════════════════════════════════════

mac-personal-check: ## [DRY RUN] Check personal Mac playbook without applying
	@echo '$(BLUE)Running personal Mac playbook (check mode)...$(NC)'
	ansible-playbook playbooks/mac/personal.yml -i inventories/localhost -K --check

mac-personal: deps ## [DEPLOY] Apply personal Mac playbook
	@echo '$(BLUE)Running personal Mac playbook...$(NC)'
	@echo '$(YELLOW)⚠️  This will modify your system!$(NC)'
	ansible-playbook playbooks/mac/personal.yml -i inventories/localhost -K

mac-work-check: ## [DRY RUN] Check work Mac playbook without applying
	@echo '$(BLUE)Running work Mac playbook (check mode)...$(NC)'
	ansible-playbook playbooks/mac/work.yml -i inventories/localhost -K --check

mac-work: deps ## [DEPLOY] Apply work Mac playbook
	@echo '$(BLUE)Running work Mac playbook...$(NC)'
	@echo '$(YELLOW)⚠️  This will modify your system!$(NC)'
	ansible-playbook playbooks/mac/work.yml -i inventories/localhost -K

wsl-setup: deps ## [DEPLOY] Apply WSL setup playbook
	@echo '$(BLUE)Running WSL setup playbook...$(NC)'
	ansible-playbook playbooks/wsl/setup.yml -i inventories/localhost

server-base: deps ## [DEPLOY] Apply server base playbook (requires INVENTORY=path)
	@echo '$(BLUE)Running server base playbook...$(NC)'
	@echo '$(RED)Usage: make server-base INVENTORY=inventories/servers.yml$(NC)'
	ansible-playbook playbooks/servers/base.yml -i ${INVENTORY} -K

server-shell: deps ## [DEPLOY] Apply server shell playbook (requires INVENTORY=path)
	@echo '$(BLUE)Running server shell playbook...$(NC)'
	@echo '$(RED)Usage: make server-shell INVENTORY=inventories/servers.yml$(NC)'
	ansible-playbook playbooks/servers/shell.yml -i ${INVENTORY}

## ═══════════════════════════════════════════════════════════
## Documentation & Info
## ═══════════════════════════════════════════════════════════

docs: ## Open project documentation
	@echo '$(BLUE)Opening documentation...$(NC)'
	@command -v open >/dev/null 2>&1 && open docs/README.md || xdg-open docs/README.md || echo "Please open docs/README.md manually"

status: ## Show project completion status
	@cat STATUS.md

.DEFAULT_GOAL := help
