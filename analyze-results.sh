#!/bin/bash

# Results Analysis Script
# Analyzes pgbench results and provides non-technical explanations

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

RESULTS_DIR="$1"

if [ -z "$RESULTS_DIR" ] || [ ! -d "$RESULTS_DIR" ]; then
    echo -e "${RED}Error: Results directory not found${NC}"
    exit 1
fi

# Get VERBOSE_MODE from environment, default to false
VERBOSE_MODE=${VERBOSE_MODE:-false}

# Helper function for floating point comparison
compare_float() {
    local val1="$1"
    local op="$2"
    local val2="$3"

    if command -v bc >/dev/null 2>&1; then
        result=$(echo "$val1 $op $val2" | bc -l 2>/dev/null)
        [ "$result" = "1" ]
    else
        # Fallback for systems without bc
        case "$op" in
            ">") [ "$(printf "%.0f" "$val1")" -gt "$(printf "%.0f" "$val2")" ] ;;
            "<") [ "$(printf "%.0f" "$val1")" -lt "$(printf "%.0f" "$val2")" ] ;;
            *) false ;;
        esac
    fi
}

echo -e "${BLUE}=== PostgreSQL Performance Analysis ===${NC}"
echo ""

# Function to extract TPS from pgbench output
extract_tps() {
    local file="$1"
    # Try multiple patterns to find TPS
    local tps
    tps=$(grep "tps = " "$file" | grep "including connections establishing" | awk '{print $3}' | head -1)
    if [ -z "$tps" ]; then
        tps=$(grep "tps = " "$file" | awk '{print $3}' | head -1)
    fi
    if [ -z "$tps" ]; then
        tps=$(grep -E "excluding|including" "$file" | grep -oE '[0-9]+\.[0-9]+' | head -1)
    fi
    echo "$tps"
}

# Function to extract latency from pgbench output
extract_latency() {
    local file="$1"
    # Try multiple patterns to find latency
    local latency
    latency=$(grep "latency average = " "$file" | awk '{print $4}' | head -1)
    if [ -z "$latency" ]; then
        latency=$(grep "latency average" "$file" | grep -oE '[0-9]+\.[0-9]+' | head -1)
    fi
    if [ -z "$latency" ]; then
        latency=$(grep -i "average" "$file" | grep -oE '[0-9]+\.[0-9]+' | head -1)
    fi
    echo "$latency"
}

# Function to extract connection time
extract_connection_time() {
    local file="$1"
    grep "initial connection time" "$file" | awk '{print $5}' | head -1
}

# Function to extract failed transactions
extract_failed() {
    local file="$1"
    grep "failed:" "$file" | awk '{print $3}' | sed 's/[()]//g' | head -1
}

# Function to get performance rating
get_performance_rating() {
    local tps="$1"

    if compare_float "$tps" ">" "1000"; then
        echo -e "${GREEN}Excellent${NC}"
    elif compare_float "$tps" ">" "500"; then
        echo -e "${GREEN}Good${NC}"
    elif compare_float "$tps" ">" "200"; then
        echo -e "${YELLOW}Fair${NC}"
    elif compare_float "$tps" ">" "50"; then
        echo -e "${YELLOW}Poor${NC}"
    else
        echo -e "${RED}Very Poor${NC}"
    fi
}

# Function to explain what TPS means
explain_tps() {
    local tps="$1"

    echo -e "${CYAN}What this means:${NC}"
    echo "• Your database can handle $tps transactions per second"
    echo "• Each transaction typically involves reading/writing data"
    echo "• Higher numbers = better performance"

    if compare_float "$tps" ">" "1000"; then
        echo "• This is excellent - your database can handle heavy workloads"
    elif compare_float "$tps" ">" "500"; then
        echo "• This is good performance for most applications"
    elif compare_float "$tps" ">" "200"; then
        echo "• This is acceptable for light to medium workloads"
    else
        echo "• This performance may struggle with busy applications"
        echo "• Consider upgrading hardware or optimizing database settings"
    fi
}

# Function to explain latency
explain_latency() {
    local latency="$1"

    echo -e "${CYAN}Response Time:${NC}"
    echo "• Average time per transaction: ${latency}ms"

    if [ -n "$latency" ] && compare_float "$latency" "<" "10"; then
        echo "• Very fast response times - users won't notice any delay"
    elif [ -n "$latency" ] && compare_float "$latency" "<" "50"; then
        echo "• Good response times - acceptable for most users"
    elif [ -n "$latency" ] && compare_float "$latency" "<" "100"; then
        echo "• Moderate response times - may be noticeable to users"
    elif [ -n "$latency" ]; then
        echo "• Slow response times - users may experience delays"
        echo "• Consider performance optimization"
    else
        echo "• Response time data not available"
    fi
}

# Create summary report
SUMMARY_FILE="$RESULTS_DIR/PERFORMANCE_SUMMARY.txt"
echo "PostgreSQL Performance Test Summary" > "$SUMMARY_FILE"
echo "Generated: $(date)" >> "$SUMMARY_FILE"
echo "========================================" >> "$SUMMARY_FILE"
echo "" >> "$SUMMARY_FILE"

