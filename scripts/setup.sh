#!/bin/bash

# Complete setup script for MPZSQL development environment
# This script orchestrates the entire setup process

set -e  # Exit on any error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Configuration
SKIP_DOWNLOAD="${SKIP_DOWNLOAD:-false}"
SKIP_BUILD="${SKIP_BUILD:-false}"
AUTO_RUN="${AUTO_RUN:-false}"
CLEAN_BUILD="${CLEAN_BUILD:-false}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to display usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Complete setup script for MPZSQL development environment"
    echo
    echo "Environment Variables:"
    echo "  SKIP_DOWNLOAD    Skip repository download (default: false)"
    echo "  SKIP_BUILD       Skip Docker image build (default: false)"
    echo "  AUTO_RUN         Automatically run container after build (default: false)"
    echo "  CLEAN_BUILD      Force clean build (default: false)"
    echo
    echo "Options:"
    echo "  -h, --help       Show this help message"
    echo "  --skip-download  Skip repository download"
    echo "  --skip-build     Skip Docker build"
    echo "  --auto-run       Run container after successful build"
    echo "  --clean-build    Force clean build without cache"
    echo "  --download-only  Only download repository"
    echo "  --build-only     Only build Docker image"
    echo
    echo "Examples:"
    echo "  $0                           # Full setup"
    echo "  $0 --skip-download           # Build only (repo exists)"
    echo "  $0 --auto-run                # Setup and run"
    echo "  $0 --clean-build --auto-run  # Clean build and run"
}

# Function to create directory structure
setup_directories() {
    log_info "Setting up directory structure..."
    
    mkdir -p "$PROJECT_ROOT/scripts"
    mkdir -p "$PROJECT_ROOT/secrets"
    
    log_success "Directory structure ready"
}

# Function to download repository
download_repository() {
    if [ "$SKIP_DOWNLOAD" = "true" ]; then
        log_info "Skipping repository download"
        return 0
    fi
    
    log_info "Step 1: Downloading MPZSQL repository..."
    
    if [ "$CLEAN_BUILD" = "true" ]; then
        export FORCE_CLEAN=true
    fi
    
    "$SCRIPT_DIR/download-mpzsql.sh"
    log_success "Repository download completed"
}

# Function to build Docker image
build_docker_image() {
    if [ "$SKIP_BUILD" = "true" ]; then
        log_info "Skipping Docker build"
        return 0
    fi
    
    log_info "Step 2: Building Docker image..."
    
    if [ "$CLEAN_BUILD" = "true" ]; then
        export NO_CACHE=true
    fi
    
    "$SCRIPT_DIR/build-image.sh"
    log_success "Docker image build completed"
}

# Function to run container
run_container() {
    if [ "$AUTO_RUN" != "true" ]; then
        log_info "Skipping container run (use --auto-run to enable)"
        return 0
    fi
    
    log_info "Step 3: Running container..."
    
    export DETACHED=true
    "$SCRIPT_DIR/run-container.sh"
    log_success "Container started successfully"
}

# Function to verify setup
verify_setup() {
    log_info "Verifying setup..."
    
    # Check if repository exists
    if [ ! -d "$PROJECT_ROOT/mpzsql" ]; then
        log_error "MPZSQL repository not found"
        return 1
    fi
    
    # Check if Docker image exists
    if ! docker image inspect "ducklake/mpzsql:latest" &> /dev/null; then
        log_warning "Docker image not built yet"
        return 1
    fi
    
    # Check if environment file exists
    if [ ! -f "$PROJECT_ROOT/secrets/set_env.sh" ]; then
        log_warning "Environment file not found at secrets/set_env.sh"
        return 1
    fi
    
    log_success "Setup verification passed"
    return 0
}

# Function to display next steps
show_next_steps() {
    echo
    echo "=== Next Steps ==="
    echo
    echo "Development workflow:"
    echo "  1. Edit environment variables: vim secrets/set_env.sh"
    echo "  2. Rebuild image: ./scripts/build-image.sh"
    echo "  3. Run container: ./scripts/run-container.sh"
    echo "  4. View logs: docker logs -f mpzsql-container"
    echo
    echo "Useful commands:"
    echo "  • Check container status: docker ps"
    echo "  • Stop container: docker stop mpzsql-container"
    echo "  • Clean rebuild: CLEAN_BUILD=true ./scripts/setup.sh"
    echo "  • Access application: http://localhost:8080"
    echo
    echo "GitHub Actions preparation:"
    echo "  • All scripts are ready for CI/CD integration"
    echo "  • Environment variables can be set via GitHub Secrets"
    echo "  • Use these scripts in .github/workflows/ files"
    echo
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_usage
            exit 0
            ;;
        --skip-download)
            SKIP_DOWNLOAD=true
            shift
            ;;
        --skip-build)
            SKIP_BUILD=true
            shift
            ;;
        --auto-run)
            AUTO_RUN=true
            shift
            ;;
        --clean-build)
            CLEAN_BUILD=true
            shift
            ;;
        --download-only)
            SKIP_BUILD=true
            AUTO_RUN=false
            shift
            ;;
        --build-only)
            SKIP_DOWNLOAD=true
            AUTO_RUN=false
            shift
            ;;
        *)
            log_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Main execution
main() {
    echo "=== MPZSQL Complete Setup Script ==="
    echo "Timestamp: $(date)"
    echo "Project root: $PROJECT_ROOT"
    echo "Skip download: $SKIP_DOWNLOAD"
    echo "Skip build: $SKIP_BUILD"
    echo "Auto run: $AUTO_RUN"
    echo "Clean build: $CLEAN_BUILD"
    echo
    
    setup_directories
    download_repository
    build_docker_image
    run_container
    
    echo
    log_success "Setup completed successfully!"
    
    if verify_setup; then
        show_next_steps
    else
        log_warning "Some components may not be fully configured"
        show_next_steps
    fi
}

# Execute main function
main "$@"
