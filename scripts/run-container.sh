#!/bin/bash

# Run script for MPZSQL Docker container
# Loads environment variables and runs the container with proper configuration

set -e  # Exit on any error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Configuration with defaults
IMAGE_NAME="${IMAGE_NAME:-ducklake/mpzsql}"
IMAGE_TAG="${IMAGE_TAG:-latest}"
CONTAINER_NAME="${CONTAINER_NAME:-mpzsql-container}"
HOST_PORT="${HOST_PORT:-8080}"
CONTAINER_PORT="${CONTAINER_PORT:-8080}"
ENV_FILE="${ENV_FILE:-$PROJECT_ROOT/secrets/set_env.sh}"
DETACHED="${DETACHED:-false}"
REMOVE_ON_EXIT="${REMOVE_ON_EXIT:-true}"

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
    
    if ! docker image inspect "$IMAGE_NAME:$IMAGE_TAG" &> /dev/null; then
        log_error "Docker image $IMAGE_NAME:$IMAGE_TAG not found"
        log_info "Run './scripts/build-image.sh' first to build the image"
        exit 1
    fi
    
    if [ ! -f "$ENV_FILE" ]; then
        log_error "Environment file not found: $ENV_FILE"
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

# Function to parse environment variables from set_env.sh
parse_env_variables() {
    log_info "Loading environment variables from $ENV_FILE"
    
    # Extract export statements and convert to Docker env format
    ENV_VARS=()
    
    while IFS= read -r line; do
        # Skip comments and empty lines
        if [[ "$line" =~ ^[[:space:]]*# ]] || [[ -z "${line// }" ]]; then
            continue
        fi
        
        # Process export statements
        if [[ "$line" =~ ^[[:space:]]*export[[:space:]]+([A-Z_][A-Z0-9_]*)=(.*)$ ]]; then
            var_name="${BASH_REMATCH[1]}"
            var_value="${BASH_REMATCH[2]}"
            
            # Remove quotes from value if present
            var_value=$(echo "$var_value" | sed 's/^"//; s/"$//')
            
            # Handle variable substitution (basic cases)
            if [[ "$var_value" =~ ^\$(.+)$ ]]; then
                ref_var="${BASH_REMATCH[1]}"
                # Find the value of the referenced variable
                for env_var in "${ENV_VARS[@]}"; do
                    if [[ "$env_var" =~ ^${ref_var}=(.*)$ ]]; then
                        var_value="${BASH_REMATCH[1]}"
                        break
                    fi
                done
            fi
            
            ENV_VARS+=("$var_name=$var_value")
            log_info "  ✓ $var_name"
        fi
    done < "$ENV_FILE"
    
    log_success "Loaded ${#ENV_VARS[@]} environment variables"
}

# Function to stop existing container
stop_existing_container() {
    if docker ps -q -f name="$CONTAINER_NAME" | grep -q .; then
        log_warning "Stopping existing container: $CONTAINER_NAME"
        docker stop "$CONTAINER_NAME" || true
    fi
    
    if docker ps -aq -f name="$CONTAINER_NAME" | grep -q .; then
        log_warning "Removing existing container: $CONTAINER_NAME"
        docker rm "$CONTAINER_NAME" || true
    fi
}

# Function to run the container
run_container() {
    log_info "Starting MPZSQL container..."
    
    # Build docker run command
    DOCKER_ARGS=(
        "run"
        "--name" "$CONTAINER_NAME"
        "--publish" "$HOST_PORT:$CONTAINER_PORT"
    )
    
    # Add environment variables
    for env_var in "${ENV_VARS[@]}"; do
        DOCKER_ARGS+=("--env" "$env_var")
    done
    
    # Add flags based on configuration
    if [ "$DETACHED" = "true" ]; then
        DOCKER_ARGS+=("--detach")
    else
        DOCKER_ARGS+=("--interactive" "--tty")
    fi
    
    if [ "$REMOVE_ON_EXIT" = "true" ]; then
        DOCKER_ARGS+=("--rm")
    fi
    
    # Add image
    DOCKER_ARGS+=("$IMAGE_NAME:$IMAGE_TAG")
    
    # Execute docker run
    log_info "Running: docker ${DOCKER_ARGS[*]}"
    echo
    
    if docker "${DOCKER_ARGS[@]}"; then
        if [ "$DETACHED" = "true" ]; then
            log_success "Container started successfully in background"
            log_info "Container name: $CONTAINER_NAME"
            log_info "Access URL: http://localhost:$HOST_PORT"
            echo
            echo "Management commands:"
            echo "  • View logs: docker logs -f $CONTAINER_NAME"
            echo "  • Stop container: docker stop $CONTAINER_NAME"
            echo "  • Container status: docker ps -f name=$CONTAINER_NAME"
        else
            log_info "Container stopped"
        fi
    else
        log_error "Failed to start container"
        exit 1
    fi
}

# Function to display usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Run MPZSQL Docker container with environment variables"
    echo
    echo "Environment Variables:"
    echo "  IMAGE_NAME       Docker image name (default: ducklake/mpzsql)"
    echo "  IMAGE_TAG        Docker image tag (default: latest)"
    echo "  CONTAINER_NAME   Container name (default: mpzsql-container)"
    echo "  HOST_PORT        Host port to bind (default: 8080)"
    echo "  CONTAINER_PORT   Container port (default: 8080)"
    echo "  ENV_FILE         Environment file path (default: ../secrets/set_env.sh)"
    echo "  DETACHED         Run in background (default: false)"
    echo "  REMOVE_ON_EXIT   Remove container on exit (default: true)"
    echo
    echo "Options:"
    echo "  -h, --help       Show this help message"
    echo "  -d, --detach     Run container in background"
    echo "  --no-rm          Don't remove container on exit"
    echo "  --port PORT      Set host port"
    echo
    echo "Examples:"
    echo "  $0                           # Run interactively"
    echo "  $0 --detach                  # Run in background"
    echo "  HOST_PORT=9090 $0            # Use custom port"
    echo "  $0 --port 9090 --detach      # Custom port in background"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_usage
            exit 0
            ;;
        -d|--detach)
            DETACHED=true
            shift
            ;;
        --no-rm)
            REMOVE_ON_EXIT=false
            shift
            ;;
        --port)
            if [[ -n $2 && $2 =~ ^[0-9]+$ ]]; then
                HOST_PORT=$2
                shift 2
            else
                log_error "Invalid port number: $2"
                exit 1
            fi
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
    echo "=== MPZSQL Docker Run Script ==="
    echo "Timestamp: $(date)"
    echo "Image: $IMAGE_NAME:$IMAGE_TAG"
    echo "Container: $CONTAINER_NAME"
    echo "Port mapping: $HOST_PORT:$CONTAINER_PORT"
    echo "Environment file: $ENV_FILE"
    echo "Detached mode: $DETACHED"
    echo
    
    check_prerequisites
    parse_env_variables
    stop_existing_container
    run_container
    
    echo
    log_success "Run script completed!"
}

# Execute main function
main "$@"
