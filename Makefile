.PHONY: help deps wsl laptop server check-wsl check-laptop check-server

help:
	@echo "Ansible Shared Roles - Modern Shell Configuration"
	@echo ""
	@echo "Available targets:"
	@echo "  make deps           - Install Ansible galaxy dependencies"
	@echo "  make wsl            - Deploy to WSL (current machine)"
	@echo "  make laptop         - Deploy to personal laptop"
	@echo "  make server         - Deploy to servers (requires inventory)"
	@echo "  make check-wsl      - Dry-run WSL deployment"
	@echo "  make check-laptop   - Dry-run laptop deployment"
	@echo "  make check-server   - Dry-run server deployment"

deps:
	@echo "Installing Ansible dependencies..."
	ansible-galaxy install -r requirements.yml

wsl: deps
	@echo "Deploying to WSL..."
	ansible-playbook playbooks/wsl-setup.yml

laptop: deps
	@echo "Deploying to laptop..."
	ansible-playbook playbooks/laptop-setup.yml

server: deps
	@echo "Deploying to servers..."
	ansible-playbook playbooks/server-setup.yml -i inventory.ini

check-wsl: deps
	@echo "Checking WSL deployment (dry-run)..."
	ansible-playbook playbooks/wsl-setup.yml --check

check-laptop: deps
	@echo "Checking laptop deployment (dry-run)..."
	ansible-playbook playbooks/laptop-setup.yml --check

check-server: deps
	@echo "Checking server deployment (dry-run)..."
	ansible-playbook playbooks/server-setup.yml -i inventory.ini --check
