#!/usr/bin/env python3
"""
Store certificate files as GitHub repository secrets.
Reads the Let's Encrypt certificate and key files and uploads them as secrets.
"""

import argparse
import base64
import os
import re
import sys
from pathlib import Path
from typing import Dict, Tuple

try:
    import requests
    from nacl import public
except ImportError:
    print("Installing required dependencies with uv...")
    import subprocess

    subprocess.check_call(["uv", "add", "requests", "pynacl"])
    import requests
    from nacl import public


class GitHubSecretsManager:
    """Manages GitHub repository secrets via REST API."""

    def __init__(self, token: str, owner: str, repo: str):
        self.token = token
        self.owner = owner
        self.repo = repo
        self.base_url = f"https://api.github.com/repos/{owner}/{repo}"
        self.headers = {
            "Authorization": f"Bearer {token}",
            "Accept": "application/vnd.github.v3+json",
            "X-GitHub-Api-Version": "2022-11-28",
        }

    def verify_token(self) -> bool:
        """Verify the token has proper permissions."""
        try:
            response = requests.get("https://api.github.com/user", headers=self.headers)
            if response.status_code == 401:
                print("❌ Invalid GitHub token")
                return False

            response.raise_for_status()
            user = response.json()
            print(f"✅ Authenticated as: {user.get('login', 'Unknown')}")

            # Check repository access
            repo_response = requests.get(self.base_url, headers=self.headers)
            if repo_response.status_code == 404:
                print(f"❌ Repository {self.owner}/{self.repo} not found or no access")
                return False
            repo_response.raise_for_status()

            # Check if we have admin access (required for secrets)
            repo_data = repo_response.json()
            permissions = repo_data.get("permissions", {})
            if not permissions.get("admin", False):
                print("⚠️  Warning: You may not have admin access to manage secrets")
                print("   Permissions:", permissions)

            return True
        except requests.exceptions.RequestException as e:
            print(f"❌ Failed to verify token: {e}")
            if hasattr(e, "response") and e.response is not None:
                print(f"   Response: {e.response.text}")
            return False

    def get_public_key(self) -> Tuple[str, str]:
        """Get repository public key for secret encryption."""
        try:
            response = requests.get(
                f"{self.base_url}/actions/secrets/public-key", headers=self.headers
            )
            if response.status_code == 404:
                print("❌ Unable to access repository secrets. Possible causes:")
                print("   - Repository doesn't exist or you don't have access")
                print("   - GitHub Actions is not enabled for this repository")
                print("   - Token doesn't have 'repo' scope")
                raise Exception("Cannot access repository secrets")
            response.raise_for_status()
            data = response.json()
            return data["key"], data["key_id"]
        except requests.exceptions.RequestException as e:
            print(f"❌ Failed to get public key: {e}")
            if hasattr(e, "response") and e.response is not None:
                print(f"   Status: {e.response.status_code}")
                print(f"   Response: {e.response.text}")
            raise

    def encrypt_secret(self, public_key: str, secret_value: str) -> str:
        """Encrypt a secret value using the repository's public key."""
        public_key_bytes = base64.b64decode(public_key)
        public_key_obj = public.PublicKey(public_key_bytes)
        sealed_box = public.SealedBox(public_key_obj)
        encrypted = sealed_box.encrypt(secret_value.encode("utf-8"))
        return base64.b64encode(encrypted).decode("utf-8")

    def set_secret(self, name: str, value: str) -> bool:
        """Create or update a repository secret."""
        try:
            # Get public key for encryption
            public_key, key_id = self.get_public_key()

            # Encrypt the secret value
            encrypted_value = self.encrypt_secret(public_key, value)

            # Create or update the secret
            response = requests.put(
                f"{self.base_url}/actions/secrets/{name}",
                headers=self.headers,
                json={"encrypted_value": encrypted_value, "key_id": key_id},
            )
            if response.status_code == 404:
                print(
                    f"\n❌ Failed to set secret {name}: Repository or Actions not accessible"
                )
                return False
            response.raise_for_status()
            return True
        except Exception as e:
            print(f"\n❌ Failed to set secret {name}: {str(e)}")
            return False

    def list_secrets(self) -> list:
        """List all repository secrets."""
        response = requests.get(
            f"{self.base_url}/actions/secrets", headers=self.headers
        )
        response.raise_for_status()
        return [secret["name"] for secret in response.json()["secrets"]]


def read_certificate_files(cert_dir: Path) -> Dict[str, str]:
    """Read certificate files and return their contents."""
    certificates = {}

    # Define the files to read
    files = {
        "LETSENCRYPT_CERT": "letsencrypt-server.crt",
        "LETSENCRYPT_KEY": "letsencrypt-server.key",
    }

    for secret_name, filename in files.items():
        file_path = cert_dir / filename
        if not file_path.exists():
            print(f"❌ Certificate file not found: {file_path}")
            continue

        try:
            with open(file_path, "r") as f:
                content = f.read().strip()
                certificates[secret_name] = content
                print(f"✅ Read {filename} ({len(content)} characters)")
        except Exception as e:
            print(f"❌ Failed to read {filename}: {e}")

    return certificates


