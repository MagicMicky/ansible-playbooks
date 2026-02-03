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
	@printf '  make test-syntax          # Fast syntax check (~10s, no Docker)\n'
	@printf '  make test                 # Full test suite (~10-15min, 19 tests)\n'
	@printf '  make test-ci              # CI-style parallel tests (faster)\n'
	@printf '  make test-shell           # Interactive zsh debugging\n'
	@printf '\n'
	@printf '$(YELLOW)Example Workflows:$(NC)\n'
	@printf '  make test-syntax && make test     # Quick check, then full suite\n'
	@printf '  make test-wsl && make test-shell  # Test WSL, then explore shell\n'
	@printf '  make test-performance-wsl         # Check shell startup time\n'
	@printf '  make clean && make test           # Fresh start, full suite\n'
	@printf '\n'
	@printf '$(YELLOW)All Commands:$(NC)\n'
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-22s$(NC) %s\n", $$1, $$2}'
	@printf '\n'
	@printf '$(YELLOW)Test Architecture:$(NC)\n'
	@printf '  - 19 tests total (WSL: 9, Server: 9, Syntax: 1)\n'
	@printf '  - Each playbook runs in isolated Docker container\n'
	@printf '  - Includes: security, performance, profile isolation checks\n'
	@printf '  - Individual tests leave containers running for debugging\n'
	@printf '\n'

deps: ## Install Ansible Galaxy dependencies
	@printf '$(BLUE)Installing Ansible Galaxy dependencies...$(NC)\n'
	ansible-galaxy install -r requirements.yml

install: deps ## Install pre-commit hooks and dependencies
	@printf '$(BLUE)Installing pre-commit hooks...$(NC)\n'
	pip3 install pre-commit
	pre-commit install
	@printf '$(GREEN)✅ Setup complete!$(NC)\n'

## ═══════════════════════════════════════════════════════════
## Testing Commands
## ═══════════════════════════════════════════════════════════

test: deps test-syntax test-docker-build test-docker-up ## [MAIN] Run complete test suite in isolated containers (~10-15min)
	@printf '$(BLUE)╔════════════════════════════════════════════════════════╗$(NC)\n'
	@printf '$(BLUE)║  Running Test Suite                                   ║$(NC)\n'
	@printf '$(BLUE)║  - WSL tests in wsl-test container                    ║$(NC)\n'
	@printf '$(BLUE)║  - Server tests in server-test container              ║$(NC)\n'
	@printf '$(BLUE)║  - Full idempotency coverage                          ║$(NC)\n'
	@printf '$(BLUE)╚════════════════════════════════════════════════════════╝$(NC)\n'
	@./tests/scripts/run-all-tests.sh
	@$(MAKE) test-docker-down

test-ci: test-docker-build test-docker-up ## [CI] Run tests in parallel (simulates CI matrix behavior)
	@printf '$(BLUE)╔════════════════════════════════════════════════════════╗$(NC)\n'
	@printf '$(BLUE)║  Running CI-Style Parallel Tests                      ║$(NC)\n'
	@printf '$(BLUE)╚════════════════════════════════════════════════════════╝$(NC)\n'
	@printf '$(YELLOW)Running WSL and Server tests concurrently...$(NC)\n'
	@cd tests/docker && \
		( docker compose exec -T wsl-test bash -c "cd /ansible && ansible-playbook playbooks/wsl/setup.yml -i tests/inventories/wsl.yml && bash tests/scripts/validate-shell.sh" ) & \
		( docker compose exec -T server-test bash -c "cd /ansible && ansible-playbook playbooks/servers/setup.yml -i tests/inventories/ubuntu.yml && bash tests/scripts/validate-shell.sh" ) & \
		wait
	@printf '$(GREEN)✅ CI-style parallel tests complete$(NC)\n'
	@$(MAKE) test-docker-down

test-syntax: ## [FAST] Syntax check all playbooks (no Docker needed ~10s)
	@printf '$(BLUE)Running syntax validation...$(NC)\n'
	@./tests/scripts/validate-syntax.sh

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

test-shell: test-docker-up ## [DEBUG] Open interactive zsh shell in WSL test container
	@printf '$(BLUE)╔════════════════════════════════════════════════════════╗$(NC)\n'
	@printf '$(BLUE)║  Interactive Shell - WSL Test Container               ║$(NC)\n'
	@printf '$(BLUE)╚════════════════════════════════════════════════════════╝$(NC)\n'
	@printf '\n'
	@printf '$(YELLOW)Opening zsh shell in wsl-test container...$(NC)\n'
	@printf '$(YELLOW)Tip: Type "exit" to leave container$(NC)\n'
	@printf '\n'
	cd tests/docker && docker compose exec wsl-test zsh || docker compose exec wsl-test /bin/bash

test-shell-server: test-docker-up ## [DEBUG] Open interactive zsh shell in server test container
	@printf '$(BLUE)Opening zsh shell in server-test container...$(NC)\n'
	@printf '$(YELLOW)Tip: Type "exit" to leave container$(NC)\n'
	cd tests/docker && docker compose exec server-test zsh || docker compose exec server-test /bin/bash

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
	@if cd tests/docker && docker compose exec -T server-test ansible-playbook playbooks/servers/setup.yml -i tests/inventories/ubuntu.yml; then \
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
	cd tests/docker && docker compose exec -T server-test ansible-playbook playbooks/servers/setup.yml -i tests/inventories/ubuntu.yml

