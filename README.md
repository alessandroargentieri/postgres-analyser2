# PostgreSQL Performance Testing Tool 🚀

A simple Docker-based tool for testing PostgreSQL database performance using pgbench. Perfect for non-technical users who want to understand their database performance.

## Quick Start (3 Steps!)

### 1. Build the Docker Image
```bash
# For local use only
docker build -t postgres-benchmark .

# For multi-platform compatibility (recommended)
docker build --platform=linux/amd64 -t postgres-benchmark .

# To push to Docker Hub (replace with your username)
docker build --platform=linux/amd64 -t your-username/postgres-benchmark .
```

### 2. Run the Tests
```bash
# Basic run (results displayed only)
docker run --rm \
  -e POSTGRES_HOST=your-database-host \
  -e POSTGRES_USER=your-username \
  -e POSTGRES_PASSWORD=your-password \
  -e POSTGRES_DB=your-database \
  postgres-benchmark

# Save results to your computer
docker run --rm \
  -v $(pwd)/results:/app/results \
  -e POSTGRES_HOST=your-database-host \
  -e POSTGRES_USER=your-username \
  -e POSTGRES_PASSWORD=your-password \
  -e POSTGRES_DB=your-database \
  postgres-benchmark

# If using your Docker Hub image
docker run --rm \
  -v $(pwd)/results:/app/results \
  -e POSTGRES_HOST=your-database-host \
  -e POSTGRES_USER=your-username \
  -e POSTGRES_PASSWORD=your-password \
  -e POSTGRES_DB=your-database \
  your-username/postgres-benchmark
```

### 3. Check Results
The tool will automatically run all tests and explain the results in simple terms!

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `POSTGRES_HOST` | Database server address | `localhost` |
| `POSTGRES_PORT` | Database port | `5432` |
| `POSTGRES_USER` | Username | `postgres` |
| `POSTGRES_PASSWORD` | Password | `postgres` |
| `POSTGRES_DB` | Database name | `testdb` |
| `SCALE_FACTOR` | Test size (higher = more data) | `10` |
| `TEST_DURATION` | How long each test runs (seconds) | `60` |
| `VERBOSE_MODE` | Show progress during tests | `false` |

## What Tests Are Run?

The tool automatically runs 4 different tests:

1. **Simple Test** - Normal daily usage (5 users)
2. **Load Test** - Busy periods (20 users)
3. **Stress Test** - Peak capacity (50 users)
4. **Connection Test** - Many connections (100 users)

## Understanding Your Results

The tool explains everything in simple terms:

- **TPS (Transactions Per Second)**: How many operations your database can handle
- **Latency**: How long each operation takes
- **Performance Rating**: Excellent, Good, Fair, Poor, or Very Poor
- **Recommendations**: What to do if performance is poor

## Real Examples

### Testing a Local Database
```bash
docker run --rm \
  -v $(pwd)/results:/app/results \
  -e POSTGRES_HOST=localhost \
  -e POSTGRES_USER=myuser \
  -e POSTGRES_PASSWORD=mypass \
  -e POSTGRES_DB=myapp \
  postgres-benchmark
```

### Testing a Cloud Database (AWS RDS Example)
```bash
docker run --rm \
  -v $(pwd)/results:/app/results \
  -e POSTGRES_HOST=mydb.cluster-xyz.us-east-1.rds.amazonaws.com \
  -e POSTGRES_USER=admin \
  -e POSTGRES_PASSWORD=secret123 \
  -e POSTGRES_DB=production \
  postgres-benchmark
```

### Custom Test Settings
```bash
docker run --rm \
  -v $(pwd)/results:/app/results \
  -e POSTGRES_HOST=my-db-server \
  -e POSTGRES_USER=testuser \
  -e POSTGRES_PASSWORD=testpass \
  -e SCALE_FACTOR=50 \
  -e TEST_DURATION=120 \
  postgres-benchmark
```

### Performance vs Verbose Mode

