#!/usr/bin/env bash
# Validation script for machine type detection
# Checks that generated starship-env.zsh contains expected values for each container type

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

# Function to check a value in a file
check_value() {
    local container=$1
    local file=$2
    local expected_var=$3
    local expected_value=$4
    local description=$5

    echo -n "  Checking ${description}... "

    if docker compose exec -T "${container}" test -f "${file}"; then
        actual_value=$(docker compose exec -T "${container}" grep "^export ${expected_var}=" "${file}" | cut -d'"' -f2)

        if [[ "${actual_value}" == "${expected_value}" ]]; then
            echo -e "${GREEN}✓ PASS${NC} (${actual_value})"
            ((PASS_COUNT++))
        else
            echo -e "${RED}✗ FAIL${NC} (expected: ${expected_value}, got: ${actual_value})"
            ((FAIL_COUNT++))
        fi
    else
        echo -e "${RED}✗ FAIL${NC} (file not found)"
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
check_value "wsl-test" "/home/testuser/.config/shell/starship-env.zsh" "MACHINE_TYPE" "wsl" "MACHINE_TYPE"
check_value "wsl-test" "/home/testuser/.config/shell/starship-env.zsh" "STARSHIP_ENV_CHAR" "λ" "character (lambda)"
check_value "wsl-test" "/home/testuser/.config/shell/starship-env.zsh" "STARSHIP_ENV_COLOR" "#82AAFF" "color (blue)"
check_value "wsl-test" "/home/testuser/.config/shell/starship-env.zsh" "STARSHIP_SHOW_HOSTNAME" "true" "show hostname"
echo ""

echo -e "${BLUE}Testing Server Container (dev-test-01):${NC}"
check_value "server-test" "/home/testuser/.config/shell/starship-env.zsh" "MACHINE_TYPE" "server" "MACHINE_TYPE"
check_value "server-test" "/home/testuser/.config/shell/starship-env.zsh" "STARSHIP_ENV_CHAR" "·" "character (middle dot)"
check_value "server-test" "/home/testuser/.config/shell/starship-env.zsh" "STARSHIP_ENV_COLOR" "#FFB86C" "color (orange - dev server)"
check_value "server-test" "/home/testuser/.config/shell/starship-env.zsh" "STARSHIP_SHOW_HOSTNAME" "true" "show hostname"
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
