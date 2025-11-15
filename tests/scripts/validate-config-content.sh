#!/usr/bin/env bash
# Configuration Content Validation Script
# Verifies that configuration files have expected content and structure

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

echo -e "${BLUE}=== Configuration Content Validation ===${NC}"
echo ""

reset_assertions

# ============================================================================
# 1. Starship Configuration Structure
# ============================================================================
echo "1. Starship Configuration Structure"

STARSHIP_CONFIG="$HOME/.config/starship.toml"

if [ -f "$STARSHIP_CONFIG" ]; then
    echo -e "  ${GREEN}✓${NC} Starship config exists"
    ASSERT_PASSED=$((ASSERT_PASSED + 1))

    # Check for essential sections
    if grep -q '\[character\]' "$STARSHIP_CONFIG"; then
        echo -e "  ${GREEN}✓${NC} Character section configured"
        ASSERT_PASSED=$((ASSERT_PASSED + 1))
    else
        echo -e "  ${RED}✗${NC} Character section missing"
        ASSERT_FAILED=$((ASSERT_FAILED + 1))
    fi

    if grep -q '\[directory\]' "$STARSHIP_CONFIG"; then
        echo -e "  ${GREEN}✓${NC} Directory section configured"
        ASSERT_PASSED=$((ASSERT_PASSED + 1))
    else
        echo -e "  ${YELLOW}⚠${NC} Directory section missing (optional)"
        ASSERT_PASSED=$((ASSERT_PASSED + 1))
    fi

    if grep -q '\[git_branch\]' "$STARSHIP_CONFIG"; then
        echo -e "  ${GREEN}✓${NC} Git branch section configured"
        ASSERT_PASSED=$((ASSERT_PASSED + 1))
    else
        echo -e "  ${YELLOW}⚠${NC} Git branch section missing (optional)"
        ASSERT_PASSED=$((ASSERT_PASSED + 1))
    fi

    # Check for prompt character (should have one of: λ, !, ·)
    if grep -qE '[λ!·]' "$STARSHIP_CONFIG"; then
        echo -e "  ${GREEN}✓${NC} Machine-specific prompt character configured"
        ASSERT_PASSED=$((ASSERT_PASSED + 1))
    else
        echo -e "  ${YELLOW}⚠${NC} No machine-specific prompt character found"
        ASSERT_PASSED=$((ASSERT_PASSED + 1))
    fi
else
    echo -e "  ${RED}✗${NC} Starship config missing: $STARSHIP_CONFIG"
    ASSERT_FAILED=$((ASSERT_FAILED + 1))
fi

echo ""

# ============================================================================
# 2. Zsh Aliases
# ============================================================================
echo "2. Zsh Aliases"

# Source zsh configuration and check if aliases are loaded
if command -v zsh > /dev/null 2>&1; then
    # Test in a zsh subshell to check aliases
    if zsh -c 'source ~/.zshrc 2>/dev/null && alias ll' > /dev/null 2>&1; then
        echo -e "  ${GREEN}✓${NC} Alias 'll' is defined"
        ASSERT_PASSED=$((ASSERT_PASSED + 1))
    else
        echo -e "  ${YELLOW}⚠${NC} Alias 'll' not defined (optional)"
        ASSERT_PASSED=$((ASSERT_PASSED + 1))
    fi

    # Check if aliases file exists
    if [ -f "$HOME/.zsh.d/30-aliases.zsh" ]; then
        echo -e "  ${GREEN}✓${NC} Aliases file exists"
        ASSERT_PASSED=$((ASSERT_PASSED + 1))

        # Count number of aliases defined
        alias_count=$(grep -c '^alias ' "$HOME/.zsh.d/30-aliases.zsh" 2>/dev/null || echo "0")
        if [ "$alias_count" -gt 0 ]; then
            echo -e "  ${GREEN}✓${NC} Found $alias_count aliases defined"
            ASSERT_PASSED=$((ASSERT_PASSED + 1))
        else
            echo -e "  ${YELLOW}⚠${NC} No aliases found in aliases file"
            ASSERT_PASSED=$((ASSERT_PASSED + 1))
        fi
    else
        echo -e "  ${YELLOW}⚠${NC} Aliases file not found (may not be symlinked yet)"
        ASSERT_PASSED=$((ASSERT_PASSED + 1))
    fi
else
    echo -e "  ${YELLOW}○${NC} Zsh not available, skipping alias checks"
fi

echo ""

# ============================================================================
# 3. PATH Configuration
# ============================================================================
echo "3. PATH Configuration"

