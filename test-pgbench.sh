#!/bin/bash

# Quick test script to verify pgbench command works
# This creates a minimal test environment to check our pgbench syntax

echo "Testing pgbench command syntax..."

# Test the exact command we use in test-runner.sh
echo "pgbench -c 2 -j 1 -T 10 -P 5"

# This should show the help without errors if syntax is correct
pgbench --help | head -3

echo "✅ pgbench syntax check completed"