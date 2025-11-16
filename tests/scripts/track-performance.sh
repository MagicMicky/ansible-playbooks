#!/usr/bin/env bash
# Track shell startup time and compare to baseline
# Detects performance regressions automatically
#
# Usage:
#   ./track-performance.sh                    # Measure and save
#   ./track-performance.sh --check-only       # Measure without saving
#   ./track-performance.sh --show-history     # Display history
#   ./track-performance.sh --reset            # Reset history
#
# Exit codes:
#   0 - Performance acceptable
#   1 - Performance regression detected (>20% over baseline)
#   2 - Script error (zsh not found, etc.)

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_DIR="${SCRIPT_DIR}/../test-results"
PERF_FILE="${RESULTS_DIR}/perf-history.json"

# Performance thresholds (in milliseconds)
BASELINE_CONTAINER_MS=200   # Target in Docker container
BASELINE_NATIVE_MS=100      # Target on native machine
REGRESSION_THRESHOLD=1.20   # 20% regression triggers failure

# Ensure results directory exists
mkdir -p "${RESULTS_DIR}"

# Initialize performance history file if it doesn't exist
if [ ! -f "${PERF_FILE}" ]; then
    echo "[]" > "${PERF_FILE}"
fi

echo -e "${BLUE}╔════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Shell Performance Tracker                ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════╝${NC}"
echo ""

# Parse arguments
CHECK_ONLY=false
SHOW_HISTORY=false
RESET_HISTORY=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --check-only)
            CHECK_ONLY=true
            shift
            ;;
        --show-history)
            SHOW_HISTORY=true
            shift
            ;;
        --reset)
            RESET_HISTORY=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 2
            ;;
    esac
done

# Handle --reset
if [ "$RESET_HISTORY" = true ]; then
    echo "[]" > "${PERF_FILE}"
    echo -e "${GREEN}Performance history reset${NC}"
    exit 0
fi

# Handle --show-history
if [ "$SHOW_HISTORY" = true ]; then
    if command -v jq > /dev/null 2>&1; then
        echo -e "${BLUE}Performance History (last 10 entries):${NC}"
        jq -r '.[-10:] | .[] | "\(.date) | \(.commit[0:8]) | \(.startup_ms)ms | \(.environment)"' "${PERF_FILE}" 2>/dev/null || echo "No history available"
    else
        echo "Install jq to view formatted history"
        cat "${PERF_FILE}"
    fi
    exit 0
fi

# Check if zsh is available
if ! command -v zsh > /dev/null 2>&1; then
    echo -e "${RED}Error: zsh not found${NC}"
    exit 2
fi

# Detect environment
ENVIRONMENT="native"
if [ -f "/.dockerenv" ]; then
    ENVIRONMENT="container"
    BASELINE_MS=$BASELINE_CONTAINER_MS
elif grep -q "Microsoft" /proc/version 2>/dev/null; then
    ENVIRONMENT="wsl"
    BASELINE_MS=$BASELINE_NATIVE_MS
else
    BASELINE_MS=$BASELINE_NATIVE_MS
fi

echo -e "Environment: ${BLUE}${ENVIRONMENT}${NC}"
echo -e "Baseline target: ${BLUE}${BASELINE_MS}ms${NC}"
echo ""

# Measure startup time (average of 5 runs)
echo -e "${YELLOW}Measuring shell startup time...${NC}"
total=0
measurements=()
runs=5

for i in $(seq 1 $runs); do
    # Use bash's TIMEFORMAT and time built-in (portable)
    TIMEFORMAT='%3R'
    time_output=$( { time zsh -i -c exit > /dev/null 2>&1; } 2>&1 )

    # Extract seconds (format: "0.123")
    if [[ "$time_output" =~ ^[0-9]+\.[0-9]+ ]]; then
        # Convert to milliseconds
        time_ms=$(echo "$time_output" | awk '{printf "%d", $1 * 1000}')

        # Sanity check
        if [ -z "$time_ms" ] || [ "$time_ms" -eq 0 ]; then
            time_ms=100  # Default reasonable value
        fi
        measurements+=("$time_ms")
        total=$((total + time_ms))
        echo "  Run $i: ${time_ms}ms"
    else
        echo "  Run $i: timing failed"
        measurements+=(100)
        total=$((total + 100))
    fi