def get_repo_info() -> Tuple[str, str]:
    """Get repository owner and name from git remote or environment."""
    # Try environment variables first
    if "GITHUB_REPOSITORY" in os.environ:
        repo = os.environ["GITHUB_REPOSITORY"]
        owner, name = repo.split("/")
        return owner, name

    # Try to get from git remote
    try:
        import subprocess

        remote_url = subprocess.check_output(
            ["git", "remote", "get-url", "origin"], text=True
        ).strip()

        # Parse GitHub URL
        match = re.search(r"github\.com[:/]([^/]+)/([^/]+?)(\.git)?$", remote_url)
        if match:
            return match.group(1), match.group(2)
    except Exception:
        pass

    raise ValueError(
        "Could not determine repository. Set GITHUB_REPOSITORY environment variable."
    )


def main():
    parser = argparse.ArgumentParser(
        description="Store certificate files as GitHub repository secrets"
    )
    parser.add_argument(
        "--token",
        default=os.environ.get("GITHUB_API_TOKEN") or os.environ.get("GITHUB_TOKEN"),
        help="GitHub Personal Access Token (or set GITHUB_API_TOKEN/GITHUB_TOKEN env var)",
    )
    parser.add_argument(
        "--cert-dir",
        default="secrets/certs",
        help="Path to certificates directory (default: secrets/certs)",
    )
    parser.add_argument(
        "--list",
        action="store_true",
        help="List current secrets instead of uploading certificates",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Show what would be uploaded without making changes",
    )
    parser.add_argument("--debug", action="store_true", help="Enable debug output")

    args = parser.parse_args()

    # Enable debug if requested
    if args.debug:
        import logging

        logging.basicConfig(level=logging.DEBUG)

    # Validate token
    if not args.token:
        print(
            "❌ GitHub token not provided. Set GITHUB_API_TOKEN/GITHUB_TOKEN or use --token"
        )
        print("\nTo create a token:")
        print("1. Go to https://github.com/settings/tokens")
        print("2. Click 'Generate new token (classic)'")
        print("3. Select scopes: 'repo' (all)")
        print("4. Generate and copy the token")
        sys.exit(1)

    # Get repository info
    try:
        owner, repo = get_repo_info()
        print(f"🚀 Repository: {owner}/{repo}")
    except ValueError as e:
        print(f"❌ {e}")
        sys.exit(1)

    # Create manager
    manager = GitHubSecretsManager(args.token, owner, repo)

    # Verify token
    print("\n🔐 Verifying GitHub access...")
    if not manager.verify_token():
        print("\n💡 Token requirements:")
        print("   - Must have 'repo' scope for private repositories")
        print("   - Must have 'public_repo' scope for public repositories")
        print("   - User must have admin access to the repository")
        sys.exit(1)

    # List secrets if requested
    if args.list:
        try:
            secrets = manager.list_secrets()
            print("\n📋 Current repository secrets:")
            for secret in secrets:
                print(f"  • {secret}")
        except Exception as e:
            print(f"❌ Failed to list secrets: {e}")
            sys.exit(1)
        return

    # Read certificate files
    cert_dir = Path(args.cert_dir)
    if not cert_dir.exists():
        print(f"❌ Certificate directory not found: {cert_dir}")
        sys.exit(1)

    print(f"📖 Reading certificates from {cert_dir}")
    certificates = read_certificate_files(cert_dir)

    if not certificates:
        print("❌ No certificate files found or readable")
        sys.exit(1)

    print(f"\n🔄 Found {len(certificates)} certificate files to upload:")
    for name in certificates:
        print(f"  • {name}")

    if args.dry_run:
        print("\n⚠️  Dry run mode - no changes will be made")
        print("\nCertificate contents preview:")
        for name, content in certificates.items():
            lines = content.split("\n")
            print(f"\n{name}:")
            print(f"  First line: {lines[0] if lines else '(empty)'}")
            print(
                f"  Last line:  {lines[-1] if lines and lines[-1] else lines[-2] if len(lines) > 1 else '(empty)'}"
            )
            print(f"  Total lines: {len(lines)}")
        return

    # Upload certificates as secrets
    print("\n🔄 Uploading certificates to GitHub...")
    success_count = 0
    for name, content in certificates.items():
        print(f"  Setting {name}...", end=" ", flush=True)
        if manager.set_secret(name, content):
            print("✅")
            success_count += 1
        else:
            print("❌")

    print(
        f"\n✅ Successfully uploaded {success_count}/{len(certificates)} certificates"
    )

    if success_count > 0:
        print("\n📝 Secrets created:")
        for name in certificates:
            print(
                f"  • {name} - Can be used in GitHub Actions as ${{ secrets.{name} }}"
            )


if __name__ == "__main__":
    main()
