#!/usr/bin/env bash
# Check installed tools and their versions
# Useful for verifying playbook execution results

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Installed Tools Check ===${NC}"
echo ""

# Function to check tool
check_tool() {
    local cmd=$1
    local name=$2

    echo -n "$name: "
    if command -v "$cmd" > /dev/null 2>&1; then
        version=$("$cmd" --version 2>&1 | head -1 || echo "installed")
        echo -e "${GREEN}✓${NC} $version"
        return 0
    else
        echo -e "${RED}✗ NOT FOUND${NC}"
        return 1
    fi
}

# Essential tools (all environments)
echo "Essential Tools:"
check_tool "git" "Git"
check_tool "zsh" "Zsh"
check_tool "starship" "Starship"
check_tool "fzf" "fzf"
check_tool "zoxide" "zoxide"
check_tool "rg" "ripgrep"
echo ""

# Laptop/development tools (optional)
echo "Development Tools (optional):"
check_tool "bat" "bat" || true
check_tool "eza" "eza" || true
check_tool "fd" "fd" || true
echo ""

# Server tools
echo "Server Tools (if applicable):"
check_tool "docker" "Docker" || true
# Docker Compose V2 uses 'docker compose' not 'docker-compose'
if docker compose version > /dev/null 2>&1; then
    version=$(docker compose version 2>&1 | head -1)
    echo -e "  Docker Compose: ${GREEN}✓${NC} $version"
else
    echo -e "  Docker Compose: ${RED}✗ NOT FOUND${NC}"
fi
echo ""

# Build tools
echo "Build Tools:"
check_tool "make" "Make" || true
check_tool "gcc" "GCC" || true
check_tool "curl" "curl"
check_tool "wget" "wget"
echo ""

# Configuration files
echo "Configuration Files:"
[ -f "$HOME/.zshrc" ] && echo -e "  ~/.zshrc: ${GREEN}✓${NC}" || echo -e "  ~/.zshrc: ${RED}✗${NC}"
[ -f "$HOME/.config/starship.toml" ] && echo -e "  ~/.config/starship.toml: ${GREEN}✓${NC}" || echo -e "  ~/.config/starship.toml: ${RED}✗${NC}"
[ -d "$HOME/.local/share/zinit" ] && echo -e "  zinit directory: ${GREEN}✓${NC}" || echo -e "  zinit directory: ${RED}✗${NC}"
echo ""

echo -e "${GREEN}Tool check complete${NC}"
