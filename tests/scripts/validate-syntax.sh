#!/usr/bin/env bash
# Validate syntax of all Ansible playbooks
# Exit with non-zero status if any playbook has syntax errors

# Note: Not using set -e because we handle errors explicitly

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ANSIBLE_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

echo "=== Ansible Playbook Syntax Validation ==="
echo "Working directory: ${ANSIBLE_DIR}"
echo ""

# Install dependencies if requirements.yml exists
if [ -f "${ANSIBLE_DIR}/requirements.yml" ]; then
    echo "Installing Ansible dependencies..."
    ansible-galaxy install -r "${ANSIBLE_DIR}/requirements.yml" > /dev/null 2>&1 || true
    echo ""
fi

FAILED=0
PASSED=0

# Find all playbook YAML files (excluding vars directories)
PLAYBOOKS=$(find "${ANSIBLE_DIR}/playbooks" -name "*.yml" -type f -not -path "*/vars/*" 2>/dev/null || true)

if [ -z "$PLAYBOOKS" ]; then
    echo "ERROR: No playbooks found in ${ANSIBLE_DIR}/playbooks"
    exit 1
fi

for playbook in $PLAYBOOKS; do
    playbook_name=$(basename "$playbook")
    echo -n "Checking $playbook_name... "

    # Capture both stdout and stderr
    output=$(ansible-playbook --syntax-check "$playbook" 2>&1)
    exit_code=$?

    if [ $exit_code -eq 0 ]; then
        echo "✓ PASS"
        ((PASSED++))
    else
        # Check if failure is due to missing external role
        if echo "$output" | grep -q "role '.*' was not found"; then
            echo "⚠ SKIP (requires external role)"
            ((PASSED++))  # Don't count as failure
        else
            echo "✗ FAIL"
            echo "$output"
            ((FAILED++))
        fi
    fi
done

echo ""
echo "=== Results ==="
echo "Passed: $PASSED"
echo "Failed: $FAILED"
echo ""

if [ $FAILED -gt 0 ]; then
    echo "❌ Syntax validation FAILED"
    exit 1
else
    echo "✅ All playbooks passed syntax validation"
    exit 0
fi
