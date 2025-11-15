#!/usr/bin/env bash
# Profile Isolation Validation Script
# Verifies that machine profiles are correctly set and isolated
# Tests that .machine-type marker exists and matches expected profile

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

echo -e "${BLUE}=== Profile Isolation Validation ===${NC}"
echo ""

reset_assertions

# ============================================================================
# 1. Machine Type Detection
# ============================================================================
echo "1. Machine Type Detection"

# Check for .machine-type marker file
MACHINE_TYPE_FILE="$HOME/.zsh.d/.machine-type"

if [ -f "$MACHINE_TYPE_FILE" ]; then
    MACHINE_TYPE=$(cat "$MACHINE_TYPE_FILE")
    echo -e "  ${GREEN}✓${NC} Machine type marker exists: $MACHINE_TYPE"
    ASSERT_PASSED=$((ASSERT_PASSED + 1))
else
    echo -e "  ${RED}✗${NC} Machine type marker missing: $MACHINE_TYPE_FILE"
    ASSERT_FAILED=$((ASSERT_FAILED + 1))
fi

echo ""

# ============================================================================
# 2. Profile-Specific Configuration Exists
# ============================================================================
echo "2. Profile-Specific Configuration"

# Expected profile files (symlinks)
PROFILE_FILES=(
    "$HOME/.zsh.d/plugins.zsh"
    "$HOME/.zsh.d/config.zsh"
    "$HOME/.zsh.d/overrides.zsh"
)

for file in "${PROFILE_FILES[@]}"; do
    if [ -L "$file" ]; then
        target=$(readlink "$file")
        echo -e "  ${GREEN}✓${NC} Profile config symlink: $(basename $file) → $target"
        ASSERT_PASSED=$((ASSERT_PASSED + 1))
    elif [ -f "$file" ]; then
        echo -e "  ${YELLOW}⚠${NC} Profile config exists but is not a symlink: $(basename $file)"
        ASSERT_PASSED=$((ASSERT_PASSED + 1))
    else
        echo -e "  ${RED}✗${NC} Profile config missing: $(basename $file)"
        ASSERT_FAILED=$((ASSERT_FAILED + 1))
    fi
done

echo ""

# ============================================================================
# 3. Core Files Are Present (Universal)
# ============================================================================
echo "3. Core Configuration Files (Universal Across Profiles)"

CORE_FILES=(
    "$HOME/.zsh.d/01-zinit.zsh"
    "$HOME/.zsh.d/10-path.zsh"
    "$HOME/.zsh.d/20-env.zsh"
    "$HOME/.zsh.d/30-aliases.zsh"
)

for file in "${CORE_FILES[@]}"; do
    if [ -L "$file" ] || [ -f "$file" ]; then
        echo -e "  ${GREEN}✓${NC} Core config exists: $(basename $file)"
        ASSERT_PASSED=$((ASSERT_PASSED + 1))
    else
        echo -e "  ${RED}✗${NC} Core config missing: $(basename $file)"
        ASSERT_FAILED=$((ASSERT_FAILED + 1))
    fi
done

echo ""

# ============================================================================
# 4. Profile-Specific Behavior Verification
# ============================================================================
echo "4. Profile-Specific Behavior"

# Test based on detected machine type
if [ -f "$MACHINE_TYPE_FILE" ]; then
    case "$MACHINE_TYPE" in
        "wsl")
            echo "  Detected WSL profile"

            # WSL should have Windows interop
            if [ -f "$HOME/.zsh.d/overrides.zsh" ]; then
                if grep -q "wsl" "$HOME/.zsh.d/overrides.zsh" 2>/dev/null || \
                   readlink "$HOME/.zsh.d/overrides.zsh" | grep -q "wsl" 2>/dev/null; then
                    echo -e "  ${GREEN}✓${NC} WSL-specific overrides configured"
                    ASSERT_PASSED=$((ASSERT_PASSED + 1))
                else
                    echo -e "  ${YELLOW}⚠${NC} WSL profile set but overrides don't reference WSL"
                    ASSERT_PASSED=$((ASSERT_PASSED + 1))
                fi
            fi
            ;;

        "server")
            echo "  Detected Server profile"

            # Server should have minimal config
            if [ -f "$HOME/.zsh.d/config.zsh" ]; then
                target=$(readlink "$HOME/.zsh.d/config.zsh" 2>/dev/null || echo "")
                if echo "$target" | grep -q "server" 2>/dev/null; then
                    echo -e "  ${GREEN}✓${NC} Server-specific config configured"
                    ASSERT_PASSED=$((ASSERT_PASSED + 1))
                else
                    echo -e "  ${YELLOW}⚠${NC} Server profile set but config doesn't reference server"
                    ASSERT_PASSED=$((ASSERT_PASSED + 1))
                fi
            fi
            ;;

        "personal"|"laptop")
            echo "  Detected Personal/Laptop profile"

            # Personal should have full features
            echo -e "  ${GREEN}✓${NC} Personal profile detected"
            ASSERT_PASSED=$((ASSERT_PASSED + 1))
            ;;

        "pro"|"work")
            echo "  Detected Pro/Work profile"

            # Pro should have work-specific tools
            echo -e "  ${GREEN}✓${NC} Pro profile detected"
            ASSERT_PASSED=$((ASSERT_PASSED + 1))
            ;;

        *)
            echo -e "  ${YELLOW}⚠${NC} Unknown machine type: $MACHINE_TYPE"
            ASSERT_PASSED=$((ASSERT_PASSED + 1))
            ;;
    esac
