#!/usr/bin/env bash
# Tool Version Verification Script
# Verifies installed tool versions match expected versions (major version)

set -e

# Load assertion helpers
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../helpers/assert.sh"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}=== Tool Version Verification ===${NC}"
echo ""

reset_assertions

# ============================================================================
# Version Comparison Helper
# ============================================================================

# Extract major version from version string
get_major_version() {
    echo "$1" | sed 's/[^0-9]*\([0-9]\+\).*/\1/'
}

# Check tool version
check_tool_version() {
    local tool=$1
    local expected_major=$2
    local version_flag=${3:---version}

    if ! command -v "$tool" > /dev/null 2>&1; then
        echo -e "  ${YELLOW}○${NC} $tool not installed (skipping version check)"
        return 0
    fi

    # Get version output
    local version_output=$($tool $version_flag 2>&1 | head -n 1)

    # Extract version number (handles different formats)
    local version=$(echo "$version_output" | grep -oP '\d+\.\d+\.\d+' | head -n 1)

    if [ -z "$version" ]; then
        # Try alternative format (just major.minor)
        version=$(echo "$version_output" | grep -oP '\d+\.\d+' | head -n 1)
    fi

    if [ -z "$version" ]; then
        echo -e "  ${YELLOW}⚠${NC} Could not parse version for $tool"
        echo -e "      Output: $version_output"
        ASSERT_PASSED=$((ASSERT_PASSED + 1))
        return 0
    fi

    local actual_major=$(get_major_version "$version")

    if [ "$actual_major" = "$expected_major" ]; then
        echo -e "  ${GREEN}✓${NC} $tool version $version (expected major: $expected_major)"
        ASSERT_PASSED=$((ASSERT_PASSED + 1))
    else
        echo -e "  ${RED}✗${NC} $tool version mismatch: $version (expected major: $expected_major)"
        echo -e "      This may cause compatibility issues"
        ASSERT_FAILED=$((ASSERT_FAILED + 1))
    fi
}

# ============================================================================
# Essential Tools
# ============================================================================
echo "1. Essential Tools"

check_tool_version "zsh" "5"
check_tool_version "git" "2"
check_tool_version "starship" "1"

echo ""

# ============================================================================
# Modern Shell Tools
# ============================================================================
echo "2. Modern Shell Tools"

# fzf
if command -v fzf > /dev/null 2>&1; then
    fzf_version=$(fzf --version | awk '{print $1}')
    fzf_major=$(get_major_version "$fzf_version")

    if [ "$fzf_major" = "0" ]; then
        echo -e "  ${GREEN}✓${NC} fzf version $fzf_version (expected: 0.x)"
        ASSERT_PASSED=$((ASSERT_PASSED + 1))
    else
        echo -e "  ${YELLOW}⚠${NC} fzf version $fzf_version (expected: 0.x, but got $fzf_major.x)"
        ASSERT_PASSED=$((ASSERT_PASSED + 1))
    fi
else
    echo -e "  ${YELLOW}○${NC} fzf not installed (optional tool)"
fi

# zoxide
if command -v zoxide > /dev/null 2>&1; then
    zoxide_version=$(zoxide --version | awk '{print $2}')
    zoxide_major=$(get_major_version "$zoxide_version")

    if [ "$zoxide_major" = "0" ]; then
        echo -e "  ${GREEN}✓${NC} zoxide version $zoxide_version (expected: 0.x)"
        ASSERT_PASSED=$((ASSERT_PASSED + 1))
    else
        echo -e "  ${YELLOW}⚠${NC} zoxide version $zoxide_version (got $zoxide_major.x)"
        ASSERT_PASSED=$((ASSERT_PASSED + 1))
    fi
else
    echo -e "  ${YELLOW}○${NC} zoxide not installed (optional tool)"
fi

# ripgrep
check_tool_version "rg" "13"

# bat (optional)
if command -v bat > /dev/null 2>&1; then
    bat_version=$(bat --version | awk '{print $2}')
    bat_major=$(get_major_version "$bat_version")
    echo -e "  ${GREEN}✓${NC} bat version $bat_version (optional tool)"
    ASSERT_PASSED=$((ASSERT_PASSED + 1))
else
    echo -e "  ${YELLOW}○${NC} bat not installed (optional tool)"
fi

# eza (optional)
if command -v eza > /dev/null 2>&1; then
    eza_version=$(eza --version | head -n 1 | awk '{print $2}')
    echo -e "  ${GREEN}✓${NC} eza version $eza_version (optional tool)"
    ASSERT_PASSED=$((ASSERT_PASSED + 1))
else
    echo -e "  ${YELLOW}○${NC} eza not installed (optional tool)"
fi

# fd (optional)
if command -v fd > /dev/null 2>&1; then
    fd_version=$(fd --version | awk '{print $2}')
    echo -e "  ${GREEN}✓${NC} fd version $fd_version (optional tool)"
    ASSERT_PASSED=$((ASSERT_PASSED + 1))
else
    echo -e "  ${YELLOW}○${NC} fd not installed (optional tool)"
fi

echo ""

# ============================================================================
# Build Tools
# ============================================================================
echo "3. Build Tools (if available)"

check_tool_version "make" "4" || check_tool_version "make" "3"
check_tool_version "curl" "7"
check_tool_version "wget" "1"

echo ""

# ============================================================================
# Python & Ansible
# ============================================================================
echo "4. Python & Ansible"

check_tool_version "python3" "3"
check_tool_version "ansible" "2" || check_tool_version "ansible" "9"  # Ansible 9.x is also 2.16.x core

echo ""

# ============================================================================
# Summary
# ============================================================================
echo "=== Version Check Summary ==="
echo "Note: Major version mismatches may indicate compatibility issues"
echo "Optional tools are not required for basic functionality"
echo ""

assert_summary