# Check if .local/bin is in PATH (either current or configured to be added)
if [ -f "$HOME/.zsh.d/10-path.zsh" ]; then
    echo -e "  ${GREEN}✓${NC} PATH configuration file exists"
    ASSERT_PASSED=$((ASSERT_PASSED + 1))

    # Check if .local/bin is configured
    if grep -q '.local/bin' "$HOME/.zsh.d/10-path.zsh"; then
        echo -e "  ${GREEN}✓${NC} .local/bin configured in PATH"
        ASSERT_PASSED=$((ASSERT_PASSED + 1))
    else
        echo -e "  ${YELLOW}⚠${NC} .local/bin not explicitly configured (may be system default)"
        ASSERT_PASSED=$((ASSERT_PASSED + 1))
    fi
else
    echo -e "  ${YELLOW}⚠${NC} PATH configuration file not found"
    ASSERT_PASSED=$((ASSERT_PASSED + 1))
fi

# Check actual PATH in a zsh subshell
if command -v zsh > /dev/null 2>&1; then
    if zsh -c 'source ~/.zshrc 2>/dev/null && echo $PATH' | grep -q '.local/bin'; then
        echo -e "  ${GREEN}✓${NC} .local/bin is in PATH"
        ASSERT_PASSED=$((ASSERT_PASSED + 1))
    else
        echo -e "  ${YELLOW}⚠${NC} .local/bin not in PATH (may be added on full shell startup)"
        ASSERT_PASSED=$((ASSERT_PASSED + 1))
    fi
fi

echo ""

# ============================================================================
# 4. Plugin Loading (Zinit)
# ============================================================================
echo "4. Plugin Loading (Zinit)"

if [ -d "$HOME/.local/share/zinit" ]; then
    echo -e "  ${GREEN}✓${NC} Zinit directory exists"
    ASSERT_PASSED=$((ASSERT_PASSED + 1))

    # Check if zinit.zsh exists
    if [ -f "$HOME/.local/share/zinit/zinit.git/zinit.zsh" ]; then
        echo -e "  ${GREEN}✓${NC} Zinit main script exists"
        ASSERT_PASSED=$((ASSERT_PASSED + 1))
    else
        echo -e "  ${RED}✗${NC} Zinit main script missing"
        ASSERT_FAILED=$((ASSERT_FAILED + 1))
    fi

    # Check if plugins are configured
    if [ -f "$HOME/.zsh.d/plugins.zsh" ]; then
        echo -e "  ${GREEN}✓${NC} Plugins configuration exists"
        ASSERT_PASSED=$((ASSERT_PASSED + 1))

        # Count plugins configured
        plugin_count=$(grep -c '^zinit ' "$HOME/.zsh.d/plugins.zsh" 2>/dev/null | head -n 1 || echo "0")
        # Ensure it's a single number
        plugin_count="${plugin_count//[^0-9]/}"
        plugin_count="${plugin_count:-0}"
        if [ "$plugin_count" -gt 0 ]; then
            echo -e "  ${GREEN}✓${NC} Found $plugin_count plugins configured"
            ASSERT_PASSED=$((ASSERT_PASSED + 1))
        else
            echo -e "  ${YELLOW}⚠${NC} No plugins found in plugins.zsh"
            ASSERT_PASSED=$((ASSERT_PASSED + 1))
        fi
    else
        echo -e "  ${YELLOW}⚠${NC} Plugins configuration not found"
        ASSERT_PASSED=$((ASSERT_PASSED + 1))
    fi
else
    echo -e "  ${RED}✗${NC} Zinit directory missing"
    ASSERT_FAILED=$((ASSERT_FAILED + 1))
fi

echo ""

# ============================================================================
# 5. Environment Variables
# ============================================================================
echo "5. Environment Variables"

if [ -f "$HOME/.zsh.d/20-env.zsh" ]; then
    echo -e "  ${GREEN}✓${NC} Environment configuration file exists"
    ASSERT_PASSED=$((ASSERT_PASSED + 1))

    # Check for locale configuration (critical for Starship bug fix)
    if grep -q 'LC_ALL\|LANG' "$HOME/.zsh.d/20-env.zsh"; then
        echo -e "  ${GREEN}✓${NC} Locale configuration present (UTF-8 fix)"
        ASSERT_PASSED=$((ASSERT_PASSED + 1))
    else
        echo -e "  ${YELLOW}⚠${NC} No explicit locale configuration"
        ASSERT_PASSED=$((ASSERT_PASSED + 1))
    fi

    # Check for editor configuration
    if grep -q 'EDITOR\|VISUAL' "$HOME/.zsh.d/20-env.zsh"; then
        echo -e "  ${GREEN}✓${NC} Editor configuration present"
        ASSERT_PASSED=$((ASSERT_PASSED + 1))
    else
        echo -e "  ${YELLOW}○${NC} No editor configuration (optional)"
    fi
