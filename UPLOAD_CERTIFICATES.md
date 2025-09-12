# Quick Instructions: Upload Certificates to GitHub Secrets

## Option 1: Using VS Code Tasks (Recommended)

1. **Open Command Palette**: `Cmd+Shift+P` (macOS) or `Ctrl+Shift+P` (Windows/Linux)
2. **Type**: `Tasks: Run Task`
3. **Select one of**:
   - `Upload Certificates (Dry Run)` - Test what would be uploaded
   - `Upload Certificates (LIVE)` - Actually upload the secrets
   - `List GitHub Secrets` - See what secrets already exist

## Option 2: Using Terminal

Open a terminal in VS Code (`Ctrl+`` ` or `View > Terminal`) and run:

```bash
# Dry run first (recommended)
./scripts/run_cert_upload.sh --dry-run

# If dry run looks good, upload for real
./scripts/run_cert_upload.sh

# Or list existing secrets
./scripts/run_cert_upload.sh --list
```

## What This Does

The script will:
1. ✅ Read your GitHub token from `secrets/githubtoken.txt`
2. ✅ Read certificate files:
   - `secrets/certs/letsencrypt-server.crt`
   - `secrets/certs/letsencrypt-server.key`
3. ✅ Upload them as GitHub repository secrets:
   - `LETSENCRYPT_CERT`
   - `LETSENCRYPT_KEY`

## Expected Output

```
🔑 Using GitHub token from /path/to/secrets/githubtoken.txt
🚀 Running certificate upload script with uv...

🚀 Repository: MiguelElGallo/ducklake

🔐 Verifying GitHub access...
✅ Authenticated as: MiguelElGallo

📖 Reading certificates from secrets/certs
✅ Read letsencrypt-server.crt (1234 characters)
✅ Read letsencrypt-server.key (567 characters)

🔄 Found 2 certificate files to upload:
  • LETSENCRYPT_CERT
  • LETSENCRYPT_KEY

🔄 Uploading certificates to GitHub...
  Setting LETSENCRYPT_CERT... ✅
  Setting LETSENCRYPT_KEY... ✅

✅ Successfully uploaded 2/2 certificates

📝 Secrets created:
  • LETSENCRYPT_CERT - Can be used in GitHub Actions as ${{ secrets.LETSENCRYPT_CERT }}
  • LETSENCRYPT_KEY  - Can be used in GitHub Actions as ${{ secrets.LETSENCRYPT_KEY }}
```

## Troubleshooting

If you see any errors, check:
1. GitHub token is valid and has `repo` scope
2. You have admin access to the repository
3. Certificate files exist in `secrets/certs/`
4. `uv` is installed (`uv --version`)

## Next Steps

Once uploaded, you can use these secrets in GitHub Actions:

```yaml
- name: Setup SSL certificates
  run: |
    echo "${{ secrets.LETSENCRYPT_CERT }}" > server.crt
    echo "${{ secrets.LETSENCRYPT_KEY }}" > server.key
    chmod 600 server.key
```
