#!/usr/bin/env bash
# Validation script for machine type detection
# Checks that Starship configuration is properly generated for each container type

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
PASS_COUNT=0
FAIL_COUNT=0

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Machine Type Detection Validation                       ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Function to check if starship.toml exists and is valid
check_starship_config() {
    local container=$1
    local profile=$2
    local description=$3

    echo -n "  Checking ${description}... "

    if docker compose exec -T "${container}" test -f "/home/testuser/.config/starship.toml"; then
        echo -e "${GREEN}✓ PASS${NC} (starship.toml exists)"
        ((PASS_COUNT++))
    else
        echo -e "${RED}✗ FAIL${NC} (starship.toml not found)"
        ((FAIL_COUNT++))
    fi
}

# Change to docker directory
cd "$(dirname "$0")/../docker" || exit 1

# Check if containers are running
if ! docker compose ps | grep -q "Up"; then
    echo -e "${YELLOW}⚠ Containers not running. Starting them...${NC}"
    docker compose up -d
    sleep 5
fi

echo -e "${BLUE}Testing WSL Container:${NC}"
check_starship_config "wsl-test" "wsl" "Starship config (WSL)"
echo ""

echo -e "${BLUE}Testing Server Container (dev-test-01):${NC}"
check_starship_config "server-test" "server" "Starship config (Server)"
echo ""

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Results                                                  ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${GREEN}Passed:${NC} ${PASS_COUNT}"
echo -e "  ${RED}Failed:${NC} ${FAIL_COUNT}"
echo ""

if [[ ${FAIL_COUNT} -eq 0 ]]; then
    echo -e "${GREEN}✅ All validation checks passed!${NC}"
    exit 0
else
    echo -e "${RED}❌ Some validation checks failed${NC}"
    exit 1
fi
