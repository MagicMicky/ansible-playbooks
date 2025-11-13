#!/usr/bin/env bash
# Master test runner - executes all test suites
# Run this to validate the entire ansible-playbooks repository

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ANSIBLE_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

cd "${ANSIBLE_DIR}"

echo -e "${BLUE}╔════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Ansible Playbooks - Complete Test Suite  ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════╝${NC}"
echo ""

TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Function to run test
run_test() {
    local name=$1
    local command=$2

    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    echo ""
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}Test $TOTAL_TESTS: $name${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    if eval "$command"; then
        echo -e "${GREEN}✅ PASSED: $name${NC}"
        PASSED_TESTS=$((PASSED_TESTS + 1))
        return 0
    else
        echo -e "${RED}❌ FAILED: $name${NC}"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        return 1
    fi
}

# Install Ansible dependencies
echo -e "${BLUE}Installing Ansible dependencies...${NC}"
# Use --ignore-errors to skip private repos (e.g., work-tasks)
ansible-galaxy install -r requirements.yml --ignore-errors || true
echo ""

# Test 1: Syntax validation
run_test "Syntax Validation" \
    "${SCRIPT_DIR}/validate-syntax.sh"

# Test 2: WSL playbook (check mode)
run_test "WSL Playbook (Check Mode)" \
    "ansible-playbook playbooks/wsl/setup.yml -i tests/inventories/wsl.yml --check"

# Test 3: WSL playbook (apply)
run_test "WSL Playbook (Apply)" \
    "ansible-playbook playbooks/wsl/setup.yml -i tests/inventories/wsl.yml"

# Test 4: Server shell playbook (check mode)
run_test "Server Shell Playbook (Check Mode)" \
    "ansible-playbook playbooks/servers/shell.yml -i tests/inventories/ubuntu.yml --check"

# Test 5: Server shell playbook (apply)
run_test "Server Shell Playbook (Apply)" \
    "ansible-playbook playbooks/servers/shell.yml -i tests/inventories/ubuntu.yml"

# Test 6: WSL idempotency
# Idempotency failures should be fatal - playbooks MUST be idempotent
run_test "WSL Playbook Idempotency" \
    "${SCRIPT_DIR}/test-idempotency.sh playbooks/wsl/setup.yml tests/inventories/wsl.yml"

# Test 7: Shell validation
# Run as current user (testuser in Docker), not root
# This ensures we validate the same environment where playbook installed
run_test "Shell Configuration Validation" \
    "bash ${SCRIPT_DIR}/validate-shell.sh"

# Test 8: Tools check
# Run as current user to check actual installed tools
run_test "Installed Tools Check" \
    "bash ${SCRIPT_DIR}/check-tools.sh"

# Summary
echo ""
echo -e "${BLUE}╔════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║           Test Suite Summary               ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════╝${NC}"
echo ""
echo "Total tests:  $TOTAL_TESTS"
echo -e "Passed:       ${GREEN}$PASSED_TESTS${NC}"
echo -e "Failed:       ${RED}$FAILED_TESTS${NC}"
echo ""

if [ $FAILED_TESTS -eq 0 ]; then
    echo -e "${GREEN}✅ ALL TESTS PASSED${NC}"
    exit 0
else
    echo -e "${RED}❌ SOME TESTS FAILED${NC}"
    exit 1
fi
