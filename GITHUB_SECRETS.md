# GitHub Secrets Summary

This document lists all the GitHub secrets required for the project workflows.

## Required GitHub Secrets

### Azure Authentication (Standard Azure Secrets)
- `AZURE_CLIENT_ID` - Azure service principal client ID
- `AZURE_TENANT_ID` - Azure tenant ID  
- `AZURE_SUBSCRIPTION_ID` - Azure subscription ID

### Application Environment Variables (Updated)
- `AZURE_STORAGE_ACCOUNT` - Azure storage account name
- `AZURE_STORAGE_CONTAINER` - Azure storage container name
- `LETSENCRYPT_CERT` - LetsEncrypt certificate content
- `LETSENCRYPT_KEY` - LetsEncrypt private key content
- `LOGFIRE_WRITE_TOKEN` - Pydantic Logfire token for logging
- `POSTGRESQL_CATALOGDB` - PostgreSQL database name
- `POSTGRESQL_PASSWORD` - PostgreSQL password
- `POSTGRESQL_PORT` - PostgreSQL port (usually 5432)
- `POSTGRESQL_SERVER` - PostgreSQL server hostname
- `POSTGRESQL_USER` - PostgreSQL username

## Files Updated

### GitHub Workflows
- ✅ `.github/workflows/deploy-to-container-app.yml` - Updated environment variables
- ✅ `.github/workflows/build-and-push-image.yml` - Updated environment variables
- ✅ Other workflow files - Only use Azure authentication secrets (correct)

### Docker & Documentation
- ✅ `Dockerfile` - Updated environment variable definitions
- ✅ `scripts/README.md` - Updated documentation and examples

## Removed/Deprecated Secrets
The following old secrets are no longer used:
- `PGHOST` → replaced by `POSTGRESQL_SERVER`
- `PGUSER` → replaced by `POSTGRESQL_USER` 
- `PGPORT` → replaced by `POSTGRESQL_PORT`
- `PGDATABASE` → replaced by `POSTGRESQL_CATALOGDB`
- `PGPASSWORD` → replaced by `POSTGRESQL_PASSWORD`
- `DATABASE` → no longer used (DuckDB local file)

## Next Steps
1. Ensure all 12 secrets listed above are configured in GitHub repository settings
2. Test workflows to verify they work with the new secret names
3. Remove any old secrets from GitHub repository settings if they exist

## Automatically Updated Secrets

The following secrets are automatically updated by the infrastructure deployment workflow:
- ✅ `AZURE_STORAGE_ACCOUNT` - Set from deployed storage account name
- ✅ `AZURE_STORAGE_CONTAINER` - Set to "data" (constant)
- ✅ `POSTGRESQL_CATALOGDB` - Set to "ducklake_catalog" (constant)
- ✅ `POSTGRESQL_PASSWORD` - Set from main.bicepparam
- ✅ `POSTGRESQL_USER` - Set from main.bicepparam
- ✅ `POSTGRESQL_PORT` - Set to "5432" (constant)
- ✅ `POSTGRESQL_SERVER` - Set from deployed PostgreSQL server FQDN

## Manually Set Secrets

The following secrets must be set manually in GitHub repository settings:
- 🔧 `AZURE_CLIENT_ID` - Azure service principal client ID
- 🔧 `AZURE_TENANT_ID` - Azure tenant ID  
- 🔧 `AZURE_SUBSCRIPTION_ID` - Azure subscription ID
- 🔧 `ADMIN_PAT` - GitHub Personal Access Token with repo access
- 🔧 `LETSENCRYPT_CERT` - LetsEncrypt certificate content
- 🔧 `LETSENCRYPT_KEY` - LetsEncrypt private key content
- 🔧 `LOGFIRE_WRITE_TOKEN` - Pydantic Logfire token for logging