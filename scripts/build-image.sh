#!/bin/bash

# Build script for MPZSQL Docker image
# Flexible script for local development and CI/CD environments

set -e  # Exit on any error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Configuration with defaults
IMAGE_NAME="${IMAGE_NAME:-ducklake/mpzsql}"
IMAGE_TAG="${IMAGE_TAG:-latest}"
DOCKERFILE_PATH="${DOCKERFILE_PATH:-$PROJECT_ROOT/Dockerfile}"
BUILD_CONTEXT="${BUILD_CONTEXT:-$PROJECT_ROOT}"
PLATFORM="${PLATFORM:-linux/amd64}"
NO_CACHE="${NO_CACHE:-false}"

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

# Function to check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed or not in PATH"
        exit 1
    fi
    
    if [ ! -f "$DOCKERFILE_PATH" ]; then
        log_error "Dockerfile not found at: $DOCKERFILE_PATH"
        exit 1
    fi
    
    if [ ! -d "$PROJECT_ROOT/mpzsql" ]; then
        log_warning "MPZSQL directory not found. Running download script..."
        "$SCRIPT_DIR/download-mpzsql.sh"
    fi
    
    log_success "Prerequisites check passed"
}

# Function to prepare build context
prepare_build_context() {
    log_info "Preparing build context..."
    
    # Ensure certs directory exists for Docker COPY
    if [ ! -d "$BUILD_CONTEXT/certs" ]; then
        log_info "Creating certs directory for build context"
        mkdir -p "$BUILD_CONTEXT/certs"
    fi
    
    # Check if TLS certificates were prepared by CI
    if [ -f "$BUILD_CONTEXT/certs/letsencrypt.crt" ] && [ -f "$BUILD_CONTEXT/certs/letsencrypt.key" ]; then
        log_info "LetsEncrypt TLS certificates found in build context"
    else
        log_info "No LetsEncrypt TLS certificates found - image will run without TLS"
    fi
    
    log_success "Build context prepared"
}

# Function to build Docker image
build_image() {
    log_info "Building Docker image..."
    echo "Image: $IMAGE_NAME:$IMAGE_TAG"
    echo "Platform: $PLATFORM"
    echo "Context: $BUILD_CONTEXT"
    echo "Dockerfile: $DOCKERFILE_PATH"
    echo
    
    # Build arguments
    BUILD_ARGS=(
        "--file" "$DOCKERFILE_PATH"
        "--tag" "$IMAGE_NAME:$IMAGE_TAG"
        "--platform" "$PLATFORM"
    )
    
    # Add no-cache flag if requested
    if [ "$NO_CACHE" = "true" ]; then
        BUILD_ARGS+=("--no-cache")
        log_info "Building with --no-cache flag"
    fi
    
    # Add build context
    BUILD_ARGS+=("$BUILD_CONTEXT")
    
    # Execute build
    if docker build "${BUILD_ARGS[@]}"; then
        log_success "Docker image built successfully: $IMAGE_NAME:$IMAGE_TAG"
    else
        log_error "Docker build failed"
        exit 1
    fi
}

# Function to verify the image
verify_image() {
    log_info "Verifying the built image..."
    
    if docker image inspect "$IMAGE_NAME:$IMAGE_TAG" &> /dev/null; then
        # Try to get image size with numfmt if available, otherwise use raw bytes
        if command -v numfmt &> /dev/null; then
            IMAGE_SIZE=$(docker image inspect "$IMAGE_NAME:$IMAGE_TAG" --format='{{.Size}}' | numfmt --to=iec)
        else
            IMAGE_SIZE=$(docker image inspect "$IMAGE_NAME:$IMAGE_TAG" --format='{{.Size}}' | awk '{printf "%.1fMB", $1/1048576}')
        fi
        log_success "Image verification passed"
        log_info "Image size: $IMAGE_SIZE"
    else
        log_error "Image verification failed"
        exit 1
    fi
}

# Function to display usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Build MPZSQL Docker image with flexible configuration"
    echo
    echo "Environment Variables:"
    echo "  IMAGE_NAME      Docker image name (default: ducklake/mpzsql)"
    echo "  IMAGE_TAG       Docker image tag (default: latest)"
    echo "  DOCKERFILE_PATH Path to Dockerfile (default: ../Dockerfile)"
    echo "  BUILD_CONTEXT   Build context directory (default: ..)"
    echo "  PLATFORM        Target platform (default: linux/amd64)"
    echo "  NO_CACHE        Skip cache during build (default: false)"
    echo
    echo "Options:"
    echo "  -h, --help      Show this help message"
    echo "  --no-cache      Build without using cache"
    echo "  --verify-only   Only verify existing image"
    echo
    echo "Examples:"
    echo "  $0                                    # Build with defaults"
    echo "  IMAGE_NAME=myrepo/mpzsql $0          # Custom image name"
    echo "  NO_CACHE=true $0                     # Build without cache"
    echo "  $0 --no-cache                        # Build without cache (flag)"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_usage
            exit 0
            ;;
        --no-cache)
            NO_CACHE=true
            shift
            ;;
        --verify-only)
            verify_image
            exit 0
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
    echo "=== MPZSQL Docker Build Script ==="
    echo "Timestamp: $(date)"
    echo "User: $(whoami)"
    echo "Working directory: $(pwd)"
    echo
    
    check_prerequisites
    prepare_build_context
    build_image
    verify_image
    
    echo
    log_success "Build process completed successfully!"
    echo "Image: $IMAGE_NAME:$IMAGE_TAG"
    echo
    echo "Next steps:"
    echo "  • Run locally: ./scripts/run-container.sh"
    echo "  • Push to registry: docker push $IMAGE_NAME:$IMAGE_TAG"
    echo "  • Tag for production: docker tag $IMAGE_NAME:$IMAGE_TAG $IMAGE_NAME:prod"
}

# Execute main function
main "$@"
