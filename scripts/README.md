# MPZSQL Container Scripts

This directory contains scripts to download, build, and run the MPZSQL application in a Docker container. These scripts are designed to be flexible and reusable for both local development and CI/CD environments.

## Quick Start

For a complete setup, run:
```bash
./scripts/setup.sh --auto-run
```

This will:
1. Download the MPZSQL repository
2. Build the Docker image
3. Start the container with all environment variables

### 5. Certificate Management Scripts

#### `upload_certs.sh` - Upload SSL Certificates to GitHub Secrets
Uploads Let's Encrypt certificate files as GitHub repository secrets for use in CI/CD.

```bash
# Upload certificates
./scripts/upload_certs.sh

# Dry run (show what would be uploaded)
./scripts/upload_certs.sh --dry-run

# List current secrets
./scripts/upload_certs.sh --list
```

**Prerequisites:**
- GitHub Personal Access Token with `repo` scope
- Certificate files in `secrets/certs/`:
  - `letsencrypt-server.crt`
  - `letsencrypt-server.key`

**Environment Variables:**
- `GITHUB_TOKEN` or `GITHUB_API_TOKEN` - GitHub Personal Access Token

#### `set_cert_secrets.py` - Python Backend for Certificate Upload
The Python script that handles GitHub API interactions for certificate upload.

```bash
# Direct usage
python3 scripts/set_cert_secrets.py

# Custom certificate directory
python3 scripts/set_cert_secrets.py --cert-dir /path/to/certs

# Use specific token
python3 scripts/set_cert_secrets.py --token ghp_your_token_here
```

#### `test_cert_upload.sh` - Test Certificate Upload Setup
Validates that certificate files exist and scripts are properly configured.

```bash
./scripts/test_cert_upload.sh
```

**Created Secrets:**
- `LETSENCRYPT_CERT` - SSL certificate content
- `LETSENCRYPT_KEY` - Private key content

For detailed documentation, see [`CERTIFICATE_UPLOAD.md`](CERTIFICATE_UPLOAD.md).

## Scripts Overview

### 1. `setup.sh` - Complete Setup Script
The main orchestration script that handles the entire setup process.

```bash
# Full setup with automatic container start
./scripts/setup.sh --auto-run

# Clean build (no cache) and run
./scripts/setup.sh --clean-build --auto-run

# Only download repository
./scripts/setup.sh --download-only

# Only build Docker image
./scripts/setup.sh --build-only
```

### 2. `download-mpzsql.sh` - Repository Download
Downloads/clones the MPZSQL repository from GitHub.

```bash
# Basic download
./scripts/download-mpzsql.sh

# Force clean download
FORCE_CLEAN=true ./scripts/download-mpzsql.sh

# Custom repository URL
MPZSQL_REPO_URL=https://github.com/custom/mpzsql.git ./scripts/download-mpzsql.sh
```