test-idempotency-wsl: test-docker-up ## [VALIDATION] WSL playbook idempotency test
	@printf '$(BLUE)Testing WSL playbook idempotency...$(NC)\n'
	@printf '$(YELLOW)Note: Runs playbook twice, checks for changes on 2nd run$(NC)\n'
	cd tests/docker && docker compose exec -T wsl-test /ansible/tests/scripts/test-idempotency.sh playbooks/wsl/setup.yml tests/inventories/wsl.yml

test-idempotency-server: test-docker-up ## [VALIDATION] Server playbook idempotency test
	@printf '$(BLUE)Testing server playbook idempotency...$(NC)\n'
	@printf '$(YELLOW)Note: Runs playbook twice, checks for changes on 2nd run$(NC)\n'
	cd tests/docker && docker compose exec -T server-test /ansible/tests/scripts/test-idempotency.sh playbooks/servers/setup.yml tests/inventories/ubuntu.yml

test-validation-wsl: test-docker-up ## [VALIDATION] Validate WSL shell configuration
	@printf '$(BLUE)Validating WSL shell configuration...$(NC)\n'
	cd tests/docker && docker compose exec -T wsl-test /ansible/tests/scripts/validate-shell.sh

test-validation-server: test-docker-up ## [VALIDATION] Validate server shell configuration
	@printf '$(BLUE)Validating server shell configuration...$(NC)\n'
	cd tests/docker && docker compose exec -T server-test /ansible/tests/scripts/validate-shell.sh

test-profile-isolation-wsl: test-docker-up ## [VALIDATION] Validate WSL profile isolation
	@printf '$(BLUE)Validating WSL profile isolation...$(NC)\n'
	cd tests/docker && docker compose exec -T wsl-test /ansible/tests/scripts/validate-profile-isolation.sh

test-profile-isolation-server: test-docker-up ## [VALIDATION] Validate server profile isolation
	@printf '$(BLUE)Validating server profile isolation...$(NC)\n'
	cd tests/docker && docker compose exec -T server-test /ansible/tests/scripts/validate-profile-isolation.sh

test-config-content-wsl: test-docker-up ## [VALIDATION] Validate WSL configuration content
	@printf '$(BLUE)Validating WSL configuration content...$(NC)\n'
	cd tests/docker && docker compose exec -T wsl-test /ansible/tests/scripts/validate-config-content.sh

test-config-content-server: test-docker-up ## [VALIDATION] Validate server configuration content
	@printf '$(BLUE)Validating server configuration content...$(NC)\n'
	cd tests/docker && docker compose exec -T server-test /ansible/tests/scripts/validate-config-content.sh

test-performance-wsl: test-docker-up ## [VALIDATION] Track WSL shell startup performance
	@printf '$(BLUE)Tracking WSL shell startup performance...$(NC)\n'
	cd tests/docker && docker compose exec -T wsl-test /ansible/tests/scripts/track-performance.sh

test-performance-server: test-docker-up ## [VALIDATION] Track server shell startup performance
	@printf '$(BLUE)Tracking server shell startup performance...$(NC)\n'
	cd tests/docker && docker compose exec -T server-test /ansible/tests/scripts/track-performance.sh

test-performance-history: ## [INFO] Show shell startup performance history
	@printf '$(BLUE)Performance history:$(NC)\n'
	@./tests/scripts/track-performance.sh --show-history

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

wsl-check: deps ## [DEPLOY] Apply WSL setup playbook
	@printf '$(BLUE)Running WSL setup playbook...$(NC)\n'
	ansible-playbook playbooks/wsl/setup.yml -i inventories/localhost -K --check

wsl: deps ## [DEPLOY] Apply WSL setup playbook
	@printf '$(BLUE)Running WSL setup playbook...$(NC)\n'
	ansible-playbook playbooks/wsl/setup.yml -i inventories/localhost -K

server: deps ## [DEPLOY] Apply server setup playbook (requires INVENTORY=path)
	@printf '$(BLUE)Running server setup playbook...$(NC)\n'
	@printf '$(RED)Usage: make server INVENTORY=inventories/servers.yml$(NC)\n'
	ansible-playbook playbooks/servers/setup.yml -i ${INVENTORY} -K

server-shell-only: deps ## [DEPLOY] Apply server setup playbook, shell only (requires INVENTORY=path)
	@printf '$(BLUE)Running server setup playbook (shell only)...$(NC)\n'
	@printf '$(RED)Usage: make server-shell-only INVENTORY=inventories/servers.yml$(NC)\n'
	ansible-playbook playbooks/servers/setup.yml -i ${INVENTORY} -K -e configure_server_base=false

## ═══════════════════════════════════════════════════════════
## Documentation & Info
## ═══════════════════════════════════════════════════════════

docs: ## Open project documentation
	@printf '$(BLUE)Opening documentation...$(NC)\n'
	@command -v open >/dev/null 2>&1 && open docs/README.md || xdg-open docs/README.md || printf "Please open docs/README.md manually\n"

status: ## Show project completion status
	@cat STATUS.md

.DEFAULT_GOAL := help
