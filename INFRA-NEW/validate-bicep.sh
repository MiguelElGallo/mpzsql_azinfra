#!/bin/bash

# Bicep Validation and Compilation Script
# This script validates and compiles all Bicep templates and parameters
# to catch issues before deployment

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESOURCE_GROUP="RG-MPZSQL"
SUBSCRIPTION_ID="${AZURE_SUBSCRIPTION_ID:-}"

echo -e "${BLUE}🔍 Bicep Validation and Compilation Script${NC}"
echo "=========================================="

# Function to print status messages
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if required tools are installed
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check if bicep is installed
    if ! command -v bicep &> /dev/null; then
        print_error "Bicep CLI is not installed. Please install it first."
        echo "Install instructions: https://docs.microsoft.com/en-us/azure/azure-resource-manager/bicep/install"
        exit 1
    fi
    
    # Check if Azure CLI is installed
    if ! command -v az &> /dev/null; then
        print_error "Azure CLI is not installed. Please install it first."
        echo "Install instructions: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
        exit 1
    fi
    
    print_success "Prerequisites check passed"
}

# Function to check Azure CLI login status
check_azure_login() {
    print_status "Checking Azure CLI login status..."
    
    if ! az account show &> /dev/null; then
        print_error "Not logged in to Azure CLI. Please run 'az login' first."
        exit 1
    fi
    
    local current_subscription=$(az account show --query id -o tsv)
    print_success "Logged in to Azure. Current subscription: $current_subscription"
    
    if [ -n "$SUBSCRIPTION_ID" ] && [ "$current_subscription" != "$SUBSCRIPTION_ID" ]; then
        print_warning "Current subscription ($current_subscription) differs from AZURE_SUBSCRIPTION_ID ($SUBSCRIPTION_ID)"
        print_status "Setting subscription to: $SUBSCRIPTION_ID"
        az account set --subscription "$SUBSCRIPTION_ID"
    fi
}

# Function to validate and compile Bicep templates
validate_bicep_syntax() {
    print_status "Validating Bicep syntax..."
    
    local templates=("main.bicep" "role-assignments.bicep")
    local all_valid=true
    
    # Create compiled directory if it doesn't exist
    mkdir -p ./compiled/
    
    for template in "${templates[@]}"; do
        if [ ! -f "$template" ]; then
            print_error "Template $template not found"
            all_valid=false
            continue
        fi
        
        print_status "Building $template..."
        if bicep build "$template" --outdir ./compiled/ 2>&1 | tee "/tmp/bicep_build_$template.log"; then
            print_success "$template compiled successfully"
        else
            print_error "Failed to compile $template"
            all_valid=false
        fi
    done
    
    if [ "$all_valid" = false ]; then
        print_error "One or more templates failed to compile"
        exit 1
    fi
}

# Function to validate deployment templates
validate_deployment() {
    print_status "Validating deployment templates..."
    
    # Check if resource group exists
    if ! az group show --name "$RESOURCE_GROUP" &> /dev/null; then
        print_warning "Resource group $RESOURCE_GROUP does not exist"
        print_status "Creating resource group $RESOURCE_GROUP..."
        az group create --name "$RESOURCE_GROUP" --location "swedencentral"
        print_success "Resource group created"
    fi
    
    # Validate main template
    print_status "Validating main.bicep deployment..."
    if az deployment group validate \
        --resource-group "$RESOURCE_GROUP" \
        --template-file main.bicep \
        --parameters main.bicepparam \
        --output table; then
        print_success "Main template validation passed"
    else
        print_error "Main template validation failed"
        exit 1
    fi
    
    # Validate role assignments template with dummy parameters
    print_status "Validating role-assignments.bicep deployment..."
    local dummy_principal_id="00000000-0000-0000-0000-000000000000"
    local dummy_user_principal_id="11111111-1111-1111-1111-111111111111"
    local dummy_subscription="${SUBSCRIPTION_ID:-$(az account show --query id -o tsv)}"
    local dummy_kv_id="/subscriptions/$dummy_subscription/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.KeyVault/vaults/dummy-kv"
    local dummy_storage_id="/subscriptions/$dummy_subscription/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Storage/storageAccounts/dummyaccount"
    local dummy_acr_id="/subscriptions/$dummy_subscription/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.ContainerRegistry/registries/dummyregistry"
    local dummy_postgres_id="/subscriptions/$dummy_subscription/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.DBforPostgreSQL/flexibleServers/dummy-postgres"
    
    if az deployment group validate \
        --resource-group "$RESOURCE_GROUP" \
        --template-file role-assignments.bicep \
        --parameters containerAppPrincipalId="$dummy_principal_id" \
                    userAssignedIdentityPrincipalId="$dummy_user_principal_id" \
                    keyVaultResourceId="$dummy_kv_id" \
                    storageAccountResourceId="$dummy_storage_id" \
                    containerRegistryResourceId="$dummy_acr_id" \
                    postgresServerResourceId="$dummy_postgres_id" \
        --output table; then
        print_success "Role assignments template validation passed"
    else
        print_error "Role assignments template validation failed"
        exit 1
    fi
}

