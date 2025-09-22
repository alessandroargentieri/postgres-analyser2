FROM postgres:16-alpine

# Install required packages
RUN apk add --no-cache \
    bash \
    bc \
    curl \
    jq

# Create app directory
WORKDIR /app

# Copy test scripts
COPY test-runner.sh /app/
COPY analyze-results.sh /app/

# Make scripts executable
RUN chmod +x /app/test-runner.sh /app/analyze-results.sh

# Create results directory
RUN mkdir -p /app/results

# Set default environment variables
ENV POSTGRES_HOST=localhost
ENV POSTGRES_PORT=5432
ENV POSTGRES_USER=postgres
ENV POSTGRES_PASSWORD=postgres
ENV POSTGRES_DB=testdb
ENV SCALE_FACTOR=10
ENV TEST_DURATION=60
ENV VERBOSE_MODE=false

# Default command
CMD ["/app/test-runner.sh"]