For **maximum accuracy** (recommended for production testing):
```bash
# Performance mode - no real-time output, most accurate results
docker run --rm \
  -v $(pwd)/results:/app/results \
  -e POSTGRES_HOST=your-host \
  -e POSTGRES_USER=your-user \
  -e POSTGRES_PASSWORD=your-pass \
  -e POSTGRES_DB=your-database \
  -e VERBOSE_MODE=false \
  postgres-benchmark
```

For **debugging/monitoring** (shows progress but may slightly impact results):
```bash
# Verbose mode - shows progress every 30 seconds
docker run --rm \
  -v $(pwd)/results:/app/results \
  -e POSTGRES_HOST=your-host \
  -e POSTGRES_USER=your-user \
  -e POSTGRES_PASSWORD=your-pass \
  -e POSTGRES_DB=your-database \
  -e VERBOSE_MODE=true \
  postgres-benchmark
```

## Results Location

### Option 1: View Results in Terminal Only
Results are displayed in the terminal during and after the tests. No files are saved.

```bash
docker run --rm \
  -e POSTGRES_HOST=your-db-host \
  -e POSTGRES_USER=your-user \
  -e POSTGRES_PASSWORD=your-pass \
  -e POSTGRES_DB=your-database \
  postgres-benchmark
```

### Option 2: Save Results to Your Computer
Add `-v $(pwd)/results:/app/results` to save detailed results to your computer:

```bash
docker run --rm \
  -v $(pwd)/results:/app/results \
  -e POSTGRES_HOST=your-db-host \
  -e POSTGRES_USER=your-user \
  -e POSTGRES_PASSWORD=your-pass \
  -e POSTGRES_DB=your-database \
  postgres-benchmark
```

Results will be saved in the `results/` folder with:
- Detailed test outputs for each test
- `PERFORMANCE_SUMMARY.txt` - Easy-to-read summary
- Recommendations for improvements

## Troubleshooting

### "Cannot connect to database"
- Check your `POSTGRES_HOST`, `POSTGRES_USER`, and `POSTGRES_PASSWORD`
- Make sure the database server is running
- Verify network connectivity

### "Permission denied"
- Make sure your user has permission to create tables
- The tool needs to create test tables in the specified database

### Tests are too fast/slow
- Adjust `TEST_DURATION` (in seconds)
- Adjust `SCALE_FACTOR` for more/less test data

## What the Numbers Mean

| TPS Range | Performance | What It Means |
|-----------|-------------|---------------|
| 1000+ | Excellent | Can handle heavy workloads |
| 500-1000 | Good | Suitable for most applications |
| 200-500 | Fair | OK for light-medium usage |
| 50-200 | Poor | May struggle with busy apps |
| <50 | Very Poor | Needs optimization/upgrades |

## Performance Impact Notes

**Background Execution:**
- **pgbench runs in background** with zero I/O interference for maximum accuracy
- **Monitoring thread** provides progress updates without affecting performance
- **No real-time output** from pgbench itself to avoid any overhead

**Output Mode Impact:**
- **Performance Mode** (`VERBOSE_MODE=false`): Pure background execution, maximum accuracy
- **Verbose Mode** (`VERBOSE_MODE=true`): Background execution with minimal progress logging

**Why this approach is superior:**
- **Zero I/O overhead** during test execution
- **Maximum accuracy** - pgbench runs completely isolated
- **User-friendly progress** without performance impact
- **Works with any pgbench version** and output format

**Progress Display:**
- Real-time percentage and time remaining
- Non-interfering progress updates every 2 seconds
- No impact on actual database performance testing

## Safety Notes

- This tool creates temporary test tables (they're cleaned up automatically)
- It only reads/writes test data, never your actual application data
- Safe to run on production databases (but test on staging first!)

## Need Help?

If you see unexpected results or errors, check:
1. Database connection settings
2. User permissions
3. Available disk space on database server
4. Network connectivity

The tool provides clear error messages to help you troubleshoot!