# Analyze each test
for test_file in "$RESULTS_DIR"/*_results.txt; do
    if [ -f "$test_file" ]; then
        test_name=$(basename "$test_file" _results.txt)
        test_display_name=$(echo "$test_name" | tr '_' ' ' | sed 's/.*/\u&/')

        echo -e "${BLUE}📊 $test_display_name Results${NC}"
        echo "=================================================="

        # Extract all metrics
        tps=$(extract_tps "$test_file")
        latency=$(extract_latency "$test_file")
        conn_time=$(extract_connection_time "$test_file")
        failed=$(extract_failed "$test_file")

        # Show raw pgbench summary for debugging (only in verbose mode)
        if [ "${VERBOSE_MODE:-false}" = "true" ]; then
            echo -e "${CYAN}Raw pgbench summary:${NC}"
            grep -E "(tps|latency|initial connection)" "$test_file" | head -5
            echo ""
        fi

        if [ -n "$tps" ] && [ "$tps" != "0" ]; then
            rating=$(get_performance_rating "$tps")

            echo -e "${GREEN}✅ PERFORMANCE METRICS${NC}"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo -e "🚀 Transactions per Second: ${GREEN}$tps TPS${NC}"
            echo -e "⏱️  Average Response Time: ${YELLOW}${latency:-N/A}ms${NC}"
            echo -e "🔗 Connection Setup Time: ${CYAN}${conn_time:-N/A}ms${NC}"
            echo -e "❌ Failed Transactions: ${RED}${failed:-0}${NC}"
            echo -e "🏆 Performance Rating: $rating"
            echo ""

            # Detailed explanation
            echo -e "${CYAN}📋 WHAT THIS MEANS FOR YOUR DATABASE:${NC}"
            explain_tps "$tps"
            echo ""
            explain_latency "$latency"
            echo ""

            # Add to summary file
            echo "$test_display_name:" >> "$SUMMARY_FILE"
            echo "  TPS: $tps" >> "$SUMMARY_FILE"
            echo "  Latency: ${latency:-N/A}ms" >> "$SUMMARY_FILE"
            echo "  Connection Time: ${conn_time:-N/A}ms" >> "$SUMMARY_FILE"
            echo "  Failed: ${failed:-0}" >> "$SUMMARY_FILE"
            echo "  Rating: $(echo -e "$rating" | sed 's/\x1B\[[0-9;]*[JKmsu]//g')" >> "$SUMMARY_FILE"
            echo "" >> "$SUMMARY_FILE"
        else
            echo -e "${RED}❌ PARSING ERROR${NC}"
            echo "Could not extract TPS from results. Showing raw output:"
            echo ""
            echo -e "${YELLOW}Last 10 lines of test output:${NC}"
            tail -10 "$test_file"
            echo ""
            echo -e "${YELLOW}Lines containing 'tps':${NC}"
            grep -i "tps" "$test_file" || echo "No TPS lines found"
            echo ""
        fi

        echo ""
        echo "════════════════════════════════════════════════════"
        echo ""
    fi
done

# Generate recommendations
echo -e "${YELLOW}📋 Recommendations${NC}"
echo "=================="

# Find the best and worst performing tests
best_tps=0
worst_tps=999999
best_test=""
worst_test=""

for test_file in "$RESULTS_DIR"/*_results.txt; do
    if [ -f "$test_file" ]; then
        test_name=$(basename "$test_file" _results.txt)
        tps=$(extract_tps "$test_file")

        if [ -n "$tps" ]; then
            if compare_float "$tps" ">" "$best_tps"; then
                best_tps=$tps
                best_test=$test_name
            fi
            if compare_float "$tps" "<" "$worst_tps"; then
                worst_tps=$tps
                worst_test=$test_name
            fi
        fi
    fi
done

echo "• Best performing test: $best_test ($best_tps TPS)"
echo "• Most challenging test: $worst_test ($worst_tps TPS)"
echo ""

if compare_float "$worst_tps" "<" "100"; then
    echo -e "${YELLOW}⚠️  Performance Concerns:${NC}"
    echo "• Your database struggles under heavy load"
    echo "• Consider increasing CPU, RAM, or using faster storage (SSD)"
    echo "• Review database configuration settings"
    echo "• Consider connection pooling for high-connection scenarios"
else
    echo -e "${GREEN}✅ Good Performance:${NC}"
    echo "• Your database handles the tested workloads well"
    echo "• Current configuration appears suitable for your needs"
fi

echo ""
echo -e "${BLUE}💡 Understanding the Tests:${NC}"
echo "• Simple Test: Normal daily usage (5 users)"
echo "• Load Test: Busy periods (20 users)"
echo "• Stress Test: Peak capacity (50 users)"
echo "• Connection Test: Many simultaneous connections (100 users)"

echo ""
echo -e "${GREEN}📁 Detailed results saved to: $SUMMARY_FILE${NC}"

# Add final recommendations to summary
echo "" >> "$SUMMARY_FILE"
echo "Recommendations:" >> "$SUMMARY_FILE"
echo "================" >> "$SUMMARY_FILE"
echo "Best performing: $best_test ($best_tps TPS)" >> "$SUMMARY_FILE"
echo "Most challenging: $worst_test ($worst_tps TPS)" >> "$SUMMARY_FILE"

if compare_float "$worst_tps" "<" "100"; then
    echo "" >> "$SUMMARY_FILE"
    echo "Performance concerns detected:" >> "$SUMMARY_FILE"
    echo "- Consider hardware upgrades (CPU, RAM, SSD storage)" >> "$SUMMARY_FILE"
    echo "- Review PostgreSQL configuration" >> "$SUMMARY_FILE"
    echo "- Implement connection pooling" >> "$SUMMARY_FILE"
else
    echo "" >> "$SUMMARY_FILE"
    echo "Performance looks good for tested workloads." >> "$SUMMARY_FILE"
fi