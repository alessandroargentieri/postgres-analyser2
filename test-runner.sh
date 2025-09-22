#!/bin/bash

# PostgreSQL Performance Testing Script
# Easy-to-use pgbench wrapper for database performance testing

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values (can be overridden by environment variables)
POSTGRES_HOST=${POSTGRES_HOST:-localhost}
POSTGRES_PORT=${POSTGRES_PORT:-5432}
POSTGRES_USER=${POSTGRES_USER:-postgres}
POSTGRES_PASSWORD=${POSTGRES_PASSWORD:-postgres}
POSTGRES_DB=${POSTGRES_DB:-testdb}
SCALE_FACTOR=${SCALE_FACTOR:-10}
TEST_DURATION=${TEST_DURATION:-60}
VERBOSE_MODE=${VERBOSE_MODE:-false}

# Connection string
export PGPASSWORD="$POSTGRES_PASSWORD"
CONN_STRING="-h $POSTGRES_HOST -p $POSTGRES_PORT -U $POSTGRES_USER -d $POSTGRES_DB"

echo -e "${BLUE}=== PostgreSQL Performance Testing Tool ===${NC}"
echo -e "${BLUE}Database: $POSTGRES_HOST:$POSTGRES_PORT/$POSTGRES_DB${NC}"
echo -e "${BLUE}Scale Factor: $SCALE_FACTOR (simulates $((SCALE_FACTOR * 100000)) accounts)${NC}"
echo -e "${BLUE}Test Duration: $TEST_DURATION seconds each${NC}"
echo ""

# Test database connection
echo -e "${YELLOW}Testing database connection...${NC}"
if ! psql $CONN_STRING -c "SELECT version();" > /dev/null 2>&1; then
    echo -e "${RED}❌ Cannot connect to database. Please check your connection settings.${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Database connection successful${NC}"
echo ""

# Initialize pgbench database
echo -e "${YELLOW}Setting up test database...${NC}"
pgbench $CONN_STRING -i -s $SCALE_FACTOR --quiet
echo -e "${GREEN}✅ Test database initialized${NC}"
echo ""

# Create results directory with timestamp
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# Detect if running in Docker or locally
if [ -d "/app" ] && [ -w "/app" ]; then
    # Running in Docker container
    RESULTS_DIR="/app/results/test_$TIMESTAMP"
else
    # Running locally
    RESULTS_DIR="./results/test_$TIMESTAMP"
fi

mkdir -p "$RESULTS_DIR"