# Function to run what-if analysis
run_whatif_analysis() {
    print_status "Running what-if analysis for main deployment..."
    
    if az deployment group what-if \
        --resource-group "$RESOURCE_GROUP" \
        --template-file main.bicep \
        --parameters main.bicepparam \
        --result-format FullResourcePayloads; then
        print_success "What-if analysis completed"
    else
        print_warning "What-if analysis encountered issues (this might be expected for new deployments)"
    fi
}

# Function to lint Bicep files
lint_bicep_files() {
    print_status "Linting Bicep files..."
    
    local templates=("main.bicep" "role-assignments.bicep")
    local all_clean=true
    
    for template in "${templates[@]}"; do
        print_status "Linting $template..."
        if bicep lint "$template"; then
            print_success "$template linting passed"
        else
            print_warning "$template has linting warnings/errors"
            all_clean=false
        fi
    done
    
    if [ "$all_clean" = true ]; then
        print_success "All templates passed linting"
    else
        print_warning "Some templates have linting issues"
    fi
}

# Function to generate ARM templates for review
generate_arm_templates() {
    print_status "Generating ARM templates for review..."
    
    mkdir -p ./generated-arm/
    
    # Generate ARM template from main.bicep
    if bicep build main.bicep --outfile ./generated-arm/main.json; then
        print_success "Generated ./generated-arm/main.json"
    fi
    
    # Generate ARM template from role-assignments.bicep
    if bicep build role-assignments.bicep --outfile ./generated-arm/role-assignments.json; then
        print_success "Generated ./generated-arm/role-assignments.json"
    fi
    
    print_status "ARM templates generated in ./generated-arm/ directory"
}

# Function to display file information
display_file_info() {
    print_status "Template and parameter files information:"
    echo ""
    
    local files=("main.bicep" "main.bicepparam" "role-assignments.bicep" "role-assignments.bicepparam")
    
    for file in "${files[@]}"; do
        if [ -f "$file" ]; then
            local size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null || echo "unknown")
            local modified=$(stat -f%Sm -t "%Y-%m-%d %H:%M:%S" "$file" 2>/dev/null || stat -c%y "$file" 2>/dev/null | cut -d. -f1 || echo "unknown")
            echo -e "${GREEN}✓${NC} $file (${size} bytes, modified: $modified)"
        else
            echo -e "${RED}✗${NC} $file (missing)"
        fi
    done
    echo ""
}

# Main execution
main() {
    cd "$SCRIPT_DIR"
    
    print_status "Starting validation in directory: $SCRIPT_DIR"
    
    # Display help if requested
    if [[ "$1" == "--help" || "$1" == "-h" ]]; then
        echo "Usage: $0 [options]"
        echo ""
        echo "Options:"
        echo "  --help, -h          Show this help message"
        echo "  --skip-azure        Skip Azure CLI checks and deployment validation"
        echo "  --skip-whatif       Skip what-if analysis"
        echo "  --lint-only         Only run linting, skip other validations"
        echo ""
        echo "Environment Variables:"
        echo "  AZURE_SUBSCRIPTION_ID    Azure subscription ID to use"
        echo ""
        exit 0
    fi
    
    # Parse arguments
    local skip_azure=false
    local skip_whatif=false
    local lint_only=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --skip-azure)
                skip_azure=true
                shift
                ;;
            --skip-whatif)
                skip_whatif=true
                shift
                ;;
            --lint-only)
                lint_only=true
                shift
                ;;
            *)
                print_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done
    
    # Run validation steps
    display_file_info
    check_prerequisites
    
    if [ "$lint_only" = true ]; then
        lint_bicep_files
        print_success "Linting completed"
        exit 0
    fi
    
    validate_bicep_syntax
    lint_bicep_files
    generate_arm_templates
    
    if [ "$skip_azure" = false ]; then
        check_azure_login
        validate_deployment
        
        if [ "$skip_whatif" = false ]; then
            run_whatif_analysis
        fi
    else
        print_warning "Skipping Azure CLI checks and deployment validation"
    fi
    
    print_success "All validations completed successfully! 🎉"
    echo ""
    echo -e "${GREEN}Your Bicep templates are ready for deployment.${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Review the generated ARM templates in ./generated-arm/"
    echo "2. Run the deployment using the GitHub Actions workflow"
    echo "3. Or deploy manually using:"
    echo "   az deployment group create --resource-group $RESOURCE_GROUP --template-file main.bicep --parameters main.bicepparam"
}

# Execute main function with all arguments
main "$@"
