#!/usr/bin/env bash
# Isolated test runner - executes tests in dedicated containers
# Each playbook runs in its own container to prevent state pollution
#
# Architecture:
#   - wsl-test container: WSL playbook + validation + idempotency
#   - server-test container: Server playbook + validation + idempotency
#
# This ensures complete test independence and matches CI behavior

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ANSIBLE_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
DOCKER_DIR="${ANSIBLE_DIR}/tests/docker"

cd "${ANSIBLE_DIR}"

echo -e "${BLUE}╔════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Ansible Playbooks - Isolated Test Suite  ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════╝${NC}"
echo ""

TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Function to run test in specific container
run_test_in_container() {
    local container=$1
    local name=$2
    local command=$3

    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    echo ""
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}Test $TOTAL_TESTS: $name${NC}"
    echo -e "${YELLOW}Container: $container${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    if cd "${DOCKER_DIR}" && docker compose exec -T "$container" bash -c "cd /ansible && $command"; then
        echo -e "${GREEN}✅ PASSED: $name${NC}"
        PASSED_TESTS=$((PASSED_TESTS + 1))
        return 0
    else
        echo -e "${RED}❌ FAILED: $name${NC}"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        return 1
    fi
}

# Install Ansible dependencies once in each container
echo -e "${BLUE}Installing Ansible dependencies in containers...${NC}"
cd "${DOCKER_DIR}"
docker compose exec -T wsl-test bash -c "cd /ansible && ansible-galaxy install -r requirements.yml --ignore-errors" || true
docker compose exec -T server-test bash -c "cd /ansible && ansible-galaxy install -r requirements.yml --ignore-errors" || true
echo ""

# ============================================================================
# Test Suite 1: Syntax Validation (runs once, not container-specific)
# ============================================================================
echo -e "${BLUE}═══════════════════════════════════════════${NC}"
echo -e "${BLUE}  Phase 1: Syntax Validation${NC}"
echo -e "${BLUE}═══════════════════════════════════════════${NC}"

TOTAL_TESTS=$((TOTAL_TESTS + 1))
echo ""
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}Test $TOTAL_TESTS: Syntax Validation${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

if cd "${ANSIBLE_DIR}" && ./tests/scripts/validate-syntax.sh; then
    echo -e "${GREEN}✅ PASSED: Syntax Validation${NC}"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${RED}❌ FAILED: Syntax Validation${NC}"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi

# ============================================================================
# Test Suite 2: WSL Playbook (in wsl-test container)
# ============================================================================
echo ""
echo -e "${BLUE}═══════════════════════════════════════════${NC}"
echo -e "${BLUE}  Phase 2: WSL Playbook Tests${NC}"
echo -e "${BLUE}═══════════════════════════════════════════${NC}"

run_test_in_container "wsl-test" \
    "WSL Playbook (Check Mode)" \
    "ansible-playbook playbooks/wsl/setup.yml -i tests/inventories/wsl.yml --check"

run_test_in_container "wsl-test" \
    "WSL Playbook (Apply)" \
    "ansible-playbook playbooks/wsl/setup.yml -i tests/inventories/wsl.yml"

run_test_in_container "wsl-test" \
    "WSL Shell Validation" \
    "bash tests/scripts/validate-shell.sh"

run_test_in_container "wsl-test" \
    "WSL Idempotency" \
    "bash tests/scripts/test-idempotency.sh playbooks/wsl/setup.yml tests/inventories/wsl.yml"

run_test_in_container "wsl-test" \
    "WSL Security Validation" \
    "bash tests/scripts/validate-security.sh"

run_test_in_container "wsl-test" \
    "WSL Tool Versions" \
    "bash tests/scripts/validate-tool-versions.sh"

run_test_in_container "wsl-test" \
    "WSL Profile Isolation" \
    "bash tests/scripts/validate-profile-isolation.sh"

run_test_in_container "wsl-test" \
    "WSL Config Content" \
    "bash tests/scripts/validate-config-content.sh"

run_test_in_container "wsl-test" \
    "WSL Performance Tracking" \
    "bash tests/scripts/track-performance.sh --check-only"

# ============================================================================
# Test Suite 3: Server Playbook (in server-test container)
# ============================================================================
echo ""
echo -e "${BLUE}═══════════════════════════════════════════${NC}"
echo -e "${BLUE}  Phase 3: Server Playbook Tests${NC}"
echo -e "${BLUE}═══════════════════════════════════════════${NC}"

run_test_in_container "server-test" \
    "Server Playbook (Check Mode)" \
    "ansible-playbook playbooks/servers/setup.yml -i tests/inventories/ubuntu.yml --check"

run_test_in_container "server-test" \
    "Server Playbook (Apply)" \
    "ansible-playbook playbooks/servers/setup.yml -i tests/inventories/ubuntu.yml"

run_test_in_container "server-test" \
    "Server Shell Validation" \
    "bash tests/scripts/validate-shell.sh"

run_test_in_container "server-test" \
    "Server Idempotency" \
    "bash tests/scripts/test-idempotency.sh playbooks/servers/setup.yml tests/inventories/ubuntu.yml"

run_test_in_container "server-test" \
    "Server Security Validation" \
    "bash tests/scripts/validate-security.sh"

run_test_in_container "server-test" \
    "Server Tool Versions" \
    "bash tests/scripts/validate-tool-versions.sh"

run_test_in_container "server-test" \
    "Server Profile Isolation" \
    "bash tests/scripts/validate-profile-isolation.sh"

run_test_in_container "server-test" \
    "Server Config Content" \
    "bash tests/scripts/validate-config-content.sh"

run_test_in_container "server-test" \
    "Server Performance Tracking" \
    "bash tests/scripts/track-performance.sh --check-only"

# ============================================================================
# Test Summary
# ============================================================================
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
    echo ""
    echo -e "${BLUE}Test isolation: ✓ WSL and Server tests ran in separate containers${NC}"
    echo -e "${BLUE}Idempotency: ✓ Both playbooks tested for idempotency${NC}"
    echo -e "${BLUE}Security: ✓ Security validation passed for both environments${NC}"
    echo -e "${BLUE}Versions: ✓ Tool versions verified${NC}"
    echo -e "${BLUE}Performance: ✓ Shell startup time tracked${NC}"
    exit 0
else
    echo -e "${RED}❌ SOME TESTS FAILED${NC}"
    echo ""
    echo "Review the output above for details"
    exit 1
fi
