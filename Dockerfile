# Multi-stage Dockerfile for MPZSQL
# Optimized for production deployment with UV package manager

# Build stage
FROM python:3.11-slim AS builder

# Set working directory
WORKDIR /app

# Install system dependencies for building and UV
RUN apt-get update && apt-get install -y \
    build-essential \
    git \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Install UV package manager
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /usr/local/bin/

# Copy the mpzsql source code
COPY mpzsql/ ./

# Install Python dependencies using UV
# UV will use pyproject.toml and uv.lock for exact dependency resolution
RUN uv sync --frozen --no-dev

# Production stage
FROM python:3.11-slim

# Set working directory
WORKDIR /app

# Install runtime dependencies and UV
RUN apt-get update && apt-get install -y \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Install UV package manager
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /usr/local/bin/

# Copy UV virtual environment from builder stage
COPY --from=builder /app/.venv /app/.venv

# Copy application code
COPY --from=builder /app /app

# Copy entrypoint script
COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

# Create certs directory
RUN mkdir -p /app/certs

# Create non-root user for security
RUN groupadd -r mpzsql && useradd -r -g mpzsql mpzsql -m

# Copy LetsEncrypt TLS certificates if they exist (will be created by CI if secrets exist)
# This copies only from the build context certs directory, not from mpzsql/certs
COPY --chown=mpzsql:mpzsql certs/ /app/certs/

# Set ownership
RUN chown -R mpzsql:mpzsql /app

# Create UV cache directory with proper permissions
RUN mkdir -p /home/mpzsql/.cache/uv && chown -R mpzsql:mpzsql /home/mpzsql/.cache

USER mpzsql

# Activate virtual environment by adding it to PATH
ENV PATH="/app/.venv/bin:$PATH"
# Set UV cache directory
ENV UV_CACHE_DIR="/home/mpzsql/.cache/uv"

# Environment variables with defaults
ENV POSTGRESQL_SERVER=""
ENV POSTGRESQL_USER=""
ENV POSTGRESQL_PORT="5432"
ENV POSTGRESQL_CATALOGDB=""
ENV POSTGRESQL_PASSWORD=""
ENV LOGFIRE_WRITE_TOKEN=""
ENV AZURE_STORAGE_ACCOUNT=""
ENV AZURE_STORAGE_CONTAINER=""
ENV LETSENCRYPT_CERT=""
ENV LETSENCRYPT_KEY=""

# Expose port 8080
EXPOSE 8080

# Health check - check if the server is responding on port 8080
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD curl -f http://localhost:8080/ || exit 1

# Default command (can be overridden) - use entrypoint script for conditional TLS
CMD ["/app/entrypoint.sh"]
