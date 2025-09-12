# DuckLake MPZSQL Containerized Application

Always reference these instructions first and fallback to search or bash commands only when you encounter unexpected information that does not match the info here.

## Working Effectively

### Bootstrap and Build Process
- Make scripts executable: `chmod +x scripts/*.sh && chmod +x entrypoint.sh`
- Complete setup (download + build): `./scripts/setup.sh --auto-run`
- Download only: `./scripts/setup.sh --download-only` -- takes < 1 second. NEVER CANCEL.
- Build Docker image: `./scripts/build-image.sh` -- takes 50 seconds to 2 minutes. NEVER CANCEL. Set timeout to 5+ minutes.
- Clean build: `CLEAN_BUILD=true ./scripts/setup.sh` -- takes 2-3 minutes. NEVER CANCEL. Set timeout to 5+ minutes.

### Python Environment (UV)
- Install dependencies: `cd mpzsql && uv sync --frozen` -- takes 2-3 seconds. NEVER CANCEL.
- Run MPZSQL CLI: `cd mpzsql && uv run python -m mpzsql.cli --help`
- Run tests: `cd mpzsql && uv run pytest` -- takes 20-25 seconds for full suite (588 tests). NEVER CANCEL. Set timeout to 2+ minutes.
- Run single test: `cd mpzsql && uv run pytest tests/test_simple_check.py -v` -- takes < 2 seconds.

### Container Operations
- Run container (detached): `./scripts/run-container.sh --detach`
- Run container (interactive): `./scripts/run-container.sh`
- View logs: `docker logs -f mpzsql-container`
- Stop container: `docker stop mpzsql-container`
- Container runs on port 8080 by default

### Environment Setup
- Create environment file: `mkdir -p secrets && vim secrets/set_env.sh`
- Environment file format: `export VARIABLE_NAME="value"`
- Required variables listed in GITHUB_SECRETS.md

## Validation

### ALWAYS Test After Changes
- Run the complete build process: `./scripts/setup.sh --clean-build --auto-run` -- takes 2-3 minutes total. NEVER CANCEL.
- Verify container starts: `docker ps -f name=mpzsql-container`
- Check container logs for errors: `docker logs mpzsql-container`
- Test MPZSQL CLI: `cd mpzsql && uv run python -m mpzsql.cli --help`

### Manual Testing Scenarios
- **Container Startup**: Run `./scripts/run-container.sh --detach --no-rm` and verify container starts (may exit due to missing PostgreSQL, which is expected)
- **ETL Tools**: ETL scripts in `batch_load/` require Snowflake credentials and running MPZSQL server
- **Certificate Management**: Scripts in `scripts/` for uploading SSL certificates to GitHub secrets

### Build Time Expectations
- **NEVER CANCEL builds or long-running commands**
- Download MPZSQL: < 1 second
- UV sync dependencies: 2-3 seconds  
- Docker build: 50 seconds to 2 minutes
- Full test suite: 20-25 seconds
- Complete setup: 2-3 minutes total

## Common Tasks

### Repository Structure
```
ducklake/
├── scripts/                    # Build and deployment automation
│   ├── setup.sh               # Main orchestration script
│   ├── download-mpzsql.sh     # Downloads MPZSQL repository
│   ├── build-image.sh         # Builds Docker image
│   ├── run-container.sh       # Runs container with env vars
│   └── upload_certs.sh        # Uploads SSL certs to GitHub secrets
├── batch_load/                # ETL tools for Snowflake to MPZSQL
├── mpzsql/                    # Downloaded MPZSQL server source (auto-generated)
├── Dockerfile                 # Multi-stage build with UV package manager
├── entrypoint.sh             # Container startup script with TLS support
├── secrets/                  # Environment variables and certificates
│   ├── set_env.sh           # Environment variables for container
│   └── certs/               # SSL certificates (not in repo)
└── .github/workflows/       # CI/CD workflows for Azure deployment
```

### Key Technologies
- **Python**: UV package manager for fast dependency resolution
- **Docker**: Multi-stage builds with Python 3.11 slim base
- **MPZSQL**: FlightSQL server with DuckDB backend
- **Azure**: Container Registry and Container Apps deployment
- **TLS**: Let's Encrypt certificate integration
- **ETL**: Snowflake to MPZSQL high-performance data transfer

### Environment Variables
Always check `GITHUB_SECRETS.md` for complete list. Key variables:
- `POSTGRESQL_*`: PostgreSQL connection settings
- `AZURE_STORAGE_*`: Azure blob storage configuration  
- `LETSENCRYPT_*`: SSL certificate content
- `LOGFIRE_WRITE_TOKEN`: Pydantic logging token

### CI/CD Integration
- Main workflow: `.github/workflows/build-and-push-image.yml`
- Builds Docker image and pushes to Azure Container Registry
- Includes TLS certificate management and cleanup
- Uses GitHub secrets for environment variables

### Development Workflow
1. Edit environment: `vim secrets/set_env.sh`
2. Rebuild: `./scripts/build-image.sh` 
3. Test locally: `./scripts/run-container.sh --detach`
4. View logs: `docker logs -f mpzsql-container`
5. Run tests: `cd mpzsql && uv run pytest`

### Prerequisites
- Docker (installed and running)
- Git (for repository operations)
- UV package manager (installed at `/home/runner/.local/bin/uv`)
- Curl (for health checks and downloads)

### Troubleshooting
- Container exits immediately: Check PostgreSQL connection in logs (expected without DB)
- Build fails: Run with `CLEAN_BUILD=true` to force clean build
- Permission denied: Run `chmod +x scripts/*.sh && chmod +x entrypoint.sh`
- UV not found: Check `/home/runner/.local/bin/uv` or install UV
- Environment loading: Verify `secrets/set_env.sh` exists and has export statements

### Performance Notes
- UV package manager provides extremely fast dependency resolution (2-3 seconds)
- Docker multi-stage builds optimize image size (final image ~887MB)
- Batch ETL processes 100,000 records per batch to stay within FlightSQL limits
- Health checks ensure container readiness before deployment

### Security
- Non-root user execution in containers
- TLS certificate support with Let's Encrypt integration
- GitHub secrets for sensitive environment variables
- mTLS support for client verification

### Important Files to Check After Changes
- Always verify `Dockerfile` builds successfully
- Check `entrypoint.sh` for container startup logic
- Validate `scripts/setup.sh` orchestration works end-to-end
- Ensure `.github/workflows/` files reference correct environment variables