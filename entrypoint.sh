#!/bin/bash

# Entrypoint script for MPZSQL container with conditional TLS support
# This script checks for TLS certificates and adds appropriate flags

set -e

# Default command arguments
DEFAULT_ARGS=("python" "-m" "mpzsql.cli" "--hostname" "0.0.0.0" "--port" "8080")

# Check specifically for certificates from CI secrets (not sample certificates)
TLS_CERT_PATH="/app/certs/letsencrypt.crt"
TLS_KEY_PATH="/app/certs/letsencrypt.key"

# Build command arguments
CMD_ARGS=("${DEFAULT_ARGS[@]}")

if [ -f "$TLS_CERT_PATH" ] && [ -f "$TLS_KEY_PATH" ]; then
    echo "🔐 LetsEncrypt TLS certificates found - enabling TLS"
    CMD_ARGS+=("--tls-cert" "$TLS_CERT_PATH" "--tls-key" "$TLS_KEY_PATH")
else
    echo "ℹ️ No LetsEncrypt TLS certificates found - running without TLS"
fi

# Add any additional arguments passed to the container
CMD_ARGS+=("$@")

echo "🚀 Starting MPZSQL server with: ${CMD_ARGS[*]}"

# Execute the command
exec "${CMD_ARGS[@]}"