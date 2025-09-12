#!/bin/bash
#
# Store Let's Encrypt certificate files as GitHub secrets
# This script uploads the certificate and private key files to GitHub repository secrets
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print colored output
print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Certificate files
CERT_DIR="$PROJECT_ROOT/secrets/certs"
CERT_FILE="$CERT_DIR/letsencrypt-server.crt"
KEY_FILE="$CERT_DIR/letsencrypt-server.key"

print_info "Let's Encrypt Certificate to GitHub Secrets Uploader"
echo

# Check if certificate files exist
if [[ ! -f "$CERT_FILE" ]]; then
    print_error "Certificate file not found: $CERT_FILE"
    exit 1
fi

if [[ ! -f "$KEY_FILE" ]]; then
    print_error "Private key file not found: $KEY_FILE"
    exit 1
fi

print_success "Found certificate files:"
echo "  📄 Certificate: $CERT_FILE"
echo "  🔑 Private Key: $KEY_FILE"
echo

# Check for GitHub token
if [[ -z "$GITHUB_TOKEN" && -z "$GITHUB_API_TOKEN" ]]; then
    print_warning "GitHub token not found in environment variables."
    echo
    echo "Please set either GITHUB_TOKEN or GITHUB_API_TOKEN:"
    echo "  export GITHUB_TOKEN=your_token_here"
    echo
    echo "To create a token:"
    echo "  1. Go to https://github.com/settings/tokens"
    echo "  2. Click 'Generate new token (classic)'"
    echo "  3. Select scopes: 'repo' (all)"
    echo "  4. Generate and copy the token"
    echo
    exit 1
fi

# Check if we have uv
if ! command -v uv &> /dev/null; then
    print_error "uv is required but not installed"
    exit 1
fi

# Run the Python script
print_info "Running certificate upload script with uv..."
echo

# Parse command line arguments
PYTHON_ARGS=()
DRY_RUN=false
LIST_SECRETS=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            PYTHON_ARGS+=("$1")
            shift
            ;;
        --list)
            LIST_SECRETS=true
            PYTHON_ARGS+=("$1")
            shift
            ;;
        --debug)
            PYTHON_ARGS+=("$1")
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo
            echo "Options:"
            echo "  --dry-run    Show what would be uploaded without making changes"
            echo "  --list       List current repository secrets"
            echo "  --debug      Enable debug output"
            echo "  --help       Show this help message"
            echo
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Add certificate directory argument
PYTHON_ARGS+=("--cert-dir" "$CERT_DIR")

# Execute the Python script with uv
cd "$PROJECT_ROOT"
uv run "$SCRIPT_DIR/set_cert_secrets.py" "${PYTHON_ARGS[@]}"
exit_code=$?

echo

if [[ $exit_code -eq 0 ]]; then
    if [[ "$LIST_SECRETS" == "true" ]]; then
        print_success "Successfully listed repository secrets"
    elif [[ "$DRY_RUN" == "true" ]]; then
        print_success "Dry run completed successfully"
    else
        print_success "Certificate secrets uploaded successfully!"
        echo
        print_info "The following secrets are now available in GitHub Actions:"
        echo "  • LETSENCRYPT_CERT - The SSL certificate"
        echo "  • LETSENCRYPT_KEY  - The private key"
        echo
        print_info "You can use them in your workflows like:"
        echo '  ${{ secrets.LETSENCRYPT_CERT }}'
        echo '  ${{ secrets.LETSENCRYPT_KEY }}'
    fi
else
    print_error "Failed to upload certificate secrets"
    exit $exit_code
fi
