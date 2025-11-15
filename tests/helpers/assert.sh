#!/usr/bin/env bash
# Test Assertion Helper Functions
# Provides reusable assertion functions for test scripts
#
# Usage:
#   source tests/helpers/assert.sh
#   assert_file_exists "/path/to/file"
#   assert_contains "/path/to/file" "pattern"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Counters
ASSERT_PASSED=0
ASSERT_FAILED=0

# Reset counters
reset_assertions() {
    ASSERT_PASSED=0
    ASSERT_FAILED=0
}

# Print assertion summary
assert_summary() {
    echo ""
    echo "=== Assertion Summary ==="
    echo -e "Passed: ${GREEN}${ASSERT_PASSED}${NC}"
    echo -e "Failed: ${RED}${ASSERT_FAILED}${NC}"
    echo ""

    if [ $ASSERT_FAILED -gt 0 ]; then
        echo -e "${RED}❌ Some assertions failed${NC}"
        return 1
    else
        echo -e "${GREEN}✅ All assertions passed${NC}"
        return 0
    fi
}

# Assert file exists
assert_file_exists() {
    local file=$1
    local message=${2:-"File should exist: $file"}

    if [ -f "$file" ]; then
        echo -e "${GREEN}✓${NC} $message"
        ASSERT_PASSED=$((ASSERT_PASSED + 1))
        return 0
    else
        echo -e "${RED}✗${NC} FAILED: $message"
        ASSERT_FAILED=$((ASSERT_FAILED + 1))
        return 1
    fi
}

# Assert directory exists
assert_dir_exists() {
    local dir=$1
    local message=${2:-"Directory should exist: $dir"}

    if [ -d "$dir" ]; then
        echo -e "${GREEN}✓${NC} $message"
        ASSERT_PASSED=$((ASSERT_PASSED + 1))
        return 0
    else
        echo -e "${RED}✗${NC} FAILED: $message"
        ASSERT_FAILED=$((ASSERT_FAILED + 1))
        return 1
    fi
}

# Assert file contains pattern
assert_contains() {
    local file=$1
    local pattern=$2
    local message=${3:-"File should contain '$pattern': $file"}

    if [ ! -f "$file" ]; then
        echo -e "${RED}✗${NC} FAILED: File does not exist: $file"
        ASSERT_FAILED=$((ASSERT_FAILED + 1))
        return 1
    fi

    if grep -q "$pattern" "$file"; then
        echo -e "${GREEN}✓${NC} $message"
        ASSERT_PASSED=$((ASSERT_PASSED + 1))
        return 0
    else
        echo -e "${RED}✗${NC} FAILED: $message"
        ASSERT_FAILED=$((ASSERT_FAILED + 1))
        return 1
    fi
}

# Assert file does NOT contain pattern
assert_not_contains() {
    local file=$1
    local pattern=$2
    local message=${3:-"File should NOT contain '$pattern': $file"}

    if [ ! -f "$file" ]; then
        echo -e "${RED}✗${NC} FAILED: File does not exist: $file"
        ASSERT_FAILED=$((ASSERT_FAILED + 1))
        return 1
    fi

    if ! grep -q "$pattern" "$file"; then
        echo -e "${GREEN}✓${NC} $message"
        ASSERT_PASSED=$((ASSERT_PASSED + 1))
        return 0
    else
        echo -e "${RED}✗${NC} FAILED: $message"
        ASSERT_FAILED=$((ASSERT_FAILED + 1))
        return 1
    fi
}

# Assert command exists
assert_command_exists() {
    local cmd=$1
    local message=${2:-"Command should exist: $cmd"}

    if command -v "$cmd" > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} $message"
        ASSERT_PASSED=$((ASSERT_PASSED + 1))
        return 0
    else
        echo -e "${RED}✗${NC} FAILED: $message"
        ASSERT_FAILED=$((ASSERT_FAILED + 1))
        return 1
    fi
}

# Assert two strings are equal
assert_equal() {
    local actual=$1
    local expected=$2
    local message=${3:-"Values should be equal"}

    if [ "$actual" = "$expected" ]; then
        echo -e "${GREEN}✓${NC} $message (got: '$actual')"
        ASSERT_PASSED=$((ASSERT_PASSED + 1))
        return 0
    else
        echo -e "${RED}✗${NC} FAILED: $message"
        echo -e "  Expected: '${expected}'"
        echo -e "  Got:      '${actual}'"
        ASSERT_FAILED=$((ASSERT_FAILED + 1))
        return 1
    fi
}

# Assert file permissions
assert_permissions() {
    local file=$1
    local expected_perms=$2
    local message=${3:-"File permissions should be $expected_perms: $file"}

    if [ ! -e "$file" ]; then
        echo -e "${RED}✗${NC} FAILED: File does not exist: $file"
        ASSERT_FAILED=$((ASSERT_FAILED + 1))
        return 1
    fi

    local actual_perms=$(stat -c "%a" "$file" 2>/dev/null || stat -f "%A" "$file" 2>/dev/null)

    if [ "$actual_perms" = "$expected_perms" ]; then
        echo -e "${GREEN}✓${NC} $message"
        ASSERT_PASSED=$((ASSERT_PASSED + 1))
        return 0
    else
        echo -e "${RED}✗${NC} FAILED: $message"
        echo -e "  Expected: ${expected_perms}"
        echo -e "  Got:      ${actual_perms}"
        ASSERT_FAILED=$((ASSERT_FAILED + 1))
        return 1
    fi
}

# Assert symlink points to target
assert_symlink() {
    local link=$1
    local expected_target=$2
    local message=${3:-"Symlink should point to $expected_target: $link"}

    if [ ! -L "$link" ]; then
        echo -e "${RED}✗${NC} FAILED: Not a symlink: $link"
        ASSERT_FAILED=$((ASSERT_FAILED + 1))
        return 1
    fi

    local actual_target=$(readlink "$link")

    if [ "$actual_target" = "$expected_target" ]; then
        echo -e "${GREEN}✓${NC} $message"
        ASSERT_PASSED=$((ASSERT_PASSED + 1))
        return 0
    else
        echo -e "${RED}✗${NC} FAILED: $message"
        echo -e "  Expected: ${expected_target}"
        echo -e "  Got:      ${actual_target}"
        ASSERT_FAILED=$((ASSERT_FAILED + 1))
        return 1
    fi
}

# Assert environment variable is set
assert_env_set() {
    local var_name=$1
    local message=${2:-"Environment variable should be set: $var_name"}

    if [ -n "${!var_name}" ]; then
        echo -e "${GREEN}✓${NC} $message (value: '${!var_name}')"
        ASSERT_PASSED=$((ASSERT_PASSED + 1))
        return 0
    else
        echo -e "${RED}✗${NC} FAILED: $message"
        ASSERT_FAILED=$((ASSERT_FAILED + 1))
        return 1
    fi
}

# Assert PATH contains directory
assert_path_contains() {
    local dir=$1
    local message=${2:-"PATH should contain: $dir"}

    if echo "$PATH" | grep -q "$dir"; then
        echo -e "${GREEN}✓${NC} $message"
        ASSERT_PASSED=$((ASSERT_PASSED + 1))
        return 0
    else
        echo -e "${RED}✗${NC} FAILED: $message"
        echo -e "  Current PATH: $PATH"
        ASSERT_FAILED=$((ASSERT_FAILED + 1))
        return 1
    fi
}