**Environment Variables:**
- `MPZSQL_REPO_URL`: Repository URL (default: https://github.com/MiguelElGallo/mpzsql.git)
- `MPZSQL_BRANCH`: Branch to clone (default: main)
- `FORCE_CLEAN`: Force clean clone (default: false)

### 3. `build-image.sh` - Docker Image Build
Builds the Docker image with MPZSQL application.

```bash
# Basic build
./scripts/build-image.sh

# Build without cache
./scripts/build-image.sh --no-cache

# Custom image name and tag
IMAGE_NAME=myrepo/mpzsql IMAGE_TAG=v1.0 ./scripts/build-image.sh
```

**Environment Variables:**
- `IMAGE_NAME`: Docker image name (default: ducklake/mpzsql)
- `IMAGE_TAG`: Docker image tag (default: latest)
- `PLATFORM`: Target platform (default: linux/amd64)
- `NO_CACHE`: Skip cache during build (default: false)

### 4. `run-container.sh` - Container Execution
Runs the Docker container with all required environment variables.

```bash
# Run interactively
./scripts/run-container.sh

# Run in background
./scripts/run-container.sh --detach

# Custom port
./scripts/run-container.sh --port 9090

# Don't remove container on exit
./scripts/run-container.sh --no-rm
```

**Environment Variables:**
- `IMAGE_NAME`: Docker image name (default: ducklake/mpzsql)
- `IMAGE_TAG`: Docker image tag (default: latest)
- `CONTAINER_NAME`: Container name (default: mpzsql-container)
- `HOST_PORT`: Host port to bind (default: 8080)
- `ENV_FILE`: Environment file path (default: ../secrets/set_env.sh)
- `DETACHED`: Run in background (default: false)

## Environment Variables

All environment variables from `secrets/set_env.sh` are automatically loaded into the container:

### Environment Variables

The following environment variables are required for the application:

#### PostgreSQL Configuration
- `POSTGRESQL_SERVER`: PostgreSQL server hostname
- `POSTGRESQL_USER`: PostgreSQL username
- `POSTGRESQL_PORT`: PostgreSQL port (default: 5432)
- `POSTGRESQL_CATALOGDB`: PostgreSQL database name
- `POSTGRESQL_PASSWORD`: PostgreSQL password

#### Additional Variables
- `LOGFIRE_WRITE_TOKEN`: Pydantic Logfire token for logging
- `AZURE_STORAGE_ACCOUNT`: Azure storage account name
- `AZURE_STORAGE_CONTAINER`: Azure storage container name
- `LETSENCRYPT_CERT`: LetsEncrypt certificate content
- `LETSENCRYPT_KEY`: LetsEncrypt private key content

## Docker Image Details

The Docker image (`Dockerfile`) includes:
- **Base**: Python 3.11 slim
- **Package Manager**: UV (modern Python package installer)
- **Exposed Port**: 8080
- **Health Check**: Server endpoint check
- **Multi-stage build**: Optimized for production
- **Security**: Non-root user execution
- **Dependencies**: Uses `pyproject.toml` and `uv.lock` for exact dependency resolution
- **Virtual Environment**: Managed by UV for isolation

## GitHub Actions Integration

These scripts are designed for easy integration with GitHub Actions:

```yaml
name: Build and Deploy MPZSQL

on:
  push:
    branches: [main]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Setup environment
        run: |
          echo "POSTGRESQL_SERVER=${{ secrets.POSTGRESQL_SERVER }}" >> secrets/set_env.sh
          echo "POSTGRESQL_USER=${{ secrets.POSTGRESQL_USER }}" >> secrets/set_env.sh
          echo "POSTGRESQL_PORT=${{ secrets.POSTGRESQL_PORT }}" >> secrets/set_env.sh
          echo "POSTGRESQL_CATALOGDB=${{ secrets.POSTGRESQL_CATALOGDB }}" >> secrets/set_env.sh
          echo "POSTGRESQL_PASSWORD=${{ secrets.POSTGRESQL_PASSWORD }}" >> secrets/set_env.sh
          echo "LOGFIRE_WRITE_TOKEN=${{ secrets.LOGFIRE_WRITE_TOKEN }}" >> secrets/set_env.sh
          echo "AZURE_STORAGE_ACCOUNT=${{ secrets.AZURE_STORAGE_ACCOUNT }}" >> secrets/set_env.sh
          echo "AZURE_STORAGE_CONTAINER=${{ secrets.AZURE_STORAGE_CONTAINER }}" >> secrets/set_env.sh
          echo "LETSENCRYPT_CERT=${{ secrets.LETSENCRYPT_CERT }}" >> secrets/set_env.sh
          echo "LETSENCRYPT_KEY=${{ secrets.LETSENCRYPT_KEY }}" >> secrets/set_env.sh
      
      - name: Download and build
        run: ./scripts/setup.sh --build-only
      
      - name: Run tests
        run: ./scripts/run-container.sh --detach
```

## Development Workflow

1. **Initial Setup**:
   ```bash
   ./scripts/setup.sh --auto-run
   ```

2. **Make Changes to Environment**:
   ```bash
   vim secrets/set_env.sh
   ```

3. **Rebuild and Run**:
   ```bash
   ./scripts/build-image.sh
   ./scripts/run-container.sh --detach
   ```

4. **View Logs**:
   ```bash
   docker logs -f mpzsql-container
   ```

5. **Stop Container**:
   ```bash
   docker stop mpzsql-container
   ```

## Container Management

### Check Container Status
```bash
docker ps -f name=mpzsql-container
```

### View Container Logs
```bash
docker logs -f mpzsql-container
```

### Execute Commands in Container
```bash
docker exec -it mpzsql-container bash
```

### Clean Up
```bash
# Stop and remove container
docker stop mpzsql-container
docker rm mpzsql-container

# Remove image
docker rmi ducklake/mpzsql:latest
```

## Troubleshooting

### Common Issues

1. **Port Already in Use**:
   ```bash
   HOST_PORT=9090 ./scripts/run-container.sh
   ```

2. **Environment File Not Found**:
   Ensure `secrets/set_env.sh` exists and is readable.

3. **Docker Image Not Found**:
   Run the build script first:
   ```bash
   ./scripts/build-image.sh
   ```

4. **Permission Denied**:
   Make scripts executable:
   ```bash
   chmod +x scripts/*.sh
   ```

### Debug Mode

For verbose output, add debug flags:
```bash
set -x  # Enable debug mode
./scripts/setup.sh --auto-run
```

## Security Notes

- Environment variables may contain sensitive information
- The `secrets/set_env.sh` file should not be committed to version control
- Use GitHub Secrets for CI/CD environments
- The container runs as a non-root user for security

## Performance Optimization

- Use `--no-cache` for clean builds when needed
- Multi-stage Docker build minimizes final image size
- Health checks ensure container readiness
- Platform-specific builds optimize for target architecture

---

For more information, see the individual script files or run any script with `--help`.
