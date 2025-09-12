# Certificate Upload Scripts

This directory contains scripts to upload Let's Encrypt certificate files as GitHub repository secrets.

## Files

- **`set_cert_secrets.py`** - Python script that handles the GitHub API interaction
- **`upload_certs.sh`** - Shell script wrapper for easier usage

## Prerequisites

1. **GitHub Personal Access Token** with `repo` scope
2. **Certificate files** in `secrets/certs/`:
   - `letsencrypt-server.crt` - The SSL certificate
   - `letsencrypt-server.key` - The private key

## Quick Start

1. **Set your GitHub token**:
   ```bash
   export GITHUB_TOKEN="your_github_token_here"
   ```

2. **Run the upload script**:
   ```bash
   ./scripts/upload_certs.sh
   ```

## Usage Options

### Shell Script (Recommended)

```bash
# Upload certificates
./scripts/upload_certs.sh

# Dry run (see what would be uploaded)
./scripts/upload_certs.sh --dry-run

# List current secrets
./scripts/upload_certs.sh --list

# Enable debug output
./scripts/upload_certs.sh --debug

# Show help
./scripts/upload_certs.sh --help
```

### Python Script (Advanced)

```bash
# Upload certificates
python3 scripts/set_cert_secrets.py

# Custom certificate directory
python3 scripts/set_cert_secrets.py --cert-dir /path/to/certs

# Use specific token
python3 scripts/set_cert_secrets.py --token ghp_your_token_here

# Dry run
python3 scripts/set_cert_secrets.py --dry-run

# List secrets
python3 scripts/set_cert_secrets.py --list
```

## GitHub Token Setup

1. Go to [GitHub Settings > Personal Access Tokens](https://github.com/settings/tokens)
2. Click "Generate new token (classic)"
3. Select the following scopes:
   - `repo` (Full control of private repositories)
4. Generate and copy the token
5. Set it as an environment variable:
   ```bash
   export GITHUB_TOKEN="ghp_your_token_here"
   ```

## What Gets Created

The script creates the following GitHub repository secrets:

- **`LETSENCRYPT_CERT`** - Contains the SSL certificate content
- **`LETSENCRYPT_KEY`** - Contains the private key content

## Using in GitHub Actions

Once uploaded, you can use these secrets in your GitHub Actions workflows:

```yaml
name: Deploy with SSL
on: [push]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Setup SSL certificates
        run: |
          echo "${{ secrets.LETSENCRYPT_CERT }}" > server.crt
          echo "${{ secrets.LETSENCRYPT_KEY }}" > server.key
          chmod 600 server.key
      
      - name: Deploy application
        run: |
          # Your deployment commands here
```

## Security Notes

- The scripts use proper encryption for GitHub secrets
- Private keys are handled securely and never logged
- Only users with admin access to the repository can manage secrets
- Secrets are encrypted at rest in GitHub

## Troubleshooting

### "Repository not found or no access"
- Ensure your token has the correct permissions
- Verify you have admin access to the repository

### "Certificate file not found"
- Check that the files exist in `secrets/certs/`
- Verify the file names match exactly:
  - `letsencrypt-server.crt`
  - `letsencrypt-server.key`

### "Invalid GitHub token"
- Regenerate your token with proper scopes
- Ensure the token hasn't expired

### "Unable to access repository secrets"
- GitHub Actions must be enabled for the repository
- Token must have `repo` scope for private repositories
- User must have admin permissions

## File Structure

```
secrets/certs/
├── letsencrypt-server.crt    # SSL certificate (required)
├── letsencrypt-server.key    # Private key (required)
├── letsencrypt-chain.pem     # Certificate chain (optional)
└── letsencrypt-fullchain.pem # Full chain (optional)
```

Only the `.crt` and `.key` files are uploaded as secrets.
