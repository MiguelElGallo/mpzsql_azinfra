# GitHub Actions for DuckLake/MPZSQL

This directory contains reusable GitHub Actions workflows for building, pushing, and deploying the MPZSQL application.

## Available Workflows

### 1. Build and Push Docker Image (`build-and-push-image.yml`)

**Purpose**: Reusable workflow that downloads the latest MPZSQL server, builds a Docker image, and pushes it to Azure Container Registry.

**Features**:
- ✅ Downloads latest MPZSQL server from GitHub
- ✅ Builds Docker image with timestamp tags
- ✅ Auto-discovers Azure Container Registry
- ✅ Pushes image to registry
- ✅ Cleans old images (keeps last 2)
- ✅ Comprehensive logging and error handling

**Usage**:
```yaml
jobs:
  build:
    uses: ./.github/workflows/build-and-push-image.yml
    with:
      environment: 'deploy-env'          # Environment for secrets
      image_tag_prefix: 'prod'           # Optional tag prefix
      registry_cleanup: true             # Clean old images
    secrets: inherit
```

**Inputs**:
- `environment` (optional): Environment to use for secrets (default: 'deploy-env')
- `image_tag_prefix` (optional): Prefix for the image tag
- `registry_cleanup` (optional): Whether to clean old images (default: true)

**Outputs**:
- `image_name`: Name of the built image
- `image_tag`: Tag of the built image
- `registry_name`: Name of the Azure Container Registry

**Required Secrets**:
- Azure authentication: `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`
- Application secrets: `PGHOST`, `PGUSER`, `PGPORT`, `PGDATABASE`, `PGPASSWORD`, `DATABASE`, `LOGFIRE_WRITE_TOKEN`, `AZURE_STORAGE_ACCOUNT`, `AZURE_STORAGE_CONTAINER`, `POSTGRESQL_SERVER`, `POSTGRESQL_USER`, `POSTGRESQL_PORT`, `POSTGRESQL_PASSWORD`, `POSTGRESQL_CATALOGDB`

### 2. Deploy to Azure Container App (`deploy-to-container-app.yml`)

**Purpose**: Reusable workflow that deploys the latest Docker image to Azure Container Apps and configures environment variables.

**Features**:
- ✅ Auto-discovers Container App from bicep parameters
- ✅ Sets environment variables from GitHub secrets (NOT as Azure secrets)
- ✅ Updates Container App with latest image from ACR
- ✅ Activates the new deployment
- ✅ Verifies deployment status
- ✅ Comprehensive logging and error handling

**Usage**:
```yaml
jobs:
  deploy:
    uses: ./.github/workflows/deploy-to-container-app.yml
    with:
      environment: 'deploy-env'              # Environment for secrets
      image_name: 'mpzsql'                   # Container image name
      image_tag: '20240724-143022'           # Image tag to deploy
      registry_name: 'mpzsqldevacr7p6gpzzcik3me'  # ACR name
    secrets: inherit
```

**Inputs**:
- `environment` (optional): Environment to use for secrets (default: 'deploy-env')
- `image_name` (optional): Container image name (default: 'mpzsql')
- `image_tag` (required): Container image tag to deploy
- `registry_name` (required): Azure Container Registry name

**Required Secrets**:
- Azure authentication: `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`
- Application environment variables: `PGHOST`, `PGUSER`, `PGPORT`, `PGDATABASE`, `PGPASSWORD`, `DATABASE`, `LOGFIRE_WRITE_TOKEN`, `AZURE_STORAGE_ACCOUNT`, `AZURE_STORAGE_CONTAINER`

### 3. Register Azure Providers (`register-azure-providers.yml`)

**Purpose**: Ensures all required Azure resource providers are registered before deployment.

### 4. Test Docker Build (`test-docker-build.yml`)

**Purpose**: Manual test workflow for the Docker build process.

### 5. Deploy Example (`deploy-example.yml`)

**Purpose**: Complete example showing how to use multiple reusable workflows together for a full CI/CD pipeline.

## How the Registry Discovery Works

The workflow automatically finds your Azure Container Registry using one of these methods:

1. **By Tags**: Looks for registries with tags `environment: dev` and `application: mpzsql`
2. **By Name Pattern**: Falls back to searching for registries with names starting with 'mpzsql' and containing 'acr'

This matches the naming convention from your Bicep template:
```bicep
var containerRegistryName = '${take(replace(resourcePrefix, '-', ''), 8)}acr${take(uniqueString(resourceGroup().id), 12)}'
```

## Environment Variables

All PostgreSQL and application configuration is passed through environment variables during the Docker build. These should be configured as GitHub repository secrets.

## Image Tagging

Images are tagged with timestamps in the format: `YYYYMMDD-HHMMSS`

With optional prefix: `{prefix}-YYYYMMDD-HHMMSS`

## Registry Cleanup

The workflow automatically removes old images, keeping only the 2 most recent ones to save storage space and costs.

## Example Full Pipeline

```yaml
name: Complete Deployment Pipeline

on:
  push:
    branches: [main]

jobs:
  # Register Azure providers first
  register-providers:
    uses: ./.github/workflows/register-azure-providers.yml
    with:
      environment: 'deploy-env'
    secrets: inherit

  # Build and push Docker image
  build-and-push:
    needs: register-providers
    uses: ./.github/workflows/build-and-push-image.yml
    with:
      environment: 'deploy-env'
      image_tag_prefix: 'prod'
      registry_cleanup: true
    secrets: inherit

  # Deploy to Azure Container Apps
  deploy:
    needs: build-and-push
    uses: ./.github/workflows/deploy-to-container-app.yml
    with:
      environment: 'deploy-env'
      image_name: ${{ needs.build-and-push.outputs.image_name }}
      image_tag: ${{ needs.build-and-push.outputs.image_tag }}
      registry_name: ${{ needs.build-and-push.outputs.registry_name }}
    secrets: inherit
```

## Troubleshooting

### Registry Not Found
If the workflow can't find your Azure Container Registry:
1. Ensure your registry has the correct tags: `environment: dev`, `application: mpzsql`
2. Check that the Azure service principal has access to list container registries
3. Verify the resource group and subscription are correct

### Build Failures
If the Docker build fails:
1. Check that all required secrets are configured
2. Verify the MPZSQL repository is accessible
3. Review the Docker build logs for specific errors

### Push Failures
If pushing to the registry fails:
1. Ensure the Azure service principal has `AcrPush` role on the container registry
2. Verify the registry URL is correct
3. Check that the registry allows pushes from your IP/service

### Container App Deployment Failures
If the container app deployment fails with ACR authentication errors:
1. Ensure the deployment workflow specifies the correct container name (defined in your Bicep template)
2. Verify that the Container App's managed identity has `AcrPull` role on the registry
3. Check that the container name in the deployment matches the infrastructure definition

## Scripts Used

The workflow leverages existing scripts:
- `scripts/download-mpzsql.sh` - Downloads the latest MPZSQL server
- `scripts/build-image.sh` - Builds the Docker image

These scripts are battle-tested and work both locally and in CI/CD environments.