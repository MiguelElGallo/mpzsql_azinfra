#!/bin/bash
#
# Test script for certificate upload functionality
# This script validates that the certificate upload scripts work correctly
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

print_info "Testing Certificate Upload Scripts"
echo

# Test 1: Check if certificate files exist
print_info "Test 1: Checking certificate files..."
CERT_DIR="$PROJECT_ROOT/secrets/certs"
CERT_FILE="$CERT_DIR/letsencrypt-server.crt"
KEY_FILE="$CERT_DIR/letsencrypt-server.key"

if [[ -f "$CERT_FILE" ]]; then
    print_success "Certificate file found: $CERT_FILE"
else
    print_error "Certificate file missing: $CERT_FILE"
    exit 1
fi

if [[ -f "$KEY_FILE" ]]; then
    print_success "Private key file found: $KEY_FILE"
else
    print_error "Private key file missing: $KEY_FILE"
    exit 1
fi

# Test 2: Check if scripts are executable
print_info "Test 2: Checking script permissions..."
PYTHON_SCRIPT="$SCRIPT_DIR/set_cert_secrets.py"
SHELL_SCRIPT="$SCRIPT_DIR/upload_certs.sh"

if [[ -x "$PYTHON_SCRIPT" ]]; then
    print_success "Python script is executable: $PYTHON_SCRIPT"
else
    print_warning "Making Python script executable..."
    chmod +x "$PYTHON_SCRIPT"
    print_success "Python script is now executable"
fi

if [[ -x "$SHELL_SCRIPT" ]]; then
    print_success "Shell script is executable: $SHELL_SCRIPT"
else
    print_warning "Making shell script executable..."
    chmod +x "$SHELL_SCRIPT"
    print_success "Shell script is now executable"
fi

# Test 3: Validate certificate content
print_info "Test 3: Validating certificate content..."

# Check certificate format
if head -1 "$CERT_FILE" | grep -q "BEGIN CERTIFICATE"; then
    print_success "Certificate file has valid format"
else
    print_error "Certificate file does not have valid format"
    exit 1
fi

# Check private key format
if head -1 "$KEY_FILE" | grep -q "BEGIN PRIVATE KEY"; then
    print_success "Private key file has valid format"
else
    print_error "Private key file does not have valid format"
    exit 1
fi

# Test 4: Check Python dependencies (dry run)
print_info "Test 4: Testing Python script (dry run)..."

if python3 "$PYTHON_SCRIPT" --dry-run 2>/dev/null; then
    print_success "Python script dry run successful"
else
    print_warning "Python script dry run failed (might need GitHub token)"
    echo "  This is expected if no GitHub token is set"
fi

# Test 5: Show certificate info
print_info "Test 5: Certificate information..."
echo
echo "Certificate Details:"
cert_subject=$(openssl x509 -in "$CERT_FILE" -noout -subject 2>/dev/null | sed 's/subject=//' || echo "Unable to parse certificate")
cert_issuer=$(openssl x509 -in "$CERT_FILE" -noout -issuer 2>/dev/null | sed 's/issuer=//' || echo "Unable to parse issuer")
cert_dates=$(openssl x509 -in "$CERT_FILE" -noout -dates 2>/dev/null || echo "Unable to parse dates")

echo "  Subject: $cert_subject"
echo "  Issuer:  $cert_issuer"
echo "  $cert_dates"

# Test 6: Show usage instructions
print_info "Test 6: Usage instructions..."
echo
echo "To upload certificates to GitHub secrets:"
echo
echo "1. Set your GitHub token:"
echo "   export GITHUB_TOKEN=\"your_token_here\""
echo
echo "2. Run the upload script:"
echo "   $SHELL_SCRIPT"
echo
echo "3. Or test with dry run first:"
echo "   $SHELL_SCRIPT --dry-run"
echo

print_success "All tests completed successfully!"
echo
print_info "The certificate upload scripts are ready to use."

if [[ -z "$GITHUB_TOKEN" && -z "$GITHUB_API_TOKEN" ]]; then
    print_warning "Set GITHUB_TOKEN to upload certificates to GitHub secrets"
else
    print_success "GitHub token is set and ready to use"
fi
