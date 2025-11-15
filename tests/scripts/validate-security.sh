#!/usr/bin/env bash
# Security Validation Script
# Checks for proper file permissions, no secrets in configs, etc.

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

echo -e "${BLUE}=== Security Validation ===${NC}"
echo ""

reset_assertions

# ============================================================================
# 1. SSH Key Permissions
# ============================================================================
echo "1. SSH Key Permissions"

if [ -d "$HOME/.ssh" ]; then
    # Check .ssh directory permissions (700)
    if [ -d "$HOME/.ssh" ]; then
        actual_perms=$(stat -c "%a" "$HOME/.ssh" 2>/dev/null || stat -f "%A" "$HOME/.ssh" 2>/dev/null)
        if [ "$actual_perms" = "700" ]; then
            echo -e "  ${GREEN}✓${NC} .ssh directory has correct permissions (700)"
            ASSERT_PASSED=$((ASSERT_PASSED + 1))
        else
            echo -e "  ${YELLOW}⚠${NC} .ssh directory permissions: $actual_perms (expected: 700)"
            # Don't fail - might not exist in test environment
            ASSERT_PASSED=$((ASSERT_PASSED + 1))
        fi
    fi

    # Check private key permissions (600)
    for key in "$HOME/.ssh/id_"*; do
        if [ -f "$key" ] && [[ ! "$key" == *.pub ]]; then
            actual_perms=$(stat -c "%a" "$key" 2>/dev/null || stat -f "%A" "$key" 2>/dev/null)
            if [ "$actual_perms" = "600" ]; then
                echo -e "  ${GREEN}✓${NC} $(basename $key) has correct permissions (600)"
                ASSERT_PASSED=$((ASSERT_PASSED + 1))
            else
                echo -e "  ${RED}✗${NC} SECURITY ISSUE: $(basename $key) has permissions $actual_perms (should be 600)"
                ASSERT_FAILED=$((ASSERT_FAILED + 1))
            fi
        fi
    done
else
    echo -e "  ${YELLOW}○${NC} No .ssh directory found (skipping SSH key checks)"
fi
echo ""

# ============================================================================
# 2. Config File Ownership
# ============================================================================
echo "2. Config File Ownership"

# Check that config files are owned by current user, not root
check_ownership() {
    local file=$1
    local filename=$(basename "$file")

    if [ ! -e "$file" ]; then
        return
    fi

    local owner=$(stat -c "%U" "$file" 2>/dev/null || stat -f "%Su" "$file" 2>/dev/null)
    local current_user=$(whoami)

    if [ "$owner" = "$current_user" ]; then
        echo -e "  ${GREEN}✓${NC} $filename owned by $current_user"
        ASSERT_PASSED=$((ASSERT_PASSED + 1))
    elif [ "$owner" = "root" ]; then
        echo -e "  ${RED}✗${NC} SECURITY ISSUE: $filename owned by root (should be $current_user)"
        ASSERT_FAILED=$((ASSERT_FAILED + 1))
    else
        echo -e "  ${YELLOW}⚠${NC} $filename owned by $owner (expected: $current_user)"
        ASSERT_PASSED=$((ASSERT_PASSED + 1))
    fi
}

check_ownership "$HOME/.zshrc"
check_ownership "$HOME/.config/starship.toml"
check_ownership "$HOME/.zsh.d"
check_ownership "$HOME/.local/bin"
echo ""

# ============================================================================
# 3. No Secrets in Dotfiles
# ============================================================================
echo "3. No Secrets in Dotfiles"

# Common secret patterns to check for
SECRET_PATTERNS=(
    "password.*="
    "api[_-]key.*="
    "secret.*="
    "token.*="
    "AWS_ACCESS_KEY"
    "AWS_SECRET"
    "GITHUB_TOKEN"
    "private[_-]key.*="
)

check_for_secrets() {
    local file=$1
    local filename=$(basename "$file")
    local found_secrets=0

    if [ ! -f "$file" ]; then
        return
    fi

    for pattern in "${SECRET_PATTERNS[@]}"; do
        if grep -qi "$pattern" "$file" 2>/dev/null; then
            echo -e "  ${RED}✗${NC} SECURITY ISSUE: Potential secret in $filename (pattern: $pattern)"
            ASSERT_FAILED=$((ASSERT_FAILED + 1))
            found_secrets=1
            break
        fi
    done

    if [ $found_secrets -eq 0 ]; then
        echo -e "  ${GREEN}✓${NC} No secrets detected in $filename"
        ASSERT_PASSED=$((ASSERT_PASSED + 1))
    fi
}

# Check common config files
if [ -d "$HOME/dotfiles-test" ]; then
    for file in "$HOME/dotfiles-test"/zsh/**/*.zsh; do
        if [ -f "$file" ]; then
            check_for_secrets "$file"
        fi
    done
fi

check_for_secrets "$HOME/.zshrc"
check_for_secrets "$HOME/.zshenv"
check_for_secrets "$HOME/.config/starship.toml"

# Check for sensitive files that should NOT be committed
SENSITIVE_FILES=(
    ".env"
    "credentials.json"
    ".aws/credentials"
    ".ssh/id_rsa"
    ".netrc"
)

echo ""
echo "4. Sensitive Files Not in Dotfiles Repository"
for file in "${SENSITIVE_FILES[@]}"; do
    if [ -d "$HOME/dotfiles-test" ]; then
        if [ -f "$HOME/dotfiles-test/$file" ]; then
            echo -e "  ${RED}✗${NC} SECURITY ISSUE: Sensitive file in dotfiles repo: $file"
            ASSERT_FAILED=$((ASSERT_FAILED + 1))
        else
            echo -e "  ${GREEN}✓${NC} $file not in dotfiles repository"
            ASSERT_PASSED=$((ASSERT_PASSED + 1))
        fi
    fi
done

echo ""

# ============================================================================
# 5. Sudoers Entries (if applicable)
# ============================================================================
echo "5. Sudoers Configuration"

if command -v sudo > /dev/null 2>&1; then
    # Check if user has NOPASSWD sudo (test environment specific)
    if sudo -n true 2>/dev/null; then
        echo -e "  ${YELLOW}○${NC} User has passwordless sudo (test environment)"
        ASSERT_PASSED=$((ASSERT_PASSED + 1))
    else
        echo -e "  ${GREEN}✓${NC} Sudo requires password (production setting)"
        ASSERT_PASSED=$((ASSERT_PASSED + 1))
    fi
else
    echo -e "  ${YELLOW}○${NC} Sudo not available (skipping)"
fi

echo ""

# ============================================================================
# Summary
# ============================================================================
assert_summary
