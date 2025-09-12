#!/bin/bash

# Script to download/clone the mpzsql repository
# This script is designed to be flexible for both local development and CI/CD

set -e  # Exit on any error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MPZSQL_DIR="$PROJECT_ROOT/mpzsql"

# Configuration
MPZSQL_REPO_URL="${MPZSQL_REPO_URL:-https://github.com/MiguelElGallo/mpzsql.git}"
MPZSQL_BRANCH="${MPZSQL_BRANCH:-main}"
FORCE_CLEAN="${FORCE_CLEAN:-false}"

echo "=== MPZSQL Repository Download Script ==="
echo "Repository URL: $MPZSQL_REPO_URL"
echo "Branch: $MPZSQL_BRANCH"
echo "Target directory: $MPZSQL_DIR"
echo "Force clean: $FORCE_CLEAN"
echo

# Function to clean existing directory
clean_existing() {
    if [ -d "$MPZSQL_DIR" ]; then
        echo "Removing existing mpzsql directory..."
        rm -rf "$MPZSQL_DIR"
    fi
}

# Function to clone repository
clone_repo() {
    echo "Cloning mpzsql repository..."
    git clone --branch "$MPZSQL_BRANCH" --depth 1 "$MPZSQL_REPO_URL" "$MPZSQL_DIR"
    echo "Repository cloned successfully to $MPZSQL_DIR"
    
    # Remove .git folder to disconnect from original repository
    echo "Disconnecting from original repository..."
    rm -rf "$MPZSQL_DIR/.git"
    echo "Git connection removed - mpzsql is now standalone"
}

# Main logic
if [ "$FORCE_CLEAN" = "true" ]; then
    clean_existing
    clone_repo
elif [ -d "$MPZSQL_DIR" ]; then
    echo "Found existing mpzsql directory."
    echo "Use FORCE_CLEAN=true to remove and re-download, or remove manually."
    echo "Current directory: $MPZSQL_DIR"
    exit 1
else
    clone_repo
fi

# Verify the download
if [ -f "$MPZSQL_DIR/pyproject.toml" ] && [ -f "$MPZSQL_DIR/uv.lock" ]; then
    echo "✓ MPZSQL repository downloaded successfully"
    echo "✓ UV project files detected (pyproject.toml and uv.lock)"
elif [ -f "$MPZSQL_DIR/pyproject.toml" ]; then
    echo "✓ MPZSQL repository downloaded successfully"
    echo "✓ Python project files detected (pyproject.toml)"
else
    echo "⚠ Warning: No Python project files found. Please verify the repository structure."
fi

echo
echo "=== Download Complete ==="
echo "MPZSQL is available at: $MPZSQL_DIR"
