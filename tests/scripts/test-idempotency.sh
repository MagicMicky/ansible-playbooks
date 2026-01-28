#!/usr/bin/env bash
# Test playbook idempotency
# Runs playbook twice and verifies no changes on second run

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

if [ $# -lt 2 ]; then
    echo "Usage: $0 <playbook> <inventory> [extra-vars]"
    echo ""
    echo "Examples:"
    echo "  $0 playbooks/wsl/setup.yml tests/inventories/wsl.yml"
    echo "  $0 playbooks/servers/setup.yml tests/inventories/ubuntu.yml"
    echo "  $0 playbooks/servers/setup.yml tests/inventories/ubuntu.yml '{\"server_users\": [...]}'"
    exit 1
fi

PLAYBOOK="$1"
INVENTORY="$2"
EXTRA_VARS="${3:-}"

# Build extra vars argument if provided
EXTRA_VARS_ARG=""
if [ -n "$EXTRA_VARS" ]; then
    EXTRA_VARS_ARG="-e $EXTRA_VARS"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ANSIBLE_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

cd "${ANSIBLE_DIR}"

echo -e "${BLUE}=== Testing Playbook Idempotency ===${NC}"
echo "Playbook: $PLAYBOOK"
echo "Inventory: $INVENTORY"
echo ""

# Ensure playbook and inventory exist
if [ ! -f "$PLAYBOOK" ]; then
    echo -e "${RED}ERROR: Playbook not found: $PLAYBOOK${NC}"
    exit 1
fi

if [ ! -f "$INVENTORY" ]; then
    echo -e "${RED}ERROR: Inventory not found: $INVENTORY${NC}"
    exit 1
fi

# First run
echo -e "${YELLOW}>>> First run (applying changes)...${NC}"
if ! ansible-playbook "$PLAYBOOK" -i "$INVENTORY" $EXTRA_VARS_ARG; then
    echo -e "${RED}❌ First run FAILED${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}>>> Second run (testing idempotency)...${NC}"

# Second run - capture output
OUTPUT=$(mktemp)
if ! ansible-playbook "$PLAYBOOK" -i "$INVENTORY" $EXTRA_VARS_ARG | tee "$OUTPUT"; then
    echo -e "${RED}❌ Second run FAILED${NC}"
    rm -f "$OUTPUT"
    exit 1
fi

# Check for changes in output
if grep -q "changed=0" "$OUTPUT"; then
    echo ""
    echo -e "${GREEN}✅ Idempotency test PASSED${NC}"
    echo "No changes detected on second run"
    rm -f "$OUTPUT"
    exit 0
else
    # Count changes
    CHANGES=$(grep -o "changed=[0-9]*" "$OUTPUT" | head -1 | cut -d= -f2)
    echo ""
    echo -e "${RED}❌ Idempotency test FAILED${NC}"
    echo "Detected $CHANGES changes on second run"
    echo ""
    echo "Playbooks should be idempotent (no changes when run twice)"
    rm -f "$OUTPUT"
    exit 1
fi