# Function to run a test and save results
run_test() {
    local test_name="$1"
    local clients="$2"
    local jobs="$3"
    local description="$4"

    echo -e "${YELLOW}Running $test_name...${NC}"
    echo "Description: $description"
    echo "Clients: $clients, Jobs: $jobs, Duration: ${TEST_DURATION}s"

    local output_file="$RESULTS_DIR/$(echo "$test_name" | tr '[:upper:]' '[:lower:]')_results.txt"
    
    # Run pgbench in background for maximum performance accuracy
    echo "Running test in background for maximum accuracy..."

    # Start pgbench in background with no output interference
    if [ "$VERBOSE_MODE" = "true" ]; then
        # Verbose mode: minimal progress updates
        pgbench $CONN_STRING \
            -c $clients \
            -j $jobs \
            -T $TEST_DURATION \
            -P 30 \
            > "$output_file" 2>&1 &
    else
        # Performance mode: pure background execution
        pgbench $CONN_STRING \
            -c $clients \
            -j $jobs \
            -T $TEST_DURATION \
            > "$output_file" 2>&1 &
    fi

    local pgbench_pid=$!
    local start_time=$(date +%s)
    local estimated_end=$((start_time + TEST_DURATION + 5))  # Add 5s buffer for startup/cleanup

    # Progress monitoring thread (non-interfering)
    echo -n "Progress: "
    while kill -0 "$pgbench_pid" 2>/dev/null; do
        local current_time=$(date +%s)
        local elapsed=$((current_time - start_time))
        local progress=$((elapsed * 100 / TEST_DURATION))

        # Cap progress at 100%
        if [ $progress -gt 100 ]; then
            progress=100
        fi

        # Update progress without creating new lines
        printf "\rProgress: [%3d%%] %ds/%ds " "$progress" "$elapsed" "$TEST_DURATION"

        # Show estimated completion
        if [ $elapsed -gt 5 ]; then
            local remaining=$((TEST_DURATION - elapsed))
            if [ $remaining -gt 0 ]; then
                printf "(~%ds remaining)" "$remaining"
            else
                printf "(finishing...)"
            fi
        fi

        sleep 2
    done

    # Wait for pgbench to fully complete
    wait "$pgbench_pid"
    local exit_code=$?

    # Clear progress line and show completion
    printf "\rProgress: [100%%] Complete! ✓                    \n"

    # Check if pgbench completed successfully
    if [ $exit_code -ne 0 ]; then
        echo -e "${RED}⚠️  Test may have encountered issues (exit code: $exit_code)${NC}"
    fi

    echo -e "${GREEN}✅ $test_name completed${NC}"

    # Show quick summary of this test
    echo -e "${CYAN}Quick Results Summary:${NC}"

    # Enhanced parsing with more patterns to handle different pgbench versions
    local tps latency

    # Extract TPS with multiple fallback patterns
    tps=$(awk '/tps = / && /including connections establishing/ {print $3; exit}' "$output_file")
    [ -z "$tps" ] && tps=$(awk '/tps = / && /excluding connections establishing/ {print $3; exit}' "$output_file")
    [ -z "$tps" ] && tps=$(awk '/tps = / {print $3; exit}' "$output_file")
    [ -z "$tps" ] && tps=$(grep -oE '[0-9]+\.[0-9]+ tps' "$output_file" | head -1 | awk '{print $1}')
    [ -z "$tps" ] && tps=$(grep -oE 'tps: [0-9]+\.[0-9]+' "$output_file" | head -1 | awk '{print $2}')

    # Extract latency with multiple fallback patterns
    latency=$(awk '/latency average = / {print $4; exit}' "$output_file")
    [ -z "$latency" ] && latency=$(awk '/average latency:/ {print $3; exit}' "$output_file")
    [ -z "$latency" ] && latency=$(grep -oE 'latency: [0-9]+\.[0-9]+' "$output_file" | head -1 | awk '{print $2}')

    if [ -n "$tps" ] && [ "$tps" != "0" ] && [[ "$tps" =~ ^[0-9]+\.?[0-9]*$ ]]; then
        echo "• Transactions per second: $tps"
        echo "• Average latency: ${latency:-N/A}ms"

        # Simple integer comparison for quick rating
        tps_int=$(printf "%.0f" "$tps" 2>/dev/null || echo "0")
        if [ "$tps_int" -gt 1000 ]; then
            echo -e "• Performance: ${GREEN}Excellent${NC}"
        elif [ "$tps_int" -gt 500 ]; then
            echo -e "• Performance: ${GREEN}Good${NC}"
        elif [ "$tps_int" -gt 200 ]; then
            echo -e "• Performance: ${YELLOW}Fair${NC}"
        else
            echo -e "• Performance: ${RED}Needs attention${NC}"
        fi
    else
        echo "• Results will be analyzed at the end"
    fi

    # Always show where results are saved for transparency
    echo "Results saved to: $output_file"
    echo ""
}

# Test 1: Simple Test (Light Load)
run_test "Simple_Test" 5 2 "Light workload - simulates normal daily usage"

# Test 2: Load Test (Medium Load)
run_test "Load_Test" 20 4 "Medium workload - simulates busy periods"

# Test 3: Stress Test (Heavy Load)
run_test "Stress_Test" 50 8 "Heavy workload - tests maximum capacity"

# Test 4: Connection Test (Many Connections)
run_test "Connection_Test" 100 4 "Many connections - tests connection handling"

echo -e "${GREEN}🎉 All tests completed!${NC}"
echo -e "${BLUE}Results directory: $RESULTS_DIR${NC}"
echo ""

# Analyze results - always show analysis in terminal
echo -e "${YELLOW}Analyzing results...${NC}"
/app/analyze-results.sh "$RESULTS_DIR"

echo -e "${GREEN}✅ Performance testing complete!${NC}"
if [ -d "$RESULTS_DIR" ]; then
    echo -e "${BLUE}📁 Detailed results also saved to: $RESULTS_DIR${NC}"
else
    echo -e "${BLUE}💡 To save detailed results to your computer, use: -v \$(pwd)/results:/app/results${NC}"
fi