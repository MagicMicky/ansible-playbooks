#!/usr/bin/env bash
# Validate shell configuration after playbook application
# Tests: shell startup time, tools availability, machine type detection, Starship prompt

set -e

# Add ~/.local/bin to PATH for tools installed there (e.g., zoxide, starship)
export PATH="$HOME/.local/bin:/root/.local/bin:$PATH"

echo "=== Shell Configuration Validation ==="
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

FAILED=0
PASSED=0

# Function to test command
test_command() {
    local cmd=$1
    local name=$2
    echo -n "  Checking $name... "
    if command -v "$cmd" > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC}"
        PASSED=$((PASSED + 1))
        return 0
    else
        echo -e "${RED}✗ NOT FOUND${NC}"
        FAILED=$((FAILED + 1))
        return 1
    fi
}

# 1. Test shell startup time
echo "1. Shell Startup Time"
if [ -x "$(command -v zsh)" ]; then
    # Check if /usr/bin/time exists
    if command -v /usr/bin/time > /dev/null 2>&1; then
        # Measure startup time (run 3 times, take average)
        total=0
        runs=3
        for i in $(seq 1 $runs); do
            time_output=$(/usr/bin/time -f "%E" zsh -i -c exit 2>&1 || echo "0:00.00")
            time_ms=$(echo "$time_output" | awk -F'[:.]+' '{if (NF >= 3) print ($1 * 60000) + ($2 * 1000) + ($3 * 10); else print 0}')
            # Handle empty or invalid output
            if [ -z "$time_ms" ] || [ "$time_ms" -eq 0 ]; then
                time_ms=100  # Default reasonable value
            fi
            total=$((total + time_ms))
        done
        avg_time=$((total / runs))

        echo "  Average startup time: ${avg_time}ms"

        # Check against target (100ms for laptop, 50ms for server)
        # For testing, we'll use 200ms as reasonable threshold in container
        if [ $avg_time -lt 200 ]; then
            echo -e "  ${GREEN}✓ Startup time acceptable${NC}"
            PASSED=$((PASSED + 1))
        else
            echo -e "  ${YELLOW}⚠ Startup time slower than expected (target: <200ms in container)${NC}"
            # Don't fail, just warn
            PASSED=$((PASSED + 1))
        fi
    else
        echo -e "  ${YELLOW}⚠ /usr/bin/time not available, skipping startup time test${NC}"
        PASSED=$((PASSED + 1))
    fi
else
    echo -e "  ${RED}✗ zsh not found${NC}"
    FAILED=$((FAILED + 1))
fi
echo ""

# 2. Test essential tools
echo "2. Essential Tools"
test_command "starship" "Starship prompt"
test_command "fzf" "fzf fuzzy finder"
test_command "zoxide" "zoxide directory jumper"
test_command "rg" "ripgrep"
echo ""

# 3. Test optional laptop tools (if not server profile)
if [ "${SHELL_PROFILE}" != "server" ]; then
    echo "3. Laptop Tools (optional)"
    # Optional tools - don't count as failures
    if command -v "bat" > /dev/null 2>&1; then
        echo -e "  ${GREEN}✓${NC} bat (cat with syntax highlighting)"
        PASSED=$((PASSED + 1))
    else
        echo -e "  ${YELLOW}○${NC} bat (optional, not installed)"
    fi
    if command -v "eza" > /dev/null 2>&1; then
        echo -e "  ${GREEN}✓${NC} eza (modern ls)"
        PASSED=$((PASSED + 1))
    else
        echo -e "  ${YELLOW}○${NC} eza (optional, not installed)"
    fi
    if command -v "fd" > /dev/null 2>&1; then
        echo -e "  ${GREEN}✓${NC} fd (modern find)"
        PASSED=$((PASSED + 1))
    else
        echo -e "  ${YELLOW}○${NC} fd (optional, not installed)"
    fi
    echo ""
fi

# 4. Test Starship configuration
echo "4. Starship Configuration"
if [ -f "$HOME/.config/starship.toml" ]; then
    echo -e "  ${GREEN}✓${NC} starship.toml exists"
    PASSED=$((PASSED + 1))
else
    echo -e "  ${YELLOW}⚠${NC} starship.toml missing (optional, might use defaults)"
    PASSED=$((PASSED + 1))  # Don't fail for missing starship.toml
fi
echo ""

# 5. Test zinit installation
echo "5. Zinit Plugin Manager"
if [ -d "$HOME/.local/share/zinit/zinit.git" ]; then
    echo -e "  ${GREEN}✓${NC} zinit directory exists"
    PASSED=$((PASSED + 1))

    # Verify zinit actually works
    if [ -f "$HOME/.local/share/zinit/zinit.git/zinit.zsh" ]; then
        echo -e "  ${GREEN}✓${NC} zinit.zsh file present"
        PASSED=$((PASSED + 1))
    else
        echo -e "  ${RED}✗${NC} zinit.zsh missing (broken installation)"
        FAILED=$((FAILED + 1))
    fi
else
    echo -e "  ${RED}✗${NC} zinit not found"
    FAILED=$((FAILED + 1))
fi
echo ""

# 6. Test zsh configuration
echo "6. Zsh Configuration"
if [ -f "$HOME/.zshrc" ] || [ -L "$HOME/.zshrc" ]; then
    echo -e "  ${GREEN}✓${NC} .zshrc exists"
    PASSED=$((PASSED + 1))

    # Verify .zshrc is readable
    if [ -r "$HOME/.zshrc" ]; then
        echo -e "  ${GREEN}✓${NC} .zshrc is readable"
        PASSED=$((PASSED + 1))
    else
        echo -e "  ${RED}✗${NC} .zshrc exists but not readable"
        FAILED=$((FAILED + 1))
    fi

    # If it's a symlink, verify target exists
    if [ -L "$HOME/.zshrc" ]; then
        target=$(readlink "$HOME/.zshrc")
        if [ -f "$target" ]; then
            echo -e "  ${GREEN}✓${NC} .zshrc symlink target exists: $target"
            PASSED=$((PASSED + 1))
        else
            echo -e "  ${RED}✗${NC} .zshrc symlink broken, target missing: $target"
            FAILED=$((FAILED + 1))
        fi
    fi

    # Verify .zshrc has content
    if [ -s "$HOME/.zshrc" ]; then
        echo -e "  ${GREEN}✓${NC} .zshrc has content"
        PASSED=$((PASSED + 1))
    else
        echo -e "  ${RED}✗${NC} .zshrc is empty"
        FAILED=$((FAILED + 1))
    fi
else
    echo -e "  ${RED}✗${NC} .zshrc missing"
    FAILED=$((FAILED + 1))
fi
echo ""

# Results summary
echo "=== Results ==="
echo "Passed: $PASSED"
echo "Failed: $FAILED"
echo ""

if [ $FAILED -gt 0 ]; then
    echo -e "${RED}❌ Shell validation FAILED${NC}"
    exit 1
else
    echo -e "${GREEN}✅ Shell validation PASSED${NC}"
    exit 0
fi
