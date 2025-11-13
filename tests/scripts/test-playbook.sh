#!/usr/bin/env bash
# Generic playbook test runner
# Usage: ./test-playbook.sh <playbook> <inventory> [--check]

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

if [ $# -lt 2 ]; then
    echo "Usage: $0 <playbook> <inventory> [--check]"
    echo ""
    echo "Examples:"
    echo "  $0 playbooks/wsl/setup.yml tests/inventories/wsl.yml"
    echo "  $0 playbooks/servers/base.yml tests/inventories/ubuntu.yml --check"
    exit 1
fi

PLAYBOOK="$1"
INVENTORY="$2"
CHECK_MODE=""

if [ "$3" = "--check" ]; then
    CHECK_MODE="--check"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ANSIBLE_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

cd "${ANSIBLE_DIR}"

# Ensure playbook and inventory exist
if [ ! -f "$PLAYBOOK" ]; then
    echo -e "${RED}ERROR: Playbook not found: $PLAYBOOK${NC}"
    exit 1
fi

if [ ! -f "$INVENTORY" ]; then
    echo -e "${RED}ERROR: Inventory not found: $INVENTORY${NC}"
    exit 1
fi

echo -e "${BLUE}=== Running Ansible Playbook ===${NC}"
echo "Playbook: $PLAYBOOK"
echo "Inventory: $INVENTORY"
echo "Check mode: ${CHECK_MODE:-disabled}"
echo ""

# Record start time
START_TIME=$(date +%s)

# Run playbook
if ansible-playbook "$PLAYBOOK" -i "$INVENTORY" $CHECK_MODE -vv; then
    # Record end time
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))

    echo ""
    echo -e "${GREEN}✅ Playbook completed successfully${NC}"
    echo "Duration: ${DURATION}s"
    exit 0
else
    echo ""
    echo -e "${RED}❌ Playbook FAILED${NC}"
    exit 1
fi
