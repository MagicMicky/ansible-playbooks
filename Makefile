.PHONY: help install test test-syntax test-docker test-all clean lint deps

# Colors for output (using printf for proper escape sequence handling)
BLUE := \033[0;34m
GREEN := \033[0;32m
RED := \033[0;31m
YELLOW := \033[1;33m
NC := \033[0m # No Color

help: ## Show this help message
	@printf '$(BLUE)╔════════════════════════════════════════════════════════════╗$(NC)\n'
	@printf '$(BLUE)║        Ansible Playbooks - Available Commands             ║$(NC)\n'
	@printf '$(BLUE)╚════════════════════════════════════════════════════════════╝$(NC)\n'
	@printf '\n'
	@printf '$(YELLOW)Quick Start:$(NC)\n'
	@printf '  make test-syntax          # Fast syntax check (no Docker)\n'
	@printf '  make test                 # Full test suite in Docker\n'
	@printf '  make test-visual          # INTERACTIVE: See the shell in action\n'
	@printf '  make mac-personal         # Deploy to personal Mac\n'
	@printf '\n'
	@printf '$(YELLOW)All Commands:$(NC)\n'
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-22s$(NC) %s\n", $$1, $$2}'
	@printf '\n'
	@printf '$(YELLOW)Notes:$(NC)\n'
	@printf '  - Individual tests (test-wsl, test-server) leave containers running\n'
	@printf '  - Use "make clean" to stop and remove containers\n'
	@printf '  - Use "make test-visual" to see Starship prompt interactively\n'
	@printf '  - Use "make test-docker-shell" to debug inside container\n'
	@printf '\n'

deps: ## Install Ansible Galaxy dependencies
	@printf '$(BLUE)Installing Ansible Galaxy dependencies...$(NC)\n'
	ansible-galaxy install -r requirements.yml

install: deps ## Install pre-commit hooks and dependencies
	@printf '$(BLUE)Installing pre-commit hooks...$(NC)\n'
	pip install pre-commit
	pre-commit install
	@printf '$(GREEN)✅ Setup complete!$(NC)\n'

## ═══════════════════════════════════════════════════════════
## Testing Commands
## ═══════════════════════════════════════════════════════════

test: test-all ## [MAIN] Run complete test suite (syntax + Docker tests)

test-syntax: ## [FAST] Syntax check all playbooks (no Docker needed)
	@printf '$(BLUE)Running syntax validation...$(NC)\n'
	@./tests/scripts/validate-syntax.sh

test-all: deps test-syntax test-docker-build test-docker-up ## [FULL] Complete test suite: syntax, playbooks, validation
	@printf '$(BLUE)Running complete test suite...$(NC)\n'
	cd tests/docker && docker compose exec -T ubuntu-test /ansible/tests/scripts/run-all-tests.sh
	@$(MAKE) test-docker-down

## ═══════════════════════════════════════════════════════════
## Docker Container Management
## ═══════════════════════════════════════════════════════════

test-docker-build: ## [SETUP] Build Docker test containers
	@printf '$(BLUE)Building Docker test containers...$(NC)\n'
	cd tests/docker && docker compose build

test-docker-up: ## [SETUP] Start Docker test containers (leaves running)
	@printf '$(BLUE)Starting Docker test containers...$(NC)\n'
	cd tests/docker && docker compose up -d

test-docker-down: ## [CLEANUP] Stop Docker test containers
	@printf '$(BLUE)Stopping Docker test containers...$(NC)\n'
	cd tests/docker && docker compose down

test-docker-shell: ## [DEBUG] Open interactive shell in test container
	@printf '$(BLUE)Opening shell in ubuntu-test container...$(NC)\n'
	@printf '$(YELLOW)Tip: Type "exit" to leave container$(NC)\n'
	cd tests/docker && docker compose exec ubuntu-test /bin/bash

test-visual: test-docker-up ## [MANUAL] Interactive visual test - apply playbook and start shell (WSL)
	@printf '$(BLUE)╔════════════════════════════════════════════════════════╗$(NC)\n'
	@printf '$(BLUE)║   Interactive Visual Testing - WSL Environment        ║$(NC)\n'
	@printf '$(BLUE)╚════════════════════════════════════════════════════════╝$(NC)\n'
	@printf '\n'
	@printf '$(YELLOW)Step 1:$(NC) Applying WSL playbook to install everything...\n'
	@if cd tests/docker && docker compose exec -T wsl-test ansible-playbook playbooks/wsl/setup.yml -i tests/inventories/wsl.yml; then \
		printf '\n$(GREEN)✅ Setup complete!$(NC)\n'; \
	else \
		printf '\n$(RED)⚠️  Playbook had errors, but launching shell for debugging...$(NC)\n'; \
	fi
	@printf '\n'
	@printf '\n'
	@printf '$(YELLOW)Step 2:$(NC) Launching interactive shell...\n'
	@printf '$(YELLOW)You will now see:$(NC)\n'
	@printf '  - Starship prompt (λ character for WSL)\n'
	@printf '  - Color coding (blue/cyan theme)\n'
	@printf '  - Git integration (if in git directory)\n'
	@printf '  - Modern tools (fzf, zoxide, etc.)\n'
	@printf '\n'
	@printf '$(YELLOW)Try these commands:$(NC)\n'
	@printf '  cd /ansible && ls          # See project files\n'
	@printf '  starship --version         # Verify Starship installed\n'
	@printf '  echo $$MACHINE_TYPE         # Check machine type detection\n'
	@printf '  fzf --version              # Check modern tools\n'
	@printf '\n'
	@printf '$(YELLOW)Type "exit" to leave the container$(NC)\n'
	@printf '\n'
	@sleep 2
	@cd tests/docker && docker compose exec wsl-test zsh

test-visual-server: test-docker-up ## [MANUAL] Interactive visual test - apply playbook and start shell (Server)
	@printf '$(BLUE)╔════════════════════════════════════════════════════════╗$(NC)\n'
	@printf '$(BLUE)║   Interactive Visual Testing - Server Environment     ║$(NC)\n'
	@printf '$(BLUE)╚════════════════════════════════════════════════════════╝$(NC)\n'
	@printf '\n'
	@printf '$(YELLOW)Step 1:$(NC) Applying server shell playbook...\n'
	@if cd tests/docker && docker compose exec -T server-test ansible-playbook playbooks/servers/shell.yml -i tests/inventories/ubuntu.yml; then \
		printf '\n$(GREEN)✅ Setup complete!$(NC)\n'; \
	else \
		printf '\n$(RED)⚠️  Playbook had errors, but launching shell for debugging...$(NC)\n'; \
	fi
	@printf '\n'
	@printf '\n'
	@printf '$(YELLOW)Step 2:$(NC) Launching interactive shell...\n'
	@printf '$(YELLOW)You will now see:$(NC)\n'
	@printf '  - Starship prompt (· middle dot for dev server)\n'
	@printf '  - Minimal config (servers use lightweight setup)\n'
	@printf '  - Hostname: dev-test-01\n'
	@printf '\n'
	@printf '$(YELLOW)Try these commands:$(NC)\n'
	@printf '  hostname                   # Should show "dev-test-01"\n'
	@printf '  echo $$MACHINE_TYPE         # Check machine type detection\n'
	@printf '  starship config            # See minimal Starship config\n'
	@printf '\n'
	@printf '$(YELLOW)Type "exit" to leave the container$(NC)\n'
	@printf '\n'
	@sleep 2
	@cd tests/docker && docker compose exec server-test zsh

## ═══════════════════════════════════════════════════════════
## Individual Test Components (containers stay running)
## ═══════════════════════════════════════════════════════════

test-wsl: test-docker-up ## [PLAYBOOK] Apply WSL playbook in container
	@printf '$(BLUE)Testing WSL playbook...$(NC)\n'
	cd tests/docker && docker compose exec -T wsl-test ansible-playbook playbooks/wsl/setup.yml -i tests/inventories/wsl.yml

test-server: test-docker-up ## [PLAYBOOK] Apply server playbook in container
	@printf '$(BLUE)Testing server playbooks...$(NC)\n'
	cd tests/docker && docker compose exec -T server-test ansible-playbook playbooks/servers/shell.yml -i tests/inventories/ubuntu.yml

test-idempotency: test-docker-up ## [VALIDATION] Verify playbook runs don't change on 2nd run
	@printf '$(BLUE)Testing idempotency...$(NC)\n'
	@printf '$(YELLOW)Note: Runs playbook twice, checks for changes on 2nd run$(NC)\n'
	cd tests/docker && docker compose exec -T wsl-test /ansible/tests/scripts/test-idempotency.sh playbooks/wsl/setup.yml tests/inventories/wsl.yml

test-shell-validation: test-docker-up ## [VALIDATION] Check shell config (startup time, tools installed)
	@printf '$(BLUE)Validating shell configuration...$(NC)\n'
	cd tests/docker && docker compose exec -T ubuntu-test /ansible/tests/scripts/validate-shell.sh

## ═══════════════════════════════════════════════════════════
## Code Quality
## ═══════════════════════════════════════════════════════════

lint: ## Run ansible-lint on playbooks
	@printf '$(BLUE)Running ansible-lint...$(NC)\n'
	@printf '$(YELLOW)Note: Warnings are informational, errors should be fixed$(NC)\n'
	@ansible-lint playbooks/ || (printf '$(YELLOW)⚠️  Lint issues found (see above)$(NC)\n'; exit 0)

lint-fix: ## Run pre-commit hooks on all files
	@printf '$(BLUE)Running pre-commit hooks...$(NC)\n'
	pre-commit run --all-files

clean: test-docker-down ## Stop containers and clean up artifacts
	@printf '$(BLUE)Cleaning up test artifacts...$(NC)\n'
	rm -rf tests/test-results/*
	find . -name "*.retry" -delete
	find . -name "*.pyc" -delete
	find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
	@printf '$(GREEN)✅ Cleanup complete!$(NC)\n'
	@printf '$(YELLOW)Note: Containers stopped and removed$(NC)\n'

## ═══════════════════════════════════════════════════════════
## Production Deployment Commands
## ═══════════════════════════════════════════════════════════

mac-personal-check: ## [DRY RUN] Check personal Mac playbook without applying
	@printf '$(BLUE)Running personal Mac playbook (check mode)...$(NC)\n'
	ansible-playbook playbooks/mac/personal.yml -i inventories/localhost -K --check

mac-personal: deps ## [DEPLOY] Apply personal Mac playbook
	@printf '$(BLUE)Running personal Mac playbook...$(NC)\n'
	@printf '$(YELLOW)⚠️  This will modify your system!$(NC)\n'
	ansible-playbook playbooks/mac/personal.yml -i inventories/localhost -K

mac-work-check: ## [DRY RUN] Check work Mac playbook without applying
	@printf '$(BLUE)Running work Mac playbook (check mode)...$(NC)\n'
	ansible-playbook playbooks/mac/work.yml -i inventories/localhost -K --check

mac-work: deps ## [DEPLOY] Apply work Mac playbook
	@printf '$(BLUE)Running work Mac playbook...$(NC)\n'
	@printf '$(YELLOW)⚠️  This will modify your system!$(NC)\n'
	ansible-playbook playbooks/mac/work.yml -i inventories/localhost -K

wsl-setup: deps ## [DEPLOY] Apply WSL setup playbook
	@printf '$(BLUE)Running WSL setup playbook...$(NC)\n'
	ansible-playbook playbooks/wsl/setup.yml -i inventories/localhost

server-base: deps ## [DEPLOY] Apply server base playbook (requires INVENTORY=path)
	@printf '$(BLUE)Running server base playbook...$(NC)\n'
	@printf '$(RED)Usage: make server-base INVENTORY=inventories/servers.yml$(NC)\n'
	ansible-playbook playbooks/servers/base.yml -i ${INVENTORY} -K

server-shell: deps ## [DEPLOY] Apply server shell playbook (requires INVENTORY=path)
	@printf '$(BLUE)Running server shell playbook...$(NC)\n'
	@printf '$(RED)Usage: make server-shell INVENTORY=inventories/servers.yml$(NC)\n'
	ansible-playbook playbooks/servers/shell.yml -i ${INVENTORY}

## ═══════════════════════════════════════════════════════════
## Documentation & Info
## ═══════════════════════════════════════════════════════════

docs: ## Open project documentation
	@printf '$(BLUE)Opening documentation...$(NC)\n'
	@command -v open >/dev/null 2>&1 && open docs/README.md || xdg-open docs/README.md || printf "Please open docs/README.md manually\n"

status: ## Show project completion status
	@cat STATUS.md

.DEFAULT_GOAL := help