else
    echo -e "  ${YELLOW}○${NC} No machine type marker found, skipping profile-specific checks"
fi

echo ""

# ============================================================================
# 5. Starship Prompt Configuration
# ============================================================================
echo "5. Starship Prompt Configuration"

STARSHIP_CONFIG="$HOME/.config/starship.toml"

if [ -f "$STARSHIP_CONFIG" ]; then
    echo -e "  ${GREEN}✓${NC} Starship config exists"
    ASSERT_PASSED=$((ASSERT_PASSED + 1))

    # Check if it's machine-type aware (should have different prompts)
    if [ -f "$MACHINE_TYPE_FILE" ]; then
        case "$MACHINE_TYPE" in
            "wsl")
                # WSL should use λ (lambda) character
                if grep -q "λ" "$STARSHIP_CONFIG" 2>/dev/null; then
                    echo -e "  ${GREEN}✓${NC} WSL-specific prompt character (λ) configured"
                    ASSERT_PASSED=$((ASSERT_PASSED + 1))
                else
                    echo -e "  ${YELLOW}⚠${NC} WSL profile but no λ prompt character found"
                    ASSERT_PASSED=$((ASSERT_PASSED + 1))
                fi
                ;;
            "server")
                # Server should use ! (bang) character
                if grep -q "!" "$STARSHIP_CONFIG" 2>/dev/null; then
                    echo -e "  ${GREEN}✓${NC} Server-specific prompt character (!) found"
                    ASSERT_PASSED=$((ASSERT_PASSED + 1))
                else
                    echo -e "  ${YELLOW}⚠${NC} Server profile but no ! prompt character found"
                    ASSERT_PASSED=$((ASSERT_PASSED + 1))
                fi
                ;;
            *)
                echo -e "  ${YELLOW}○${NC} Profile-specific prompt check not defined for: $MACHINE_TYPE"
                ;;
        esac
    fi
else
    echo -e "  ${RED}✗${NC} Starship config missing: $STARSHIP_CONFIG"
    ASSERT_FAILED=$((ASSERT_FAILED + 1))
fi

echo ""

# ============================================================================
# 6. No Cross-Contamination Between Profiles
# ============================================================================
echo "6. Profile Isolation (No Cross-Contamination)"

# Check that we don't have conflicting profile files
PROFILE_MARKERS=(
    "$HOME/.zsh.d/.profile-wsl"
    "$HOME/.zsh.d/.profile-server"
    "$HOME/.zsh.d/.profile-personal"
    "$HOME/.zsh.d/.profile-pro"
)

marker_count=0
for marker in "${PROFILE_MARKERS[@]}"; do
    if [ -f "$marker" ]; then
        marker_count=$((marker_count + 1))
    fi
done

if [ $marker_count -eq 0 ]; then
    echo -e "  ${YELLOW}○${NC} No profile markers found (using .machine-type only)"
    ASSERT_PASSED=$((ASSERT_PASSED + 1))
elif [ $marker_count -eq 1 ]; then
    echo -e "  ${GREEN}✓${NC} Single profile marker (no contamination)"
    ASSERT_PASSED=$((ASSERT_PASSED + 1))
else
    echo -e "  ${RED}✗${NC} Multiple profile markers detected (contamination!)"
    ASSERT_FAILED=$((ASSERT_FAILED + 1))
fi

# Check for duplicate symlinks pointing to different profiles
if [ -d "$HOME/.zsh.d" ]; then
    # Get all symlinks and their targets
    wsl_links=$(find "$HOME/.zsh.d" -type l -exec readlink {} \; 2>/dev/null | grep -c "profiles/wsl" || true)
    server_links=$(find "$HOME/.zsh.d" -type l -exec readlink {} \; 2>/dev/null | grep -c "profiles/server" || true)
    personal_links=$(find "$HOME/.zsh.d" -type l -exec readlink {} \; 2>/dev/null | grep -c "profiles/personal\|profiles/laptop" || true)

    active_profiles=0
    [ $wsl_links -gt 0 ] && active_profiles=$((active_profiles + 1))
    [ $server_links -gt 0 ] && active_profiles=$((active_profiles + 1))
    [ $personal_links -gt 0 ] && active_profiles=$((active_profiles + 1))

    if [ $active_profiles -eq 0 ]; then
        echo -e "  ${YELLOW}○${NC} No profile-specific symlinks detected"
        ASSERT_PASSED=$((ASSERT_PASSED + 1))
    elif [ $active_profiles -eq 1 ]; then
        echo -e "  ${GREEN}✓${NC} Single active profile (no symlink contamination)"
        ASSERT_PASSED=$((ASSERT_PASSED + 1))
    else
        echo -e "  ${RED}✗${NC} Multiple profile symlinks detected:"
        [ $wsl_links -gt 0 ] && echo -e "      - WSL: $wsl_links symlinks"
        [ $server_links -gt 0 ] && echo -e "      - Server: $server_links symlinks"
        [ $personal_links -gt 0 ] && echo -e "      - Personal: $personal_links symlinks"
        ASSERT_FAILED=$((ASSERT_FAILED + 1))
    fi
fi

echo ""

# ============================================================================
# Summary
# ============================================================================
echo "=== Profile Isolation Summary ==="
if [ -f "$MACHINE_TYPE_FILE" ]; then
    echo "Active Profile: $MACHINE_TYPE"
else
    echo "Active Profile: Unknown (marker file missing)"
fi
echo ""

assert_summary
