
# Purpose of this repository

1. Deploy Azure Infrastructure using Bicep , main github actions workflow: .github/workflows/workflows-deploy-new-infra.yml
2. The infrastucture is mainly: 
   - Azure Storage Account
   - Azure Key Vault
   - Azure Container App Service
   - Azure SQL Database
   - VNET
   - Others
The main service is Azure Container App Service, which hosts the the mpzsql server.
3. The Code of the mpzsql server is in the repository: https://github.com/miguelElGallo/mpzsql and the main branch is `main`.
4. The repository for https://github.com/miguelElGallo/mpzsql is the place for the source code of the mpzsql server, and needs to be "downloaded" to this repository to be deployed to the folder app.
5. We need to build a docker image of the mpzsql server and deploy it to the Azure Container App Service. First buoild the docker image and and then test it locally. After that, push the image to the Azure Container Registry and deploy it to the Azure Container App Service.

## GitHub Actions Workflows

### Available Workflows

1. **register-azure-providers.yml** - Reusable workflow to register required Azure providers
2. **build-and-push-image.yml** - Reusable workflow to build and push Docker images ⭐ **NEW**
3. **test-docker-build.yml** - Test workflow for the Docker build process
4. **deploy-example.yml** - Example full deployment pipeline using multiple reusable workflows

### Docker Build and Push Workflow

The `build-and-push-image.yml` workflow provides:
- ✅ Downloads the latest MPZSQL server code
- ✅ Builds Docker image with timestamp tags
- ✅ Pushes to Azure Container Registry
- ✅ Cleans old images (keeps last 2)
- ✅ Reusable design for integration with other workflows

**Usage:**
```yaml
jobs:
  build:
    uses: ./.github/workflows/build-and-push-image.yml
    with:
      environment: 'deploy-env'
      image_tag_prefix: 'prod'
      registry_cleanup: true
    secrets: inherit
```