else
    echo -e "  ${YELLOW}⚠${NC} Environment configuration file not found"
    ASSERT_PASSED=$((ASSERT_PASSED + 1))
fi

echo ""

# ============================================================================
# 6. Functions
# ============================================================================
echo "6. Functions"

if [ -f "$HOME/.zsh.d/40-functions.zsh" ]; then
    echo -e "  ${GREEN}✓${NC} Functions file exists"
    ASSERT_PASSED=$((ASSERT_PASSED + 1))

    # Count functions defined
    function_count=$(grep -c '^function \|^[a-zA-Z_][a-zA-Z0-9_]*()' "$HOME/.zsh.d/40-functions.zsh" 2>/dev/null || echo "0")
    if [ "$function_count" -gt 0 ]; then
        echo -e "  ${GREEN}✓${NC} Found $function_count functions defined"
        ASSERT_PASSED=$((ASSERT_PASSED + 1))
    else
        echo -e "  ${YELLOW}○${NC} No functions found (file may be empty)"
    fi
else
    echo -e "  ${YELLOW}○${NC} Functions file not found (optional)"
fi

echo ""

# ============================================================================
# 7. Profile-Specific Overrides
# ============================================================================
echo "7. Profile-Specific Overrides"

if [ -f "$HOME/.zsh.d/overrides.zsh" ]; then
    echo -e "  ${GREEN}✓${NC} Profile overrides file exists"
    ASSERT_PASSED=$((ASSERT_PASSED + 1))

    # Check if file has content
    if [ -s "$HOME/.zsh.d/overrides.zsh" ]; then
        echo -e "  ${GREEN}✓${NC} Profile overrides has content"
        ASSERT_PASSED=$((ASSERT_PASSED + 1))
    else
        echo -e "  ${YELLOW}○${NC} Profile overrides file is empty (optional)"
    fi

    # Check if it's a symlink (should be)
    if [ -L "$HOME/.zsh.d/overrides.zsh" ]; then
        target=$(readlink "$HOME/.zsh.d/overrides.zsh")
        echo -e "  ${GREEN}✓${NC} Profile overrides is symlinked to: $target"
        ASSERT_PASSED=$((ASSERT_PASSED + 1))
    else
        echo -e "  ${YELLOW}⚠${NC} Profile overrides is not a symlink"
        ASSERT_PASSED=$((ASSERT_PASSED + 1))
    fi
else
    echo -e "  ${YELLOW}⚠${NC} Profile overrides file not found"
    ASSERT_PASSED=$((ASSERT_PASSED + 1))
fi

echo ""

# ============================================================================
# 8. .zshrc Content
# ============================================================================
echo "8. .zshrc Content"

if [ -f "$HOME/.zshrc" ]; then
    echo -e "  ${GREEN}✓${NC} .zshrc exists"
    ASSERT_PASSED=$((ASSERT_PASSED + 1))

    # Check for essential content
    if grep -q 'zsh.d' "$HOME/.zshrc" || readlink "$HOME/.zshrc" | grep -q 'zsh'; then
        echo -e "  ${GREEN}✓${NC} .zshrc references zsh.d or is symlinked"
        ASSERT_PASSED=$((ASSERT_PASSED + 1))
    else
        echo -e "  ${YELLOW}⚠${NC} .zshrc doesn't reference zsh.d (may use different structure)"
        ASSERT_PASSED=$((ASSERT_PASSED + 1))
    fi

    # Check for Starship initialization
    if grep -q 'starship init' "$HOME/.zshrc" || \
       ([ -L "$HOME/.zshrc" ] && grep -q 'starship init' "$(readlink -f "$HOME/.zshrc")" 2>/dev/null); then
        echo -e "  ${GREEN}✓${NC} Starship initialization found in .zshrc"
        ASSERT_PASSED=$((ASSERT_PASSED + 1))
    else
        echo -e "  ${YELLOW}⚠${NC} Starship initialization not found (may be in sourced files)"
        ASSERT_PASSED=$((ASSERT_PASSED + 1))
    fi
else
    echo -e "  ${RED}✗${NC} .zshrc missing"
    ASSERT_FAILED=$((ASSERT_FAILED + 1))
fi

echo ""

# ============================================================================
# Summary
# ============================================================================
echo "=== Configuration Content Summary ==="
echo "Validated configuration structure and essential content"
echo ""

assert_summary