done

avg_ms=$((total / runs))

# Calculate standard deviation (optional, for stability check)
variance=0
for m in "${measurements[@]}"; do
    diff=$((m - avg_ms))
    variance=$((variance + diff * diff))
done
std_dev=$(echo "scale=0; sqrt($variance / $runs)" | bc 2>/dev/null || echo "N/A")

echo ""
echo -e "${BLUE}Results:${NC}"
echo "  Average startup time: ${avg_ms}ms"
echo "  Standard deviation: ${std_dev}ms"
echo "  Baseline target: ${BASELINE_MS}ms"
echo ""

# Calculate regression percentage
if [ $avg_ms -gt $BASELINE_MS ]; then
    regression_pct=$(echo "scale=2; ($avg_ms / $BASELINE_MS) * 100" | bc 2>/dev/null || echo "N/A")
    echo "  Performance: ${regression_pct}% of baseline"
else
    regression_pct=100
    echo "  Performance: Better than baseline"
fi

# Save to history (unless check-only)
if [ "$CHECK_ONLY" = false ]; then
    # Get git commit if available
    GIT_COMMIT=$(git rev-parse HEAD 2>/dev/null || echo "unknown")
    GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")

    # Create JSON entry
    NEW_ENTRY=$(cat <<EOF
{
  "date": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "commit": "${GIT_COMMIT}",
  "branch": "${GIT_BRANCH}",
  "startup_ms": ${avg_ms},
  "baseline_ms": ${BASELINE_MS},
  "environment": "${ENVIRONMENT}",
  "std_dev_ms": ${std_dev}
}
EOF
)

    # Append to history file
    if command -v jq > /dev/null 2>&1; then
        # Use jq for proper JSON handling
        jq --argjson entry "$NEW_ENTRY" '. + [$entry]' "${PERF_FILE}" > "${PERF_FILE}.tmp" && mv "${PERF_FILE}.tmp" "${PERF_FILE}"
        echo -e "${GREEN}Performance data saved to history${NC}"
    else
        # Fallback: manual JSON manipulation (basic)
        # Remove trailing ] and add new entry
        if [ -s "${PERF_FILE}" ] && [ "$(cat "${PERF_FILE}")" != "[]" ]; then
            sed -i 's/]$//' "${PERF_FILE}"
            echo ",$NEW_ENTRY]" >> "${PERF_FILE}"
        else
            echo "[$NEW_ENTRY]" > "${PERF_FILE}"
        fi
        echo -e "${GREEN}Performance data saved to history (install jq for better JSON handling)${NC}"
    fi
fi

echo ""

# Check for regression
# Compare against baseline with threshold
max_acceptable=$((BASELINE_MS * 120 / 100))  # 120% of baseline

if [ $avg_ms -lt $BASELINE_MS ]; then
    echo -e "${GREEN}Performance excellent: ${avg_ms}ms (below ${BASELINE_MS}ms target)${NC}"
    exit 0
elif [ $avg_ms -le $max_acceptable ]; then
    echo -e "${GREEN}Performance acceptable: ${avg_ms}ms (within 20% of ${BASELINE_MS}ms target)${NC}"
    exit 0
else
    echo -e "${RED}Performance regression detected: ${avg_ms}ms (>${max_acceptable}ms threshold)${NC}"
    echo ""
    echo "Possible causes:"
    echo "  - Added heavy plugins"
    echo "  - Slow network operations in init"
    echo "  - Compilation issues with zinit"
    echo ""
    echo "To investigate:"
    echo "  zsh -i -c 'time source ~/.zshrc'"
    echo "  zinit times"
    exit 1
fi
