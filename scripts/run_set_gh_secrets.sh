#!/bin/bash

# Script to set up environment variables and run the GitHub secrets sync script
# This script sources the environment variables from set_env.sh and then runs
# the Python script to sync those variables to GitHub repository secrets

set -e  # Exit on any error

# Get the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Path to the environment file
ENV_FILE="$PROJECT_ROOT/secrets/set_env.sh"
PYTHON_SCRIPT="$SCRIPT_DIR/python/set_gh_secrets.py"

echo "🔧 Setting up GitHub secrets sync..."
echo "📍 Project root: $PROJECT_ROOT"
echo "📄 Environment file: $ENV_FILE"
echo "🐍 Python script: $PYTHON_SCRIPT"

# Check if environment file exists
if [[ ! -f "$ENV_FILE" ]]; then
    echo "❌ Environment file not found: $ENV_FILE"
    exit 1
fi

# Check if Python script exists
if [[ ! -f "$PYTHON_SCRIPT" ]]; then
    echo "❌ Python script not found: $PYTHON_SCRIPT"
    exit 1
fi

echo ""
echo "📖 Sourcing environment variables from $ENV_FILE..."

# Source the environment variables
source "$ENV_FILE"

echo "✅ Environment variables loaded"

# Verify required variables are set
if [[ -z "$ADMIN_PAT" ]]; then
    echo "❌ ADMIN_PAT environment variable is not set"
    exit 1
fi

if [[ -z "$GITHUB_REPO" ]]; then
    echo "❌ GITHUB_REPO environment variable is not set"
    exit 1
fi

if [[ -z "$GITHUB_OWNER" ]]; then
    echo "❌ GITHUB_OWNER environment variable is not set"
    exit 1
fi

echo "✅ Required environment variables verified:"
echo "   - GITHUB_OWNER: $GITHUB_OWNER"
echo "   - GITHUB_REPO: $GITHUB_REPO"
echo "   - ADMIN_PAT: [SET]"

# Set the GITHUB_REPOSITORY environment variable that the Python script expects
export GITHUB_REPOSITORY="$GITHUB_OWNER/$GITHUB_REPO"
export GITHUB_TOKEN="$ADMIN_PAT"

echo "   - GITHUB_REPOSITORY: $GITHUB_REPOSITORY"

echo ""
echo "🔧 Setting up Python environment..."

# Check if we're in the mpzsql directory context and try to use uv
if command -v uv >/dev/null 2>&1 && [[ -f "$PROJECT_ROOT/mpzsql/uv.lock" ]]; then
    echo "📦 Using uv to install dependencies..."
    cd "$PROJECT_ROOT/mpzsql"
    # Install the required packages for the script
    uv add requests pynacl --group dev || true
    echo "🚀 Running GitHub secrets sync script with uv..."
    uv run python "$PYTHON_SCRIPT" \
        --token "$ADMIN_PAT" \
        --secrets-file "$ENV_FILE"
else
    echo "🐍 Creating temporary virtual environment..."
    TEMP_VENV="/tmp/gh_secrets_venv"
    
    # Clean up any existing temp venv
    rm -rf "$TEMP_VENV"
    
    # Create virtual environment
    python3 -m venv "$TEMP_VENV"
    source "$TEMP_VENV/bin/activate"
    
    # Install required packages
    pip install requests pynacl
    
    echo "🚀 Running GitHub secrets sync script..."
    python "$PYTHON_SCRIPT" \
        --token "$ADMIN_PAT" \
        --secrets-file "$ENV_FILE"
    
    # Clean up
    deactivate
    rm -rf "$TEMP_VENV"
fi

echo ""
echo "✅ GitHub secrets sync completed!"
