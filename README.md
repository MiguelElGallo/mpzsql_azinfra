# MPZSQL  Infrastructure & Deployment Guide

Comprehensive guide for deploying and operating the MPZSQL cloud-native data lake on Azure Container Apps using Bicep + GitHub Actions. During the image build workflow the step at lines 132–137 of `.github/workflows/build-and-push-image.yml` automatically fetches the latest MPZSQL server source from the upstream repository (https://github.com/miguelElGallo/mpzsql) via `scripts/download-mpzsql.sh`, ensuring each build incorporates the newest server version without manual syncing.

## Overview

MPZSQL combines Ducklake/DuckDB analytics with Azure-managed services:
- High-performance embedded DuckDB execution engine
- PostgreSQL Flexible Server for catalog / metadata
- Azure Blob Storage for persistent data (`data` container)
- Azure Container Apps for elastic container runtime
- Azure Container Registry (ACR) for image storage
- Optional TLS via Let's Encrypt (mounted certs)
- Structured logging / telemetry via Pydantic Logfire

## Quick Start

1. Fork or clone this repository.
2. Configure Required GitHub Secrets (see section below).
3. Commit or edit `INFRA-NEW/main.bicepparam` with desired parameters (admin username/password etc.).
4. Trigger infrastructure deployment (push changes touching `INFRA-NEW/**` to `main` or manual dispatch of `Deploy New Infrastructure with Bicep`).
5. After infra completes, run the image build workflow (`build-and-push-image.yml`).
6. Deploy / update the running app (`deploy-to-container-app.yml`).

## Required GitHub Secrets

Set these repository secrets before running infrastructure or deployment workflows.

### Core Azure Credentials (all infra & build workflows)
- `AZURE_CLIENT_ID` – Federated workload identity / Service Principal client ID
- `AZURE_TENANT_ID` – Azure AD tenant ID
- `AZURE_SUBSCRIPTION_ID` – Azure subscription ID
More information can be found in this [guide](https://learn.microsoft.com/en-us/azure/developer/github/connect-from-azure-openid-connect). 

### GitHub Administration
- `ADMIN_PAT` – Fine‑scoped PAT used by infra deploy workflow to write repository secrets (repo:actions:write). Avoid classic tokens with broad scopes.
Go to https://github.com/settings/personal-access-tokens/new for creating the PAT (Personal Access token)

### Database (populated/consumed after infra deploy)
Secrets written automatically by the infra deployment workflow (`workflows-deploy-new-infra.yml`) when it runs successfully:
- `POSTGRESQL_SERVER` – FQDN of the provisioned PostgreSQL Flexible Server
- `POSTGRESQL_USER` – Admin username (extracted from `INFRA-NEW/main.bicepparam`)
- `POSTGRESQL_PASSWORD` – Admin password (extracted from `INFRA-NEW/main.bicepparam`)
- `POSTGRESQL_PORT` – Usually `5432`
- `POSTGRESQL_CATALOGDB` – Catalog database name (currently `ducklake_catalog`)

Consumed by build / container app deploy workflows:
- `.github/workflows/deploy-to-container-app.yml`
- `.github/workflows/build-and-push-image.yml`

### Storage
- `AZURE_STORAGE_ACCOUNT` – Name of the deployed storage account (auto-set post deploy)
- `AZURE_STORAGE_CONTAINER` – Data container name (currently `data`, auto-set)

### Application / Observability
- `LOGFIRE_WRITE_TOKEN` – Optional; used for logging/telemetry if present.

### TLS Certificates (optional but enables HTTPS / cert mounting)
Used in build & runtime workflows if supplied:
- `LETSENCRYPT_CERT` – Full certificate (PEM)
- `LETSENCRYPT_KEY` – Private key (PEM)
See `UPLOAD_CERTIFICATES.md` & `scripts/CERTIFICATE_UPLOAD.md` for helper script usage.

### Summary Classification
| Secret | Source | Auto Updated | Required to Start Infra | Consumed By |
|--------|--------|--------------|-------------------------|-------------|
| AZURE_CLIENT_ID | Manual | ❌ | ✅ | All workflows |
| AZURE_TENANT_ID | Manual | ❌ | ✅ | All workflows |
| AZURE_SUBSCRIPTION_ID | Manual | ❌ | ✅ | All workflows |
| ADMIN_PAT | Manual | ❌ | ✅ (for secret write-back) | Infra deploy |
| POSTGRESQL_SERVER | Infra output | ✅ | ❌ | Build / Deploy |
| POSTGRESQL_USER | Param parse | ✅ | ❌ | Build / Deploy |
| POSTGRESQL_PASSWORD | Param parse | ✅ | ❌ | Build / Deploy |
| POSTGRESQL_PORT | Static / output | ✅ | ❌ | Build / Deploy |
| POSTGRESQL_CATALOGDB | Static / output | ✅ | ❌ | Build / Deploy |
| AZURE_STORAGE_ACCOUNT | Infra output | ✅ | ❌ | Build / Deploy |
| AZURE_STORAGE_CONTAINER | Static | ✅ | ❌ | Build / Deploy |
| LOGFIRE_WRITE_TOKEN | Manual | ❌ | Optional | Build / Deploy |
| LETSENCRYPT_CERT | Manual | ❌ | Optional | Build / Deploy |
| LETSENCRYPT_KEY | Manual | ❌ | Optional | Build / Deploy |

## Secret Lifecycle
1. You manually set the core Azure creds + `ADMIN_PAT`.
2. Run infra deploy workflow (push to `main` touching `INFRA-NEW/**` or manual dispatch) → Bicep deployment → workflow extracts outputs → writes app/storage/postgres secrets back via GitHub CLI.
3. Subsequent build & deploy workflows read those populated secrets.

If you rotate parameters (e.g. change admin password) in `INFRA-NEW/main.bicepparam`, re-run the deploy workflow to refresh secrets.

## Minimal Mandatory Set
At absolute minimum to deploy infrastructure successfully:
- `AZURE_CLIENT_ID`
- `AZURE_TENANT_ID`
- `AZURE_SUBSCRIPTION_ID`
- `ADMIN_PAT`
- Valid `postgresAdminUsername` and `postgresAdminPassword` entries inside `INFRA-NEW/main.bicepparam`

## Optional / Conditional
- `LOGFIRE_WRITE_TOKEN` only if using Logfire.
- `LETSENCRYPT_CERT`, `LETSENCRYPT_KEY` only if you need cert injection. Workflows skip gracefully if absent.

## How Secrets Are Parsed
`workflows-deploy-new-infra.yml` greps `INFRA-NEW/main.bicepparam` for:
```
param postgresAdminUsername = '...'
param postgresAdminPassword = '...'
```
Ensure single quotes and the parameter names remain unchanged or update the workflow accordingly.

## Auditing Current Usage
Search pattern used: `secrets.[A-Z0-9_]+` across `.github/workflows/*.yml` produced references to:
```
AZURE_CLIENT_ID, AZURE_TENANT_ID, AZURE_SUBSCRIPTION_ID,
ADMIN_PAT,
POSTGRESQL_SERVER, POSTGRESQL_USER, POSTGRESQL_PORT, POSTGRESQL_PASSWORD, POSTGRESQL_CATALOGDB,
AZURE_STORAGE_ACCOUNT, AZURE_STORAGE_CONTAINER,
LETSENCRYPT_CERT, LETSENCRYPT_KEY,
LOGFIRE_WRITE_TOKEN
```

## Workflows Overview

### 1. Infrastructure Deployment (`workflows-deploy-new-infra.yml`)
Triggered by push to `main` affecting `INFRA-NEW/**` or manual dispatch.
Uses: `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`, `ADMIN_PAT`.
Performs: Provider registration (reusable wf), Bicep validation, Bicep deployment, key vault recovery handling, role assignments, secret write-back.

### 2. Build and Push Docker Image (`build-and-push-image.yml`)
Uses Azure auth + Postgres + Storage + optional TLS + logging secrets. Builds image, optionally injects certs, pushes to ACR, may prune old images.

### 3. Deploy to Container App (`deploy-to-container-app.yml`)
Deploys latest image to ACA, configures env vars, sets identity & registry auth, applies TLS cert mounting and logging token if present.

### 4. What-If Infra (`workflows-bicep-whatif-new-infra.yml`)
Performs Bicep What-If (change preview) using same core Azure secrets (no secret write-back).

### 5. Provider Registration (`register-azure-providers.yml`)
Reusable job to ensure required Azure resource providers are registered (core Azure secrets only).

## Setting Up Secrets (Consolidated)

### Automatically Updated by Infra Deployment
`AZURE_STORAGE_ACCOUNT`, `AZURE_STORAGE_CONTAINER`, `POSTGRESQL_CATALOGDB`, `POSTGRESQL_PASSWORD`, `POSTGRESQL_USER`, `POSTGRESQL_PORT`, `POSTGRESQL_SERVER`.

### Must Be Set Manually First
`AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`, `ADMIN_PAT`, optionally `LETSENCRYPT_CERT`, `LETSENCRYPT_KEY`, `LOGFIRE_WRITE_TOKEN`.

### Procedure
1. Repository → Settings → Secrets and variables → Actions → New repository secret.
2. Add mandatory secrets.
3. Run infra workflow → observe secret population in subsequent runs.

## Certificate Upload Helper
Use helper scripts for safe certificate upload:
```bash
./scripts/run_cert_upload.sh --dry-run  # Preview
./scripts/run_cert_upload.sh            # Upload cert + key secrets
```
Details: `UPLOAD_CERTIFICATES.md`, `scripts/CERTIFICATE_UPLOAD.md`.

## Project Structure
- `INFRA-NEW/` – Bicep infrastructure (main + role assignments + validation scripts)
- `.github/workflows/` – CI/CD workflows (infra, build, deploy, what-if, providers)
- `scripts/` – Helper scripts (setup, cert upload, secret setting, container run)
- `Dockerfile` – Multi-stage UV-based Python build
- `GITHUB_SECRETS.md` – Additional secret explanations
- `UPLOAD_CERTIFICATES.md` / `scripts/CERTIFICATE_UPLOAD.md` – TLS cert management
- `batch_load/` – ETL utilities (Snowflake → MPZSQL)

## Adding a New Secret
1. Reference it in a workflow: `${{ secrets.MY_NEW_SECRET }}`.
2. (Optional auto-population) Extend the "Update GitHub Secrets" step in `workflows-deploy-new-infra.yml`.
3. Document here under an appropriate category.

## Security Notes
- Prefer OIDC + federated credentials for Azure (already used). Avoid storing client secrets.
- Keep `ADMIN_PAT` least-privileged (only what is required to set secrets/workflows). Consider GitHub App for future expansion.
- Restrict repository & environment access; secrets include DB admin credentials.
- Rotate credentials periodically and re-run infra deploy to refresh.

## Troubleshooting
| Issue | Cause | Fix |
|-------|-------|-----|
| Infra deploy fails at secret update step | Missing `ADMIN_PAT` or insufficient scopes | Recreate PAT with `repo` + `workflow` scopes and set secret |
| Build workflow missing Postgres vars | Infra deploy not yet run | Manually dispatch infra deploy workflow |
| Password/username not refreshed | Edited param file but no redeploy | Re-run infra deploy workflow |
| Certs not found in image build | Optional cert secrets absent | Set `LETSENCRYPT_CERT` / `LETSENCRYPT_KEY` or ignore |
| ACR not found in deploy step | Infra not deployed or different RG | Ensure infra completed & RG matches `AZURE_RESOURCE_GROUP` |
| Container App not updating | Old image cached | Force new image tag & rerun build + deploy |

### Additional Common Issues
- Azure auth failures: Validate federated credential mapping and all three Azure ID secrets.
- Secret parsing failure (Postgres creds): Ensure parameter lines exactly match expected pattern (single quotes, param names unchanged).

## Getting Help
- Review GitHub Action run logs for failing step output.
- Check `INFRA-NEW/validate-bicep.sh` locally with `--skip-whatif` to reproduce validation errors.
- Open an issue with failing workflow URL and summary.

## Contributing
1. Fork repository & create feature branch.
2. Make changes + add/adjust tests or validation where applicable.
3. Run infra validation script if editing Bicep.
4. Submit PR; include summary of secret / infra changes if any.

## License

MIT

# MPZSQL

A cloud-native data lake solution built with DuckDB/Ducklake, deployed on Azure Container Apps.



## Quick Start

### Prerequisites

- Azure subscription with appropriate permissions
- GitHub repository with Actions enabled
- Required GitHub secrets (see below)

### Setup

1. **Fork or clone this repository**
2. **Configure GitHub secrets** (see detailed list below)
3. **Deploy infrastructure** using the GitHub Actions workflow
4. **Build and deploy** the application

## Required GitHub Secrets

The following GitHub secrets must be configured in your repository settings for the workflows to function properly:

### 🔑 Azure Authentication (Required for all workflows)

| Secret | Description | Used in Workflows |
|--------|-------------|-------------------|
| `AZURE_CLIENT_ID` | Azure service principal client ID | All workflows |
| `AZURE_TENANT_ID` | Azure tenant ID | All workflows |
| `AZURE_SUBSCRIPTION_ID` | Azure subscription ID | All workflows |

### 🗄️ Database Configuration

| Secret | Description | Auto-Updated | Used in Workflows |
|--------|-------------|--------------|-------------------|
| `POSTGRESQL_SERVER` | PostgreSQL server hostname/FQDN | ✅ Yes | Build, Deploy |
| `POSTGRESQL_USER` | PostgreSQL admin username | ✅ Yes | Build, Deploy |
| `POSTGRESQL_PASSWORD` | PostgreSQL admin password | ✅ Yes | Build, Deploy |
| `POSTGRESQL_PORT` | PostgreSQL port (default: 5432) | ✅ Yes | Build, Deploy |
| `POSTGRESQL_CATALOGDB` | PostgreSQL database name for catalog | ✅ Yes | Build, Deploy |

### 💾 Storage Configuration

| Secret | Description | Auto-Updated | Used in Workflows |
|--------|-------------|--------------|-------------------|
| `AZURE_STORAGE_ACCOUNT` | Azure Storage account name | ✅ Yes | Build, Deploy |
| `AZURE_STORAGE_CONTAINER` | Azure Storage container name (default: data) | ✅ Yes | Build, Deploy |

### 🔐 TLS Certificates (Optional)

| Secret | Description | Required | Used in Workflows |
|--------|-------------|----------|-------------------|
| `LETSENCRYPT_CERT` | Let's Encrypt certificate content | Optional | Build, Deploy |
| `LETSENCRYPT_KEY` | Let's Encrypt private key content | Optional | Build, Deploy |

### 📊 Logging & Monitoring

| Secret | Description | Required | Used in Workflows |
|--------|-------------|----------|-------------------|
| `LOGFIRE_WRITE_TOKEN` | Pydantic Logfire write token for logging | Optional | Build, Deploy |

### 🤖 GitHub Automation

| Secret | Description | Required | Used in Workflows |
|--------|-------------|----------|-------------------|
| `ADMIN_PAT` | GitHub Personal Access Token with repo access | Required for infra | Infrastructure |

## Workflows Overview

### 1. Infrastructure Deployment (`workflows-deploy-new-infra.yml`)

**Triggered by:** Push to `main` branch with changes to `INFRA-NEW/**` or manual dispatch

**Secrets used:**
- `AZURE_CLIENT_ID`
- `AZURE_TENANT_ID` 
- `AZURE_SUBSCRIPTION_ID`
- `ADMIN_PAT`

**What it does:**
- Deploys Azure infrastructure using Bicep templates
- Creates Azure Container Registry, Container Apps, PostgreSQL, Storage Account
- Automatically updates GitHub secrets with deployed resource information
- Configures role assignments and permissions

### 2. Build and Push Docker Image (`build-and-push-image.yml`)

**Triggered by:** Manual dispatch or called by other workflows

**Secrets used:**
- `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID` (Azure auth)
- `POSTGRESQL_SERVER`, `POSTGRESQL_USER`, `POSTGRESQL_PORT`, `POSTGRESQL_PASSWORD`, `POSTGRESQL_CATALOGDB` (Database)
- `AZURE_STORAGE_ACCOUNT`, `AZURE_STORAGE_CONTAINER` (Storage)
- `LETSENCRYPT_CERT`, `LETSENCRYPT_KEY` (Optional TLS)
- `LOGFIRE_WRITE_TOKEN` (Optional logging)

**What it does:**
- Builds Docker image with application and dependencies
- Configures TLS certificates if provided
- Pushes image to Azure Container Registry
- Cleans up old images to save storage

### 3. Deploy to Container App (`deploy-to-container-app.yml`)

**Triggered by:** Manual dispatch or called by other workflows

**Secrets used:**
- `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID` (Azure auth)
- `POSTGRESQL_SERVER`, `POSTGRESQL_USER`, `POSTGRESQL_PORT`, `POSTGRESQL_PASSWORD`, `POSTGRESQL_CATALOGDB` (Database)
- `AZURE_STORAGE_ACCOUNT`, `AZURE_STORAGE_CONTAINER` (Storage)
- `LETSENCRYPT_CERT`, `LETSENCRYPT_KEY` (TLS)
- `LOGFIRE_WRITE_TOKEN` (Logging)

**What it does:**
- Deploys container image to Azure Container Apps
- Configures environment variables from secrets
- Sets up managed identity and registry authentication
- Updates the running application

## Setting Up Secrets

### Automatically Updated Secrets

The following secrets are automatically set by the infrastructure deployment workflow and **do not need manual configuration**:

- ✅ `AZURE_STORAGE_ACCOUNT`
- ✅ `AZURE_STORAGE_CONTAINER` 
- ✅ `POSTGRESQL_CATALOGDB`
- ✅ `POSTGRESQL_PASSWORD`
- ✅ `POSTGRESQL_USER`
- ✅ `POSTGRESQL_PORT`
- ✅ `POSTGRESQL_SERVER`

### Manually Required Secrets

You **must** configure these secrets manually in GitHub repository settings:

1. **Azure Service Principal** (required):
   - `AZURE_CLIENT_ID`
   - `AZURE_TENANT_ID`
   - `AZURE_SUBSCRIPTION_ID`

2. **GitHub Token** (required for infrastructure deployment):
   - `ADMIN_PAT` - Personal Access Token with `repo` scope

3. **Optional but recommended**:
   - `LETSENCRYPT_CERT` - For TLS encryption
   - `LETSENCRYPT_KEY` - For TLS encryption  
   - `LOGFIRE_WRITE_TOKEN` - For application logging

### Setting Secrets in GitHub

1. Go to your repository on GitHub
2. Click **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**
4. Add each secret with its name and value

## Certificate Upload Helper

For TLS certificates, you can use the included upload helper:

```bash
# See detailed instructions
cat UPLOAD_CERTIFICATES.md

# Upload certificates using VS Code tasks or terminal
./scripts/run_cert_upload.sh --dry-run  # Test first
./scripts/run_cert_upload.sh            # Upload for real
```

## Project Structure

- `INFRA-NEW/` - Azure Bicep infrastructure templates
- `.github/workflows/` - GitHub Actions workflows
- `scripts/` - Helper scripts for deployment and setup
- `Dockerfile` - Container configuration
- `GITHUB_SECRETS.md` - Detailed secrets documentation
- `UPLOAD_CERTIFICATES.md` - Certificate upload instructions

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test with the workflows
5. Submit a pull request

## Troubleshooting

### Common Issues

1. **"Azure Container Registry not found"**
   - Ensure infrastructure deployment completed successfully
   - Check that the registry has the correct tags

2. **"Container App not found"**
   - Run infrastructure deployment workflow first
   - Verify resource group name matches configuration

3. **Authentication failures**
   - Verify Azure service principal secrets are correct
   - Check that the service principal has appropriate permissions

### Getting Help

- Check existing issues in the repository
- Review workflow run logs for detailed error messages
- Consult the detailed documentation in `GITHUB_SECRETS.md`

## License

[Add your license information here]
