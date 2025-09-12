# MPZSQL Infrastructure

This folder contains the Bicep templates for deploying the MPZSQL infrastructure using Azure Verified Modules (AVM).

## 📁 Files in this directory

- `main.bicep` - Main Bicep template with all Azure resources
- `main.bicepparam` - Parameters file for the main template
- `role-assignments.bicep` - Role assignments template (deployed after main infrastructure)
- `role-assignments.bicepparam` - Parameters file for role assignments
- `validate-bicep.sh` - **Comprehensive validation script** (recommended for testing)
- `deploy.sh` - Interactive deployment script
- `test-template.sh` - Template validation script
- `CHANGES_SUMMARY.md` - Documentation of recent infrastructure changes
- `README.md` - This documentation

## 🏗️ Services Deployed

- **PostgreSQL Flexible Server**: Smallest/cheapest tier (Standard_B1ms), connected to VNET with mixed authentication
- **Key Vault**: Connected to VNET with RBAC authorization and private endpoint
- **Azure Container App**: With **system-assigned managed identity**, TCP ingress, connected to VNET
- **Azure Storage Account**: With Hierarchical Namespace enabled for Data Lake functionality
- **Azure Container Registry**: Basic tier for container images
- **Virtual Network**: With dedicated subnets for different services
- **Private DNS Zone**: For private endpoint communication
- **Log Analytics Workspace**: For Container Apps monitoring

## 🏛️ Architecture

The infrastructure follows these principles:
- All services are connected to a Virtual Network for security
- **System-assigned managed identity** is used for authentication between services
- Private endpoints are used where possible
- RBAC is configured for least-privilege access
- Network access is restricted to the VNET
- **PostgreSQL administrator access** is granted to the Container App



## 🔍 Validation

### Comprehensive Validation (Recommended)

```bash
# Run the comprehensive validation script
./validate-bicep.sh

# Available options:
./validate-bicep.sh --help           # Show help
./validate-bicep.sh --skip-azure     # Skip Azure CLI checks
./validate-bicep.sh --skip-whatif    # Skip what-if analysis
./validate-bicep.sh --lint-only      # Only run linting
```

### What-if Analysis

```bash
# Preview changes before deployment
az deployment group what-if \
  --resource-group RG-MPZSQL \
  --template-file main.bicep \
  --parameters main.bicepparam
```

### Template Validation

```bash
# Run the basic validation script
./test-template.sh
```

## 🔒 Security Features

- **Network Isolation**: All services are connected to a dedicated VNET
- **System-Assigned Managed Identity**: Used for inter-service authentication (more secure than user-assigned)
- **RBAC Permissions**: Assigned with minimal required access:
  - Key Vault Secrets Officer
  - Storage Blob Data Contributor
  - ACR Pull
  - **PostgreSQL Administrator** (Azure AD authentication)
- **Private Endpoints**: For Key Vault connectivity
- **Private DNS**: For internal name resolution
- **Two-Phase Deployment**: Avoids circular dependencies in role assignments

## ⚙️ Customization

Update the `main.bicepparam` file to customize:
- **Location**: Azure region for deployment
- **Environment name**: dev, staging, prod
- **Network ranges**: VNET and subnet address spaces
- **PostgreSQL credentials**: Admin username and password (use Key Vault in production)

## 📊 Monitoring

The deployment includes:
- Log Analytics workspace for Container Apps observability
- Built-in monitoring capabilities for all services
- Resource tagging for cost management and governance

## 🔧 Prerequisites

1. **Azure CLI** installed and logged in
2. **Bicep CLI** installed (`az bicep install` or manual installation)
3. **Appropriate permissions** on the target resource group
4. **Resource Group**: RG-MPZSQL must exist or script will create it
5. **Subscription access** for role assignments and managed identity operations

## 📝 Notes

- **System-Assigned Managed Identity**: More secure than user-assigned, lifecycle tied to Container App
- **Two-Phase Deployment**: Main infrastructure first, then role assignments to avoid circular dependencies
- **PostgreSQL Access**: Container App has administrator privileges via Azure AD authentication
- The Container App uses a placeholder image that should be replaced with your actual application
- PostgreSQL password is currently in the parameters file - move to Key Vault for production
- All resources are tagged with environment and application for better management
- The template uses Azure Verified Modules (AVM) for standardized deployments
- **Validation Script**: Use `./validate-bicep.sh` to catch issues before deployment
