#!/bin/bash
#
# Run certificate upload with token from file
#

set -e

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Read token from file
TOKEN_FILE="$PROJECT_ROOT/secrets/githubtoken.txt"

if [[ ! -f "$TOKEN_FILE" ]]; then
    echo "❌ Token file not found: $TOKEN_FILE"
    exit 1
fi

# Read token and export it
export GITHUB_TOKEN=$(cat "$TOKEN_FILE" | tr -d '\n\r\t ')

echo "🔑 Using GitHub token from $TOKEN_FILE"
echo "🚀 Running certificate upload script with uv..."
echo

# Run the upload script with uv
cd "$PROJECT_ROOT"
exec uv run "$SCRIPT_DIR/set_cert_secrets.py" --token "$GITHUB_TOKEN" "$@"
